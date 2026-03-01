#!/usr/bin/env bash
# smoke-test.sh — Infrastructure Smoke Test Suite
#
# Run after system changes (OS updates, dependency upgrades, token renewals)
# to verify all integrations are healthy.
#
# Usage:
#   ./scripts/smoke-test.sh          # Human-readable output
#   ./scripts/smoke-test.sh --json   # Machine-readable JSON output
#
# Exit code = number of hard failures (warnings don't count)

set -euo pipefail

# ─── Configuration ────────────────────────────────────────────────────
# Customize these for your environment

PROJECT_DIR="${PROJECT_DIR:-$HOME/my-project}"
# CONFIG_FILE="${CONFIG_FILE:-$HOME/.config/my-tool/config.json}"
# HEALTH_ENDPOINT="${HEALTH_ENDPOINT:-https://localhost:8443/api/health}"

# ─── State ────────────────────────────────────────────────────────────

FAILURES=0
WARNINGS=0
PASSED=0
TOTAL=0
JSON_MODE=false
RESULTS=()

[[ "${1:-}" == "--json" ]] && JSON_MODE=true

# ─── Helpers ──────────────────────────────────────────────────────────

pass() {
  local name="$1" detail="${2:-}"
  ((TOTAL++)) || true
  ((PASSED++)) || true
  if $JSON_MODE; then
    RESULTS+=("{\"status\":\"pass\",\"name\":\"$name\",\"detail\":\"$detail\"}")
  else
    printf "  ✅ %-40s %s\n" "$name" "$detail"
  fi
}

fail() {
  local name="$1" detail="${2:-}" fix="${3:-}"
  ((TOTAL++)) || true
  ((FAILURES++)) || true
  if $JSON_MODE; then
    RESULTS+=("{\"status\":\"fail\",\"name\":\"$name\",\"detail\":\"$detail\",\"fix\":\"$fix\"}")
  else
    printf "  ❌ %-40s %s\n" "$name" "$detail"
    [[ -n "$fix" ]] && printf "     ↳ Fix: %s\n" "$fix"
  fi
}

warn() {
  local name="$1" detail="${2:-}" fix="${3:-}"
  ((TOTAL++)) || true
  ((WARNINGS++)) || true
  if $JSON_MODE; then
    RESULTS+=("{\"status\":\"warn\",\"name\":\"$name\",\"detail\":\"$detail\",\"fix\":\"$fix\"}")
  else
    printf "  ⚠️  %-40s %s\n" "$name" "$detail"
    [[ -n "$fix" ]] && printf "     ↳ Fix: %s\n" "$fix"
  fi
}

# ─── Test Categories ─────────────────────────────────────────────────

test_git() {
  $JSON_MODE || echo "── Git ──"

  if command -v git &>/dev/null; then
    pass "git installed" "$(git --version)"
  else
    fail "git installed" "not found" "Install git"
    return
  fi

  if command -v gh &>/dev/null; then
    pass "gh CLI installed" "$(gh --version | head -1)"
  else
    fail "gh CLI installed" "not found" "brew install gh"
    return
  fi

  if gh auth status &>/dev/null; then
    pass "gh auth valid"
  else
    fail "gh auth valid" "not authenticated" "gh auth login"
  fi

  # Dry-run push test for your primary repo
  if [[ -d "$PROJECT_DIR/.git" ]]; then
    if git -C "$PROJECT_DIR" push --dry-run &>/dev/null 2>&1; then
      pass "git push (dry-run)" "$PROJECT_DIR"
    else
      warn "git push (dry-run)" "push may fail" "Check remote and credentials"
    fi
  fi
}

test_node() {
  $JSON_MODE || echo "── Node.js ──"

  if command -v node &>/dev/null; then
    local ver
    ver=$(node --version)
    pass "node installed" "$ver"
  else
    fail "node installed" "not found" "Install Node.js"
    return
  fi

  if command -v npm &>/dev/null; then
    pass "npm installed" "$(npm --version)"
  else
    fail "npm installed" "not found" "Install npm"
  fi
}

test_health_endpoint() {
  $JSON_MODE || echo "── Service Health ──"

  local endpoint="${HEALTH_ENDPOINT:-}"
  if [[ -z "$endpoint" ]]; then
    warn "health endpoint" "HEALTH_ENDPOINT not configured" "Set HEALTH_ENDPOINT env var"
    return
  fi

  local response
  if response=$(curl -sf --max-time 5 "$endpoint" 2>/dev/null); then
    if echo "$response" | grep -qi "ok"; then
      pass "health endpoint" "healthy"
    else
      warn "health endpoint" "responded but status unclear"
    fi
  else
    fail "health endpoint" "unreachable" "Check if the service is running"
  fi
}

test_api_credentials() {
  $JSON_MODE || echo "── API Credentials ──"

  # Example: check if a credentials file exists (customize path)
  local creds_file="${CREDENTIALS_FILE:-}"
  if [[ -z "$creds_file" ]]; then
    warn "credentials file" "CREDENTIALS_FILE not configured" "Set CREDENTIALS_FILE env var"
    return
  fi

  if [[ -f "$creds_file" ]]; then
    pass "credentials file exists" "$creds_file"
  else
    fail "credentials file exists" "not found at $creds_file" "Create credentials file"
  fi
}

test_docker() {
  $JSON_MODE || echo "── Docker ──"

  if command -v docker &>/dev/null; then
    pass "docker installed" "$(docker --version | head -1)"
  else
    warn "docker installed" "not found" "Install Docker Desktop"
    return
  fi

  if docker info &>/dev/null 2>&1; then
    pass "docker daemon running"
  else
    warn "docker daemon running" "daemon not responding" "Start Docker Desktop"
  fi
}

# ─── Run All Tests ───────────────────────────────────────────────────

$JSON_MODE || echo ""
$JSON_MODE || echo "🔬 Smoke Test Suite"
$JSON_MODE || echo "═══════════════════════════════════════════════════"
$JSON_MODE || echo ""

test_git
$JSON_MODE || echo ""
test_node
$JSON_MODE || echo ""
test_health_endpoint
$JSON_MODE || echo ""
test_api_credentials
$JSON_MODE || echo ""
test_docker

# ─── Summary ─────────────────────────────────────────────────────────

if $JSON_MODE; then
  printf '{"total":%d,"passed":%d,"warnings":%d,"failures":%d,"results":[%s]}\n' \
    "$TOTAL" "$PASSED" "$WARNINGS" "$FAILURES" \
    "$(IFS=,; echo "${RESULTS[*]}")"
else
  echo ""
  echo "═══════════════════════════════════════════════════"
  printf "  Total: %d | ✅ %d | ⚠️  %d | ❌ %d\n" "$TOTAL" "$PASSED" "$WARNINGS" "$FAILURES"
  echo "═══════════════════════════════════════════════════"
  echo ""
fi

exit "$FAILURES"
