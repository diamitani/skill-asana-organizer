#!/usr/bin/env bash
# setup.sh — One-command setup + health check for the asana-organizer skill
# Usage: bash scripts/setup.sh [--check]
#
# --check: run all checks and exit (used by tests / CI / MCP server self-test)
#          Without --check, also runs a friendly interactive setup.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"
CHECK_ONLY=false
if [[ "${1:-}" == "--check" ]]; then
  CHECK_ONLY=true
fi

echo "==============================================="
echo "  Asana Organizer — Setup & Health Check"
echo "==============================================="
echo "Skill dir: $SKILL_DIR"
echo ""

# 1. Check prerequisites
echo "▶ Checking prerequisites..."

missing=()
for cmd in bash python3 curl jq; do
  if ! command -v "$cmd" &> /dev/null; then
    missing+=("$cmd")
  fi
done

if [[ ${#missing[@]} -gt 0 ]]; then
  echo "  ✗ Missing commands: ${missing[*]}"
  echo "  Install with: brew install ${missing[*]}"
  if $CHECK_ONLY; then
    exit 1
  fi
else
  echo "  ✓ bash, python3, curl, jq all present"
fi

# 2. Source the connectors
echo ""
echo "▶ Loading connector layer..."

# shellcheck disable=SC1091
if ! source "$SCRIPT_DIR/connectors.sh" 2>/dev/null; then
  echo "  ✗ Failed to source connectors.sh"
  if $CHECK_ONLY; then
    exit 1
  fi
  exit 1
fi
echo "  ✓ connectors.sh loaded (6 tools supported)"

# 3. Check API tokens
echo ""
echo "▶ Checking API tokens..."

token_status=()
for tool_env in "asana:ASANA_PAT" "clickup:CLICKUP_API_TOKEN" "monday:MONDAY_API_TOKEN" "trello:TRELLO_API_KEY, TRELLO_API_TOKEN" "notion:NOTION_API_KEY" "jira:JIRA_BASE_URL, JIRA_EMAIL, JIRA_API_TOKEN"; do
  tool="${tool_env%%:*}"
  vars="${tool_env#*:}"
  found=false
  for var in ${vars//,/ }; do
    if [[ -n "${!var:-}" ]]; then
      found=true
      break
    fi
  done
  if $found; then
    token_status+=("  ✓ $tool")
  else
    token_status+=("  ○ $tool (not configured — env: $vars)")
  fi
done
printf '%s\n' "${token_status[@]}"

configured_count=$(printf '%s\n' "${token_status[@]}" | grep -c '✓' || true)
if [[ "$configured_count" -eq 0 ]]; then
  echo ""
  echo "  ⚠ No tools configured. Set at least one of:"
  echo "    export ASANA_PAT='2/your-token-here'"
  echo "    export CLICKUP_API_TOKEN='pk_...'"
  echo "    # etc."
  if $CHECK_ONLY; then
    echo ""
    echo "  (--check mode: not failing because no token set)"
    exit 0
  fi
fi

# 4. Test configured tools
echo ""
echo "▶ Testing configured tools..."
if [[ "$configured_count" -gt 0 ]]; then
  for tool in asana clickup monday trello notion jira; do
    if declare -f "connect_${tool}_ping" &> /dev/null; then
      result=$(connect_${tool}_ping 2>&1 | tail -1 || true)
      if [[ "$result" =~ ^(200|401|403)$ ]]; then
        echo "  ✓ $tool reachable (HTTP $result — 401/403 = token issue, OK for setup)"
      else
        echo "  ? $tool returned: $result"
      fi
    fi
  done
else
  echo "  (skipped — no tokens configured)"
fi

# 5. Verify MCP server starts
echo ""
echo "▶ Checking MCP server..."
MCP_SERVER="$SKILL_DIR/mcp/server.py"
if [[ ! -f "$MCP_SERVER" ]]; then
  echo "  ✗ MCP server not found: $MCP_SERVER"
elif $CHECK_ONLY; then
  # Quick syntax check
  if python3 -c "import ast; ast.parse(open('$MCP_SERVER').read())" 2>/dev/null; then
    echo "  ✓ MCP server script is valid Python"
  else
    echo "  ✗ MCP server script has syntax errors"
    exit 1
  fi
else
  # Boot test: start, send initialize, kill
  echo "  Testing MCP server boot (2s timeout)..."
  if command -v timeout &> /dev/null; then
    timeout 2 python3 "$MCP_SERVER" < /dev/null &> /tmp/mcp_boot.log || true
    if grep -q "MCP server started" /tmp/mcp_boot.log 2>/dev/null; then
      echo "  ✓ MCP server starts cleanly"
    else
      echo "  ⚠ MCP server boot test inconclusive (check $MCP_SERVER manually)"
    fi
  else
    echo "  (skipped — GNU 'timeout' not available)"
  fi
fi

# 6. Summary
echo ""
echo "==============================================="
echo "  Setup Complete"
echo "==============================================="
echo ""
echo "Next steps:"
echo "  1. Set an API token (e.g. export ASANA_PAT='...')"
echo "  2. Use the skill:"
echo "     - In Claude Code: say 'organize my Asana project at [URL]'"
echo "     - Via MCP: add to your client's MCP config (see mcp/README.md)"
echo "     - Via CLI: source scripts/connectors.sh && connect_asana_fetch_project [URL]"
echo ""
