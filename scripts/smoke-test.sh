#!/bin/bash
# ============================================================================
# Infrastructure Smoke Test Suite
# Run after: macOS updates, OpenClaw updates, Node.js updates, token renewals
# Usage: ./scripts/smoke-test.sh [--json] [--fix]
# ============================================================================

set -uo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

PASS=0
FAIL=0
WARN=0
RESULTS=()
JSON_MODE=false
FIX_MODE=false

for arg in "$@"; do
  case $arg in
    --json) JSON_MODE=true ;;
    --fix) FIX_MODE=true ;;
  esac
done

# ── Test Runners ─────────────────────────────────────────────────────────────
# run_test: Hard failure — counts toward exit code
# run_warn: Soft warning — noted but doesn't fail the suite

run_test() {
  local name="$1"
  local cmd="$2"
  local fix_hint="${3:-}"

  if eval "$cmd" > /dev/null 2>&1; then
    PASS=$((PASS + 1))
    RESULTS+=("PASS|$name|ok|$fix_hint")
    if [ "$JSON_MODE" = false ]; then
      echo -e "  ${GREEN}✅ PASS${NC}  $name"
    fi
  else
    FAIL=$((FAIL + 1))
    RESULTS+=("FAIL|$name|failed|$fix_hint")
    if [ "$JSON_MODE" = false ]; then
      echo -e "  ${RED}❌ FAIL${NC}  $name"
      if [ -n "$fix_hint" ]; then
        echo -e "         ${YELLOW}Fix: $fix_hint${NC}"
      fi
    fi
  fi
}

run_warn() {
  local name="$1"
  local cmd="$2"
  local fix_hint="${3:-}"

  if eval "$cmd" > /dev/null 2>&1; then
    PASS=$((PASS + 1))
    RESULTS+=("PASS|$name|ok|$fix_hint")
    if [ "$JSON_MODE" = false ]; then
      echo -e "  ${GREEN}✅ PASS${NC}  $name"
    fi
  else
    WARN=$((WARN + 1))
    RESULTS+=("WARN|$name|warning|$fix_hint")
    if [ "$JSON_MODE" = false ]; then
      echo -e "  ${YELLOW}⚠️  WARN${NC}  $name"
      if [ -n "$fix_hint" ]; then
        echo -e "         ${YELLOW}Fix: $fix_hint${NC}"
      fi
    fi
  fi
}

# ── Header ───────────────────────────────────────────────────────────────────

if [ "$JSON_MODE" = false ]; then
  echo ""
  echo -e "${CYAN}🔍 Infrastructure Smoke Test Suite${NC}"
  echo -e "${CYAN}$(date '+%Y-%m-%d %H:%M:%S %Z')${NC}"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
fi

# ── GitHub ──────────────────────────────────────────────────────────────────
# Verify GitHub CLI and authentication
if [ "$JSON_MODE" = false ]; then echo -e "${CYAN}GitHub${NC}"; fi
run_test "gh CLI installed" "which gh"
run_test "gh auth valid" "gh auth status 2>&1 | grep -q 'Logged in'" "gh auth login -h github.com"
run_test "git push access" "cd <YOUR_REPO_PATH> && git push --dry-run 2>&1 | grep -v 'fatal'" "Fix gh auth first"
if [ "$JSON_MODE" = false ]; then echo ""; fi

# ── External APIs ───────────────────────────────────────────────────────────
# Add your API checks here. Example:
# if [ "$JSON_MODE" = false ]; then echo -e "${CYAN}Your API${NC}"; fi
# run_test "API credentials exist" "test -f <YOUR_CREDENTIALS_PATH>"
# run_test "API token works" "curl -sf -H 'Authorization: Bearer <YOUR_TOKEN>' '<YOUR_API_ENDPOINT>' | grep -q 'ok'" "Check credentials"
# if [ "$JSON_MODE" = false ]; then echo ""; fi

# ── OpenClaw ────────────────────────────────────────────────────────────────
if [ "$JSON_MODE" = false ]; then echo -e "${CYAN}OpenClaw${NC}"; fi
run_test "OpenClaw installed" "which openclaw"
run_test "Gateway running" "openclaw status 2>&1 | grep -qi 'gateway'" "openclaw gateway start"
run_test "Gateway version matches npm" "openclaw status 2>&1 | grep -q \"\$(openclaw --version)\"" "openclaw gateway restart"
if [ "$JSON_MODE" = false ]; then echo ""; fi

# ── Node.js ─────────────────────────────────────────────────────────────────
if [ "$JSON_MODE" = false ]; then echo -e "${CYAN}Node.js${NC}"; fi
run_test "Node.js installed" "which node"
run_test "Node.js version" "node --version | grep -q 'v2[0-9]'" "Update Node.js"
run_test "npm installed" "which npm"
if [ "$JSON_MODE" = false ]; then echo ""; fi

# ── Paired Devices ──────────────────────────────────────────────────────────
# Uncomment and customize for your setup:
# if [ "$JSON_MODE" = false ]; then echo -e "${CYAN}Paired Devices${NC}"; fi
# run_warn "<YOUR_DEVICE> paired" "openclaw devices list --json 2>&1 | grep -q '<YOUR_DEVICE>'" "Re-pair: openclaw node pair"
# if [ "$JSON_MODE" = false ]; then echo ""; fi

# ── Add Your Own Sections ───────────────────────────────────────────────────
# Template:
#
# if [ "$JSON_MODE" = false ]; then echo -e "${CYAN}Section Name${NC}"; fi
# run_test "Check name" "command_to_verify" "How to fix if it fails"
# run_warn "Optional check" "command_to_verify" "Fix hint"
# if [ "$JSON_MODE" = false ]; then echo ""; fi

# ── Summary ─────────────────────────────────────────────────────────────────
TOTAL=$((PASS + FAIL + WARN))

if [ "$JSON_MODE" = true ]; then
  echo "{"
  echo "  \"timestamp\": \"$(date -u '+%Y-%m-%dT%H:%M:%SZ')\","
  echo "  \"total\": $TOTAL,"
  echo "  \"pass\": $PASS,"
  echo "  \"fail\": $FAIL,"
  echo "  \"warn\": $WARN,"
  echo "  \"results\": ["
  first=true
  for r in "${RESULTS[@]}"; do
    IFS='|' read -r status name detail fix <<< "$r"
    if [ "$first" = true ]; then first=false; else echo ","; fi
    echo -n "    {\"status\":\"$status\",\"name\":\"$name\",\"detail\":\"$detail\",\"fix\":\"$fix\"}"
  done
  echo ""
  echo "  ]"
  echo "}"
else
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  if [ $FAIL -eq 0 ]; then
    echo -e "  ${GREEN}ALL CLEAR${NC} — $PASS/$TOTAL passed, $WARN warnings"
  else
    echo -e "  ${RED}$FAIL FAILURES${NC} — $PASS passed, $FAIL failed, $WARN warnings"
  fi
  echo ""
fi

exit $FAIL
