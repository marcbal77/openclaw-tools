#!/bin/bash
# gateway-watchdog.sh — OpenClaw Gateway Health Monitor
#
# Graduated response pattern:
#   1st failure  → log warning, wait
#   2nd failure  → attempt restart
#   3rd+ failure → rollback config to last-known-good + restart + alert
#
# Does NOT use set -e; must handle errors gracefully in loop.

OPENCLAW_CONFIG="$HOME/.openclaw/openclaw.json"
LAST_GOOD="$HOME/.openclaw/openclaw.json.last-good"
LOG="$HOME/logs/watchdog.log"
LOG_MAX_BYTES=1048576  # 1MB
WEBHOOK_ENV="$HOME/.secrets/alert-webhook.env"
CHECK_INTERVAL=60
GATEWAY_LABEL="ai.openclaw.gateway"
MAX_ROLLBACKS_PER_HOUR=3
ROLLBACK_WINDOW=3600

mkdir -p "$(dirname "$LOG")"

# ─── Logging ────────────────────────────────────────────────────────────────

log() {
  local level="$1"; shift
  local msg="[$(date '+%Y-%m-%d %H:%M:%S')] [watchdog] [$level] $*"
  echo "$msg" >> "$LOG"
  echo "$msg"
  # Rotate log at 1MB
  if [[ -f "$LOG" ]]; then
    local size
    size=$(stat -f%z "$LOG" 2>/dev/null || stat -c%s "$LOG" 2>/dev/null || echo 0)
    if [[ "$size" -gt "$LOG_MAX_BYTES" ]]; then
      mv "$LOG" "${LOG}.$(date +%s).old"
      echo "[$(date '+%Y-%m-%d %H:%M:%S')] [watchdog] [INFO] Log rotated." > "$LOG"
    fi
  fi
}

# ─── Alert (Webhook) ────────────────────────────────────────────────────────
# Configure ALERT_WEBHOOK_URL in your webhook env file.
# Works with Discord, Slack, or any service accepting JSON POST with {"content": "..."}.

send_alert() {
  local message="$1"
  if [[ ! -f "$WEBHOOK_ENV" ]]; then
    log "WARN" "Webhook env not found at $WEBHOOK_ENV — skipping alert."
    return 0
  fi
  local webhook_url
  webhook_url=$(grep -E '^ALERT_WEBHOOK_URL=' "$WEBHOOK_ENV" 2>/dev/null | cut -d= -f2- | tr -d '[:space:]')
  if [[ -z "$webhook_url" ]]; then
    log "WARN" "ALERT_WEBHOOK_URL not set in $WEBHOOK_ENV — skipping alert."
    return 0
  fi
  local payload
  payload=$(python3 -c "import json,sys; print(json.dumps({'content': sys.argv[1]}))" "$message" 2>/dev/null || echo '{"content":"Alert (payload encoding error)"}')
  curl -s -o /dev/null -w "%{http_code}" \
    -H "Content-Type: application/json" \
    -d "$payload" \
    "$webhook_url" || log "WARN" "Webhook curl failed"
  log "INFO" "Alert sent."
}

# ─── Health Check ───────────────────────────────────────────────────────────

# Returns 0 if gateway looks healthy, 1 if not
check_gateway_health() {
  # launchctl list returns 0 if service is registered; check PID field
  local lc_output
  lc_output=$(launchctl list "$GATEWAY_LABEL" 2>/dev/null) || return 1

  # Extract PID from plist dict output
  local pid
  pid=$(echo "$lc_output" | grep '"PID"' | grep -o '[0-9]*')
  if [[ -z "$pid" ]]; then
    return 1
  fi

  # Check process is actually alive
  if ! kill -0 "$pid" 2>/dev/null; then
    return 1
  fi

  # Check process uptime > 30 seconds (not crash-looping)
  local start_time now uptime_secs
  start_time=$(ps -p "$pid" -o lstart= 2>/dev/null | xargs -I{} date -j -f "%a %b %d %T %Y" "{}" "+%s" 2>/dev/null || echo 0)
  now=$(date +%s)
  uptime_secs=$(( now - start_time ))

  if [[ "$uptime_secs" -lt 30 ]]; then
    log "WARN" "Gateway PID=$pid alive but uptime=${uptime_secs}s (<30s) — possible crash-loop"
    return 1
  fi

  echo "$pid"  # echo PID so caller can capture it
  return 0
}

# ─── Rollback ───────────────────────────────────────────────────────────────

