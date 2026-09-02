#!/usr/bin/env bash
# asana-api.sh — Bash helpers for the Asana REST API
# Source this file: `source ./scripts/asana-api.sh`
# Requires: ASANA_PAT in env (Personal Access Token from https://app.asana.com/0/my-apps)

set -euo pipefail

ASANA_BASE="${ASANA_BASE:-https://app.asana.com/api/1.0}"

# Soft check on source — warn but don't exit so connectors.sh can load
# even when only non-Asana tools are configured.
if [[ -z "${ASANA_PAT:-}" ]]; then
  echo "WARNING: ASANA_PAT not set. Asana calls will fail until you export it." >&2
  echo "  Get a PAT at https://app.asana.com/0/my-apps" >&2
fi

# asana_get PATH [curl args...]
asana_get() {
  local path="$1"; shift
  [[ -n "${ASANA_PAT:-}" ]] || { echo "ERROR: ASANA_PAT not set" >&2; return 1; }
  curl -sS -X GET "${ASANA_BASE}${path}" \
    -H "Authorization: Bearer ${ASANA_PAT}" \
    "$@"
}

# asana_post PATH JSON_BODY
asana_post() {
  local path="$1"; shift
  local body="$1"; shift
  [[ -n "${ASANA_PAT:-}" ]] || { echo "ERROR: ASANA_PAT not set" >&2; return 1; }
  curl -sS -X POST "${ASANA_BASE}${path}" \
    -H "Authorization: Bearer ${ASANA_PAT}" \
    -H "Content-Type: application/json" \
    -d "$body" "$@"
}

# asana_put PATH JSON_BODY
asana_put() {
  local path="$1"; shift
  local body="$1"; shift
  [[ -n "${ASANA_PAT:-}" ]] || { echo "ERROR: ASANA_PAT not set" >&2; return 1; }
  curl -sS -X PUT "${ASANA_BASE}${path}" \
    -H "Authorization: Bearer ${ASANA_PAT}" \
    -H "Content-Type: application/json" \
    -d "$body" "$@"
}

# asana_delete PATH
asana_delete() {
  local path="$1"; shift
  [[ -n "${ASANA_PAT:-}" ]] || { echo "ERROR: ASANA_PAT not set" >&2; return 1; }
  curl -sS -X DELETE "${ASANA_BASE}${path}" \
    -H "Authorization: Bearer ${ASANA_PAT}" \
    "$@"
}

# extract_project_id "https://app.asana.com/0/1234567890123/list" → "1234567890123"
extract_project_id() {
  local url="$1"
  echo "$url" | sed -nE 's|.*/0/([0-9]+).*|\1|p'
}

# Helper: get /users/me
asana_me() {
  asana_get "/users/me" \
    --data-urlencode "opt_fields=name,email,workspaces.name,workspaces.gid" \
    | python3 -m json.tool
}

# Helper: list all workspaces
asana_workspaces() {
  asana_get "/workspaces" \
    --data-urlencode "opt_fields=name,is_organization" \
    | python3 -m json.tool
}

# Helper: list workspace members
asana_members() {
  local workspace_gid="$1"
  asana_get "/workspaces/${workspace_gid}/users" \
    --data-urlencode "opt_fields=name,email" \
    | python3 -m json.tool
}

# Quick auth check (call without args)
asana_ping() {
  if asana_get "/users/me" -o /dev/null -w "%{http_code}" | grep -q '^200$'; then
    echo "✓ Asana auth OK"
    return 0
  else
    echo "✗ Asana auth FAILED (check ASANA_PAT)" >&2
    return 1
  fi
}

echo "asana-api.sh loaded. Try: asana_ping"
