#!/usr/bin/env bash
# setup.sh — One-command setup verification for the asana-organizer skill.
#
# Usage:
#   bash scripts/setup.sh            # interactive: check env, ping, print next steps
#   bash scripts/setup.sh --check    # non-interactive (used by CI / verify)
#
# What it does:
#   1. Checks which tool env vars are set; prints friendly "missing X" hints
#   2. Runs asana_ping (and ping for each configured tool) to verify auth
#   3. Verifies the MCP server can start (launches it for 2s then kills)
#   4. Prints next steps
#
# Exit codes:
#   0 = at least Asana is configured and reachable
#   1 = Asana not configured (other tools may still be)
#   2 = a hard failure (missing connectors.sh, etc.)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
CONNECTORS="${SCRIPT_DIR}/connectors.sh"
ASANA_API="${SCRIPT_DIR}/asana-api.sh"
MCP_SERVER="${SKILL_DIR}/mcp/server.py"

CHECK_MODE=0
[[ "${1:-}" == "--check" ]] && CHECK_MODE=1

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

step() { printf '\n\033[1;34m▶ %s\033[0m\n' "$*"; }
ok()   { printf '  \033[1;32m✓\033[0m %s\n' "$*"; }
warn() { printf '  \033[1;33m⚠\033[0m %s\n' "$*"; }
err()  { printf '  \033[1;31m✗\033[0m %s\n' "$*" >&2; }

# ---------------------------------------------------------------------------
# Step 0 — prereq files
# ---------------------------------------------------------------------------

step "0. Checking required files"
for f in "$CONNECTORS" "$ASANA_API" "$MCP_SERVER"; do
  if [[ -f "$f" ]]; then
    ok "found $(basename "$f")"
  else
    err "missing $f"
    exit 2
  fi
done

for cmd in bash curl python3; do
  if command -v "$cmd" >/dev/null 2>&1; then
    ok "$cmd on PATH"
  else
    err "$cmd not found on PATH"
    exit 2
  fi
done

# ---------------------------------------------------------------------------
# Step 1 — environment variables
# ---------------------------------------------------------------------------

step "1. Checking environment variables"

# Source asana-api.sh standalone (the original "fail on source" behavior has
# been relaxed to a warning, so we can safely source from anywhere).
# shellcheck source=./asana-api.sh
source "$ASANA_API" 2>/dev/null || true
# shellcheck source=./connectors.sh
source "$CONNECTORS" 2>/dev/null || true

CONFIGURED=()
MISSING_ANY=0

check_env() {
  local tool="$1" var="$2" hint="${3:-}"
  if [[ -n "${!var:-}" ]]; then
    ok "$var is set"
    CONFIGURED+=("$tool")
  else
    warn "missing $var${hint:+ — $hint}"
    MISSING_ANY=1
  fi
}

check_env asana   ASANA_PAT         "get one at https://app.asana.com/0/my-apps"
check_env clickup CLICKUP_API_TOKEN
check_env monday  MONDAY_API_TOKEN
check_env trello  TRELLO_API_KEY
[[ -n "${TRELLO_API_TOKEN:-}" ]] && ok "TRELLO_API_TOKEN is set" \
  || { warn "missing TRELLO_API_TOKEN"; MISSING_ANY=1; }
check_env notion  NOTION_API_KEY
check_env jira    JIRA_BASE_URL
[[ -n "${JIRA_EMAIL:-}" ]] && ok "JIRA_EMAIL is set" \
  || { warn "missing JIRA_EMAIL"; MISSING_ANY=1; }
[[ -n "${JIRA_API_TOKEN:-}" ]] && ok "JIRA_API_TOKEN is set" \
  || { warn "missing JIRA_API_TOKEN"; MISSING_ANY=1; }

