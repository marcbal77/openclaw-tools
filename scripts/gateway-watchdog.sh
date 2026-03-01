#!/usr/bin/env bash
# gateway-watchdog.sh — Graduated Response Gateway Watchdog
#
# Monitors a service/gateway health and auto-recovers from crashes using
# a graduated response strategy:
#
#   Failure 1: Log and wait
#   Failure 2: Attempt restart
#   Failure 3+: Rollback config + restart + alert
#
# Features:
#   - Crash-loop detection (process must survive >30 seconds)
#   - Config rollback to last-known-good snapshot
#   - Cooldown protection (max N rollbacks per hour)
#   - Webhook alerts (Discord, Slack, etc.)
#   - Log rotation
#
# Usage:
#   ./scripts/gateway-watchdog.sh           # Run in foreground
#   nohup ./scripts/gateway-watchdog.sh &   # Run as daemon
#
# Configure via environment variables or edit the CONFIG section below.

set -uo pipefail

# ─── CONFIG ───────────────────────────────────────────────────────────
# Override these with environment variables or edit directly

CONFIG_FILE="${WATCHDOG_CONFIG_FILE:-$HOME/.config/my-gateway/config.json}"
LAST_GOOD_CONFIG="${WATCHDOG_LAST_GOOD:-$HOME/.config/my-gateway/config.json.last-good}"
LOG_FILE="${WATCHDOG_LOG:-$HOME/logs/watchdog.log}"
CHECK_INTERVAL="${WATCHDOG_INTERVAL:-60}"           # seconds between checks
MAX_ROLLBACKS_PER_HOUR="${WATCHDOG_MAX_ROLLBACKS:-3}"
SERVICE_NAME="${WATCHDOG_SERVICE_NAME:-my-gateway}"  # launchd label or systemd unit
HEALTHY_THRESHOLD="${WATCHDOG_HEALTHY_SECS:-120}"    # seconds healthy before snapshotting config
CRASH_LOOP_THRESHOLD="${WATCHDOG_CRASH_SECS:-30}"    # process must survive this long

# Webhook for alerts (set via env var or a secrets file)
# WATCHDOG_WEBHOOK_URL="https://hooks.example.com/your-webhook"
WEBHOOK_URL="${WATCHDOG_WEBHOOK_URL:-}"

# ─── STATE ────────────────────────────────────────────────────────────

consecutive_failures=0
last_healthy_ts=0
rollback_timestamps=()

# ─── HELPERS ──────────────────────────────────────────────────────────

log() {
  local ts
  ts=$(date '+%Y-%m-%d %H:%M:%S')
  echo "[$ts] $*" >> "$LOG_FILE"
}

rotate_log() {
  local max_size=1048576  # 1MB
  if [[ -f "$LOG_FILE" ]] && (( $(stat -f%z "$LOG_FILE" 2>/dev/null || stat -c%s "$LOG_FILE" 2>/dev/null || echo 0) > max_size )); then
    mv "$LOG_FILE" "${LOG_FILE}.old"
    log "Log rotated"
  fi
}

send_alert() {
  local message="$1"
  local level="${2:-warning}"  # info, warning, critical

  log "ALERT [$level]: $message"

  if [[ -n "$WEBHOOK_URL" ]]; then
    # Generic webhook payload — customize for your platform
    local payload
    payload=$(cat <<JSONEOF
{
  "content": "**[$level] ${SERVICE_NAME} Watchdog**: ${message}"
}
JSONEOF
)
    curl -sf -X POST -H "Content-Type: application/json" \
      -d "$payload" "$WEBHOOK_URL" &>/dev/null || true
  fi
}

# ─── HEALTH CHECK ────────────────────────────────────────────────────

check_gateway_health() {
  # Strategy: check if the service process is running and has been alive
  # long enough to not be crash-looping.
  #
  # Customize this function for your platform:
  #   - macOS/launchd: launchctl list <label>
  #   - Linux/systemd: systemctl is-active <unit>
  #   - Generic: curl a health endpoint, check a PID file, etc.

  local pid

  # macOS launchd example:
  if command -v launchctl &>/dev/null; then
    pid=$(launchctl list "$SERVICE_NAME" 2>/dev/null | awk '/PID/ {print $2}')
    if [[ -z "$pid" || "$pid" == "-" ]]; then
      return 1  # Not running
    fi
  # Linux systemd example:
  elif command -v systemctl &>/dev/null; then
    if ! systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
      return 1
    fi
    pid=$(systemctl show "$SERVICE_NAME" --property=MainPID --value 2>/dev/null)
  else
    # Fallback: check by process name
    pid=$(pgrep -f "$SERVICE_NAME" | head -1)
    if [[ -z "$pid" ]]; then
      return 1
    fi
  fi

  # Verify process is actually alive
  if ! kill -0 "$pid" 2>/dev/null; then
    return 1
  fi

  # Crash-loop detection: check process uptime
  local start_time now elapsed
  if [[ "$(uname)" == "Darwin" ]]; then
    start_time=$(ps -o lstart= -p "$pid" 2>/dev/null | xargs -I{} date -j -f "%c" "{}" "+%s" 2>/dev/null || echo 0)
  else
    start_time=$(stat -c %Y "/proc/$pid" 2>/dev/null || echo 0)
  fi
  now=$(date +%s)
  elapsed=$((now - start_time))

  if (( elapsed < CRASH_LOOP_THRESHOLD )); then
    log "Process $pid alive but only ${elapsed}s old (crash-loop suspected)"
    return 1
  fi

  return 0
}