rollback_config() {
  if [[ ! -f "$LAST_GOOD" ]]; then
    log "ERROR" "No last-good config at $LAST_GOOD — cannot rollback!"
    return 1
  fi

  local broken_path="$HOME/.openclaw/openclaw.json.broken.$(date +%s)"
  log "WARN" "Saving broken config → $broken_path"
  cp "$OPENCLAW_CONFIG" "$broken_path" 2>/dev/null || true

  log "INFO" "Restoring last-good config..."
  cp "$LAST_GOOD" "$OPENCLAW_CONFIG"
  log "INFO" "Config restored from $LAST_GOOD"
}

restart_gateway() {
  log "INFO" "Restarting gateway via launchctl kickstart..."
  launchctl kickstart -k "gui/$(id -u)/$GATEWAY_LABEL" 2>/dev/null || \
    log "ERROR" "launchctl kickstart failed (gateway may need manual start)"
}

snapshot_good_config() {
  local current_hash last_hash
  current_hash=$(md5 -q "$OPENCLAW_CONFIG" 2>/dev/null || md5sum "$OPENCLAW_CONFIG" 2>/dev/null | cut -d' ' -f1)
  last_hash=$(md5 -q "$LAST_GOOD" 2>/dev/null || md5sum "$LAST_GOOD" 2>/dev/null | cut -d' ' -f1 || echo "none")
  if [[ "$current_hash" != "$last_hash" ]]; then
    cp "$OPENCLAW_CONFIG" "$LAST_GOOD"
    log "INFO" "Snapshotted good config → $LAST_GOOD (hash changed)"
  fi
}

# ─── Main Loop ──────────────────────────────────────────────────────────────

log "INFO" "Gateway Watchdog starting. Checking every ${CHECK_INTERVAL}s."

consecutive_failures=0
gateway_up_since=0   # epoch when last seen healthy
rollback_count=0
rollback_window_start=0

while true; do
  pid_output=$(check_gateway_health 2>/dev/null) && HEALTHY=1 || HEALTHY=0
  now=$(date +%s)

  if [[ "$HEALTHY" -eq 1 ]]; then
    consecutive_failures=0

    # Track continuous uptime
    if [[ "$gateway_up_since" -eq 0 ]]; then
      gateway_up_since="$now"
    fi

    continuous_uptime=$(( now - gateway_up_since ))

    if [[ "$continuous_uptime" -gt 120 ]]; then
      snapshot_good_config
    fi

    log "INFO" "Gateway healthy (PID=${pid_output:-?}, continuous_uptime=${continuous_uptime}s)"

  else
    consecutive_failures=$(( consecutive_failures + 1 ))
    gateway_up_since=0
    log "WARN" "Gateway unhealthy (consecutive_failures=$consecutive_failures)"

    if [[ "$consecutive_failures" -eq 1 ]]; then
      log "WARN" "1st failure — waiting before action."

    elif [[ "$consecutive_failures" -eq 2 ]]; then
      log "WARN" "2nd consecutive failure — attempting restart."
      restart_gateway

    elif [[ "$consecutive_failures" -ge 3 ]]; then
      log "ERROR" "3rd+ failure — CRASH-LOOP DETECTED. Rolling back config."

      # Cooldown: max N rollbacks per hour
      if [[ $(( now - rollback_window_start )) -gt "$ROLLBACK_WINDOW" ]]; then
        rollback_count=0
        rollback_window_start="$now"
      fi

      if [[ "$rollback_count" -ge "$MAX_ROLLBACKS_PER_HOUR" ]]; then
        log "ERROR" "Max rollbacks ($MAX_ROLLBACKS_PER_HOUR/hr) exceeded. Manual intervention required."
        send_alert "Gateway Watchdog: Max rollbacks exceeded ($MAX_ROLLBACKS_PER_HOUR/hr). Last-good config may also be broken. Manual intervention required! Timestamp: $(date)"
        consecutive_failures=0
        sleep 300  # Back off 5 minutes
      elif rollback_config; then
        rollback_count=$(( rollback_count + 1 ))
        restart_gateway
        send_alert "Gateway Watchdog: Crash-loop detected. Config rolled back to last-known-good. Check ~/.openclaw/openclaw.json.broken.* for the bad config. Timestamp: $(date)"
        log "INFO" "Rollback + restart complete. Resetting failure counter."
        consecutive_failures=0
      else
        log "ERROR" "Rollback failed — no last-good config. Manual intervention required."
        send_alert "Gateway Watchdog: Crash-loop detected but NO last-good config found for rollback. Manual intervention required! Timestamp: $(date)"
      fi
    fi
  fi

  sleep "$CHECK_INTERVAL"
done