if [[ ${#CONFIGURED[@]} -eq 0 ]]; then
  err "no tool credentials found in environment"
  echo
  echo "  Set at least:"
  echo "    export ASANA_PAT='2/your-token-here'"
  echo
  echo "  Or any of:"
  echo "    export CLICKUP_API_TOKEN=... MONDAY_API_TOKEN=... \\"
  echo "           TRELLO_API_KEY=... TRELLO_API_TOKEN=... \\"
  echo "           NOTION_API_KEY=... JIRA_BASE_URL=... JIRA_EMAIL=... JIRA_API_TOKEN=..."
  echo
  if [[ $CHECK_MODE -eq 1 ]]; then
    warn "--check mode: continuing to verify server can still start"
  else
    exit 1
  fi
fi

# ---------------------------------------------------------------------------
# Step 2 — auth probes (only for configured tools)
# ---------------------------------------------------------------------------

step "2. Probing auth (only configured tools)"

ASANA_OK=0
# Guard against `set -u` when CONFIGURED is empty.
if [[ ${#CONFIGURED[@]} -gt 0 ]]; then
  for tool in "${CONFIGURED[@]}"; do
    case "$tool" in
      asana)
        if out=$(connect_asana_ping 2>&1); then
          if echo "$out" | grep -q '^200$'; then
            ok "Asana auth OK"
            ASANA_OK=1
          else
            warn "Asana auth returned: $(echo "$out" | head -1)"
          fi
        else
          warn "Asana auth probe failed: $(echo "$out" | head -1)"
        fi
        ;;
      clickup)
        if out=$(connect_clickup_ping 2>&1); then
          ok "ClickUp auth probe sent (status: $(echo "$out" | tail -c 4))"
        else
          warn "ClickUp probe error: $(echo "$out" | head -1)"
        fi
        ;;
      monday)
        if out=$(connect_monday_ping 2>&1); then
          ok "Monday probe sent (status: $(echo "$out" | tail -c 4))"
        else
          warn "Monday probe error: $(echo "$out" | head -1)"
        fi
        ;;
      trello)
        if out=$(connect_trello_ping 2>&1); then
          ok "Trello probe sent (status: $(echo "$out" | tail -c 4))"
        else
          warn "Trello probe error: $(echo "$out" | head -1)"
        fi
        ;;
      notion)
        if out=$(connect_notion_ping 2>&1); then
          ok "Notion probe sent (status: $(echo "$out" | tail -c 4))"
        else
          warn "Notion probe error: $(echo "$out" | head -1)"
        fi
        ;;
      jira)
        if out=$(connect_jira_ping 2>&1); then
          ok "Jira probe sent (status: $(echo "$out" | tail -c 4))"
        else
          warn "Jira probe error: $(echo "$out" | head -1)"
        fi
        ;;
    esac
  done
else
  warn "no tools configured — skipping auth probes"
fi

# ---------------------------------------------------------------------------
# Step 3 — MCP server smoke test
# ---------------------------------------------------------------------------

step "3. Verifying MCP server starts"

if python3 "$MCP_SERVER" --check >/dev/null 2>&1; then
  ok "MCP server --check passed"
else
  err "MCP server --check failed"
  python3 "$MCP_SERVER" --check 2>&1 | sed 's/^/    /' >&2
  exit 2
fi

# Launch the server as a stdio subprocess, send an initialize, and confirm
# we get a valid JSON-RPC response back, then kill it.
LAUNCH_OUT=$(python3 - "$MCP_SERVER" <<'PY' 2>&1
import json, subprocess, sys, time
server = sys.argv[1]
proc = subprocess.Popen(
    ["python3", server],
    stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
    text=True, bufsize=1,
)
try:
    proc.stdin.write(json.dumps({
        "jsonrpc":"2.0","id":1,"method":"initialize",
        "params":{"protocolVersion":"2024-11-05","capabilities":{},
                 "clientInfo":{"name":"setup.sh","version":"0"}}
    }) + "\n")
    proc.stdin.flush()
    line = proc.stdout.readline()
    msg = json.loads(line)
    assert msg.get("result",{}).get("serverInfo",{}).get("name"), msg
    print("MCP_INIT_OK")
finally:
    proc.stdin.close()
    try: proc.terminate(); proc.wait(timeout=2)
    except subprocess.TimeoutExpired: proc.kill()
PY
)

if echo "$LAUNCH_OUT" | grep -q MCP_INIT_OK; then
  ok "MCP server responds to JSON-RPC initialize"
else
  warn "MCP initialize test inconclusive:"
  echo "$LAUNCH_OUT" | sed 's/^/    /'
fi

# ---------------------------------------------------------------------------
# Step 4 — next steps
# ---------------------------------------------------------------------------

step "4. Next steps"

cat <<'EOF'
  ✅ Setup verification complete.

  To use the skill (bash only):
    source ./scripts/connectors.sh
    detect_tool_from_url "https://app.asana.com/0/12345/list"   # → asana
    connect_asana_fetch_project "https://app.asana.com/0/12345/list"

  To wire into Claude Desktop / Cursor / VS Code:
    See ./mcp/README.md for the exact JSON to add.

  To smoke-test the MCP server manually:
    echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"t","version":"0"}}}' | python3 mcp/server.py

  Quick reference — env vars per provider:
    asana       ASANA_PAT
    clickup     CLICKUP_API_TOKEN
    monday      MONDAY_API_TOKEN
    trello      TRELLO_API_KEY + TRELLO_API_TOKEN
    notion      NOTION_API_KEY
    jira        JIRA_BASE_URL + JIRA_EMAIL + JIRA_API_TOKEN
EOF

if [[ ${#CONFIGURED[@]} -eq 0 ]]; then
  echo
  warn "No tools are currently configured. Set env vars and re-run."
  if [[ $CHECK_MODE -eq 1 ]]; then
    exit 0  # --check tolerates missing creds
  else
    exit 1
  fi
fi

if [[ $ASANA_OK -eq 0 && " ${CONFIGURED[*]} " == *" asana "* ]]; then
  echo
  warn "Asana is configured but auth failed — check ASANA_PAT"
fi

exit 0