# ─── RECOVERY ACTIONS ────────────────────────────────────────────────

restart_service() {
  log "Attempting restart of $SERVICE_NAME"

  if command -v launchctl &>/dev/null; then
    launchctl kickstart -k "gui/$(id -u)/$SERVICE_NAME" 2>/dev/null || \
    launchctl kickstart -k "system/$SERVICE_NAME" 2>/dev/null || true
  elif command -v systemctl &>/dev/null; then
    systemctl restart "$SERVICE_NAME" 2>/dev/null || true
  else
    log "No service manager found — manual restart required"
    send_alert "Cannot auto-restart: no launchd/systemd found. Manual restart required." "critical"
  fi
}

rollback_config() {
  if [[ ! -f "$LAST_GOOD_CONFIG" ]]; then
    log "No last-good config to rollback to"
    return 1
  fi

  log "Rolling back config: $CONFIG_FILE → last-good snapshot"
  cp "$LAST_GOOD_CONFIG" "$CONFIG_FILE"
  return 0
}

snapshot_config() {
  if [[ ! -f "$CONFIG_FILE" ]]; then
    return
  fi

  # Only snapshot if config has changed
  local current_hash last_hash
  current_hash=$(md5sum "$CONFIG_FILE" 2>/dev/null | cut -d' ' -f1 || md5 -q "$CONFIG_FILE" 2>/dev/null || echo "unknown")
  last_hash=$(md5sum "$LAST_GOOD_CONFIG" 2>/dev/null | cut -d' ' -f1 || md5 -q "$LAST_GOOD_CONFIG" 2>/dev/null || echo "none")

  if [[ "$current_hash" != "$last_hash" ]]; then
    cp "$CONFIG_FILE" "$LAST_GOOD_CONFIG"
    log "Config snapshot updated (hash changed: ${current_hash:0:8})"
  fi
}

check_rollback_cooldown() {
  local now
  now=$(date +%s)
  local one_hour_ago=$((now - 3600))

  # Prune old timestamps
  local recent=()
  for ts in "${rollback_timestamps[@]}"; do
    if (( ts > one_hour_ago )); then
      recent+=("$ts")
    fi
  done
  rollback_timestamps=("${recent[@]+"${recent[@]}"}")

  if (( ${#rollback_timestamps[@]} >= MAX_ROLLBACKS_PER_HOUR )); then
    return 1  # Cooldown active
  fi
  return 0
}

# ─── MAIN LOOP ────────────────────────────────────────────────────────

main() {
  mkdir -p "$(dirname "$LOG_FILE")"
  log "Watchdog started for $SERVICE_NAME (interval: ${CHECK_INTERVAL}s)"

  while true; do
    rotate_log

    if check_gateway_health; then
      # Healthy
      if (( consecutive_failures > 0 )); then
        log "Service recovered after $consecutive_failures failure(s)"
        consecutive_failures=0
      fi

      local now
      now=$(date +%s)

      # Snapshot config after sustained health
      if (( last_healthy_ts > 0 )) && (( now - last_healthy_ts > HEALTHY_THRESHOLD )); then
        snapshot_config
      fi
      last_healthy_ts=$now

    else
      # Unhealthy
      ((consecutive_failures++)) || true
      log "Health check failed (consecutive: $consecutive_failures)"

      case $consecutive_failures in
        1)
          # Failure 1: Log and wait
          log "First failure — waiting for next check"
          ;;
        2)
          # Failure 2: Attempt restart
          log "Second failure — attempting restart"
          restart_service
          send_alert "Service restarted after 2 consecutive failures" "warning"
          ;;
        *)
          # Failure 3+: Crash-loop detected — rollback + restart
          log "Crash-loop detected ($consecutive_failures failures)"

          if check_rollback_cooldown; then
            if rollback_config; then
              rollback_timestamps+=("$(date +%s)")
              restart_service
              send_alert "Crash-loop: config rolled back and service restarted (failure #$consecutive_failures)" "critical"
            else
              restart_service
              send_alert "Crash-loop: restart attempted but no config backup available" "critical"
            fi
          else
            # Cooldown active — too many rollbacks
            log "Rollback cooldown active ($MAX_ROLLBACKS_PER_HOUR rollbacks/hour exceeded)"
            send_alert "MANUAL INTERVENTION REQUIRED: rollback cooldown exceeded. $consecutive_failures consecutive failures." "critical"
            sleep 300  # 5-minute backoff
          fi
          ;;
      esac
    fi

    sleep "$CHECK_INTERVAL"
  done
}

main "$@"
