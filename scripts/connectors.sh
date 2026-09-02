#!/usr/bin/env bash
# connectors.sh — Unified multi-tool connector layer for the asana-organizer skill.
#
# Provides normalized fetch/apply operations across:
#   - Asana      (env: ASANA_PAT)         — sourced from ./asana-api.sh
#   - ClickUp    (env: CLICKUP_API_TOKEN)
#   - Monday.com (env: MONDAY_API_TOKEN)
#   - Trello     (env: TRELLO_API_KEY + TRELLO_API_TOKEN)
#   - Notion     (env: NOTION_API_KEY)
#   - Jira       (env: JIRA_BASE_URL + JIRA_EMAIL + JIRA_API_TOKEN)
#
# Source this file:   `source ./scripts/connectors.sh`
#
# Public API:
#   detect_tool_from_url        <url>           → asana|clickup|monday|trello|notion|jira
#   connect_<tool>_fetch_project <url|id>       → JSON (normalized shape)
#   connect_<tool>_apply_changes  <id> <json>    → JSON
#
# Low-level HTTP wrappers (also exposed):
#   <tool>_get / <tool>_post / <tool>_put / <tool>_delete   (PATH [body])
#
# Normalized project shape (see connect_asana_fetch_project):
#   {"tool": "...", "project_id": "...", "project_name": "...",
#    "sections": [{"id": "...", "name": "..."}],
#    "tasks":    [{"id": "...", "name": "...", "notes": "...",
#                  "section_id": "...", "assignee": "...",
#                  "due_date": "...", "completed": false}]}

set -euo pipefail

# --- Resolve script directory so we can re-source asana-api.sh --------------
CON_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CON_SKILL_DIR="$(cd "${CON_SCRIPT_DIR}/.." && pwd)"

if [[ -f "${CON_SCRIPT_DIR}/asana-api.sh" ]]; then
  # shellcheck source=./asana-api.sh
  source "${CON_SCRIPT_DIR}/asana-api.sh"
else
  echo "ERROR: asana-api.sh not found next to connectors.sh" >&2
  return 1 2>/dev/null || exit 1
fi

# ============================================================================
# URL detection
# ============================================================================

# detect_tool_from_url "https://app.asana.com/0/123/list" → "asana"
detect_tool_from_url() {
  local url="${1:-}"
  if [[ -z "$url" ]]; then
    echo "unknown"
    return 1
  fi
  case "$url" in
    *app.asana.com*|*asana.com*)                       echo "asana" ;;
    *app.clickup.com*|*clickup.com*)                   echo "clickup" ;;
    *monday.com*|*view.monday.com*)                    echo "monday" ;;
    *trello.com/c/*|*trello.com/b/*|*trello.com/1/*)   echo "trello" ;;
    *notion.so*|*notion.site*)                         echo "notion" ;;
    *atlassian.net*|*atlassian.com*|*jira.*)           echo "jira" ;;
    *)
      echo "unknown" >&2
      return 1
      ;;
  esac
}

# ============================================================================
# Generic HTTP helper
# ============================================================================

# _con_http METHOD TOOL PATH [BODY] [extra curl args...]
# Streams JSON to stdout, captures HTTP status to ${CON_LAST_STATUS}.
_con_http() {
  local method="$1" tool="$2" path="$3" body="${4:-}"
  shift 4 || true
  local base_url="" auth_args=()

  case "$tool" in
    asana)
      base_url="${ASANA_BASE:-https://app.asana.com/api/1.0}"
      auth_args=(-H "Authorization: Bearer ${ASANA_PAT:-}")
      ;;
    clickup)
      base_url="https://api.clickup.com/api/v2"
      auth_args=(-H "Authorization: ${CLICKUP_API_TOKEN:-}")
      ;;
    monday)
      base_url="https://api.monday.com/v2"
      auth_args=(-H "Authorization: ${MONDAY_API_TOKEN:-}")
      ;;
    trello)
      base_url="https://api.trello.com/1"
      auth_args=(
        --data-urlencode "key=${TRELLO_API_KEY:-}"
        --data-urlencode "token=${TRELLO_API_TOKEN:-}"
      )
      ;;
    notion)
      base_url="https://api.notion.com/v1"
      auth_args=(
        -H "Authorization: Bearer ${NOTION_API_KEY:-}"
        -H "Notion-Version: 2022-06-28"
      )
      ;;
    jira)
      base_url="${JIRA_BASE_URL:-}/rest/api/3"
      if [[ -n "${JIRA_EMAIL:-}" && -n "${JIRA_API_TOKEN:-}" ]]; then
        local basic
        basic=$(printf '%s:%s' "$JIRA_EMAIL" "$JIRA_API_TOKEN" | base64 | tr -d '\n')
        auth_args=(-H "Authorization: Basic ${basic}")
      fi
      ;;
    *)
      echo "{\"error\":\"unknown tool: $tool\"}" >&2
      return 1
      ;;
  esac

  local url="${base_url}${path}"
  local curl_args=(-sS -X "$method" "$url" -H "Accept: application/json" "${auth_args[@]}" "$@" -w "\n%{http_code}")
  local response
  response=$(curl "${curl_args[@]}" ${body:+-d "$body"} 2>/dev/null || echo "")

  CON_LAST_STATUS="${response##*$'\n'}"
  response="${response%$'\n'*}"

  if [[ "${CON_LAST_STATUS}" =~ ^2 ]]; then
    printf '%s' "$response"
  else
    echo "HTTP ${CON_LAST_STATUS} from ${tool} ${method} ${path}: ${response}" >&2
    printf '%s' "$response"
  fi
}

# Public low-level wrappers: <tool>_get / <tool>_post / <tool>_put / <tool>_delete
asana_get()    { _con_http GET    asana "$1" "" "${@:2}"; }
asana_post()   { _con_http POST   asana "$1" "$2" "${@:3}"; }
asana_put()    { _con_http PUT    asana "$1" "$2" "${@:3}"; }
asana_delete() { _con_http DELETE asana "$1" "" "${@:2}"; }

clickup_get()    { _con_http GET    clickup "$1" "" "${@:2}"; }
clickup_post()   { _con_http POST   clickup "$1" "$2" "${@:3}"; }
clickup_put()    { _con_http PUT    clickup "$1" "$2" "${@:3}"; }
clickup_delete() { _con_http DELETE clickup "$1" "" "${@:2}"; }

monday_get()    { _con_http GET    monday "$1" "" "${@:2}"; }
monday_post()   { _con_http POST   monday "$1" "$2" "${@:3}"; }
monday_put()    { _con_http PUT    monday "$1" "$2" "${@:3}"; }
monday_delete() { _con_http DELETE monday "$1" "" "${@:2}"; }

trello_get()    { _con_http GET    trello "$1" "" "${@:2}"; }
trello_post()   { _con_http POST   trello "$1" "$2" "${@:3}"; }
trello_put()    { _con_http PUT    trello "$1" "$2" "${@:3}"; }
trello_delete() { _con_http DELETE trello "$1" "" "${@:2}"; }

notion_get()    { _con_http GET    notion "$1" "" "${@:2}"; }
notion_post()   { _con_http POST   notion "$1" "$2" "${@:3}"; }
notion_put()    { _con_http PUT    notion "$1" "$2" "${@:3}"; }
notion_delete() { _con_http DELETE notion "$1" "" "${@:2}"; }

jira_get()    { _con_http GET    jira "$1" "" "${@:2}"; }
jira_post()   { _con_http POST   jira "$1" "$2" "${@:3}"; }
jira_put()    { _con_http PUT    jira "$1" "$2" "${@:3}"; }
jira_delete() { _con_http DELETE jira "$1" "" "${@:2}"; }

# ============================================================================
# Tool config helpers (env checks)
# ============================================================================

# _con_require_env TOOL — prints a friendly "missing X" message if not configured
_con_require_env() {
  local tool="$1"
  case "$tool" in
    asana)   [[ -n "${ASANA_PAT:-}" ]]         || { echo "missing ASANA_PAT (get one at https://app.asana.com/0/my-apps)" >&2; return 1; } ;;
    clickup) [[ -n "${CLICKUP_API_TOKEN:-}" ]] || { echo "missing CLICKUP_API_TOKEN" >&2; return 1; } ;;
    monday)  [[ -n "${MONDAY_API_TOKEN:-}" ]]  || { echo "missing MONDAY_API_TOKEN" >&2; return 1; } ;;
    trello)  { [[ -n "${TRELLO_API_KEY:-}" ]] && [[ -n "${TRELLO_API_TOKEN:-}" ]]; } \
              || { echo "missing TRELLO_API_KEY or TRELLO_API_TOKEN" >&2; return 1; } ;;
    notion)  [[ -n "${NOTION_API_KEY:-}" ]]    || { echo "missing NOTION_API_KEY (integration secret)" >&2; return 1; } ;;
    jira)    { [[ -n "${JIRA_BASE_URL:-}" ]] && [[ -n "${JIRA_EMAIL:-}" ]] && [[ -n "${JIRA_API_TOKEN:-}" ]]; } \
              || { echo "missing JIRA_BASE_URL / JIRA_EMAIL / JIRA_API_TOKEN" >&2; return 1; } ;;
    *) echo "unknown tool: $tool" >&2; return 1 ;;
  esac
}

# connect_<tool>_ping — lightweight auth probe; returns 0 if configured (HTTP status in body)
connect_asana_ping()   { _con_require_env asana   && asana_get   "/users/me"   -o /dev/null -w "%{http_code}\n"; }
connect_clickup_ping() { _con_require_env clickup && clickup_get "/user"       -o /dev/null -w "%{http_code}\n"; }
connect_monday_ping()  { _con_require_env monday  && monday_post "" '{"query":"{ me { id email name } }"}' -o /dev/null -w "%{http_code}\n"; }
connect_trello_ping()  { _con_require_env trello  && trello_get  "/members/me" -o /dev/null -w "%{http_code}\n"; }
connect_notion_ping()  { _con_require_env notion  && notion_get  "/users/me"   -o /dev/null -w "%{http_code}\n"; }
connect_jira_ping()    { _con_require_env jira    && jira_get    "/myself"     -o /dev/null -w "%{http_code}\n"; }

# ============================================================================
# ID extraction
# ============================================================================

_con_extract_project_id() {
  local tool="$1" url_or_id="$2"
  if [[ "$url_or_id" =~ ^[0-9]+$ ]] || [[ "$tool" == "jira" && "$url_or_id" =~ ^[A-Z][A-Z0-9_]*-[0-9]+$ ]]; then
    echo "$url_or_id"; return 0
  fi
  case "$tool" in
    asana)   echo "$url_or_id" | sed -nE 's|.*/0/([0-9]+).*|\1|p' ;;
    clickup) echo "$url_or_id" | sed -nE 's|.*/([0-9]+)(/.*)?$|\1|p' ;;
    monday)  echo "$url_or_id" | sed -nE 's|boards/([0-9]+).*|\1|p' ;;
    trello)  echo "$url_or_id" | sed -nE 's|.*/b/([A-Za-z0-9]+)/.*|\1|p' ;;
    notion)  echo "$url_or_id" | sed -nE 's|.*([0-9a-fA-F]{32}).*|\1|p' ;;
    jira)    echo "$url_or_id" | sed -nE 's|.*/browse/([A-Z][A-Z0-9_]*-[0-9]+).*|\1|p' ;;
    *) echo "$url_or_id" ;;
  esac
}

# ============================================================================
# ASANA — public API
# ============================================================================

connect_asana_fetch_project() {
  local url_or_id="$1"
  _con_require_env asana || return 1
  local pid; pid=$(_con_extract_project_id asana "$url_or_id")
  [[ -n "$pid" ]] || { echo '{"error":"could not extract Asana project id"}' >&2; return 1; }

  local proj sections tasks
  proj=$(asana_get "/projects/$pid" --data-urlencode "opt_fields=name,notes") || true
  sections=$(asana_get "/projects/$pid/sections" --data-urlencode "opt_fields=name") || true
  tasks=$(asana_get "/projects/$pid/tasks" \
    --data-urlencode "opt_fields=name,notes,assignee.name,due_on,completed,memberships.section.gid" \
    --data-urlencode "limit=200") || true

  python3 - "$pid" "$proj" "$sections" "$tasks" <<'PY'
import json, sys
pid, proj_s, sec_s, task_s = sys.argv[1:5]
def safe(j):
    try: return json.loads(j or '{}')
    except Exception: return {}
p  = safe(proj_s).get('data', {})
ss = safe(sec_s).get('data', [])
ts = safe(task_s).get('data', [])

sections = [{"id": s.get('gid',''), "name": s.get('name','')} for s in ss]
tasks = []
for t in ts:
    ms = t.get('memberships') or []
    sid = ms[0]['section']['gid'] if ms and isinstance(ms[0].get('section'), dict) else ''
    assignee = ''
    if t.get('assignee'):
        assignee = t['assignee'].get('name') or t['assignee'].get('gid') or ''
    tasks.append({
        "id": t.get('gid',''),
        "name": t.get('name',''),
        "notes": t.get('notes','') or '',
        "section_id": sid,
        "assignee": assignee,
        "due_date": t.get('due_on') or '',
        "completed": bool(t.get('completed', False)),
    })
print(json.dumps({
    "tool": "asana",
    "project_id": pid,
    "project_name": p.get('name',''),
    "project_notes": p.get('notes','') or '',
    "sections": sections,
    "tasks": tasks,
}, indent=2))
PY
}

connect_asana_apply_changes() {
  local project_id="$1" changes_json="$2"
  _con_require_env asana || return 1
  python3 - "$project_id" "$changes_json" <<'PY'
import json, sys, subprocess, os
pid, raw = sys.argv[1:3]
try:
    changes = json.loads(raw)
except Exception as e:
    print(json.dumps({"error": f"invalid json: {e}"}))
    sys.exit(1)

results = []
for ch in changes.get("rewrites", []):
    tid = ch.get("task_id"); name = ch.get("name"); notes = ch.get("notes")
    if not tid: continue
    body = json.dumps({"data": {k: v for k, v in (("name", name), ("notes", notes)) if v is not None}})
    r = subprocess.run(
        ["curl", "-sS", "-X", "PUT",
         f"{os.environ.get('ASANA_BASE','https://app.asana.com/api/1.0')}/tasks/{tid}",
         "-H", f"Authorization: Bearer {os.environ.get('ASANA_PAT','')}",
         "-H", "Content-Type: application/json",
         "-d", body, "-w", "\n%{http_code}"],
        capture_output=True, text=True)
    status = r.stdout.rsplit('\n', 1)[-1]
    results.append({"task_id": tid, "status": status})

for sec in changes.get("create_sections", []):
    name = sec.get("name"); if not name: continue
    body = json.dumps({"data": {"name": name}})
    r = subprocess.run(
        ["curl", "-sS", "-X", "POST",
         f"{os.environ.get('ASANA_BASE','https://app.asana.com/api/1.0')}/projects/{pid}/sections",
         "-H", f"Authorization: Bearer {os.environ.get('ASANA_PAT','')}",
         "-H", "Content-Type: application/json", "-d", body, "-w", "\n%{http_code}"],
        capture_output=True, text=True)
    status = r.stdout.rsplit('\n', 1)[-1]
    results.append({"created_section": name, "status": status})

for mv in changes.get("moves", []):
    sec_id = mv.get("section_id"); task_id = mv.get("task_id")
    if not (sec_id and task_id): continue
    body = json.dumps({"data": {"task": task_id}})
    r = subprocess.run(
        ["curl", "-sS", "-X", "POST",
         f"{os.environ.get('ASANA_BASE','https://app.asana.com/api/1.0')}/sections/{sec_id}/addTask",
         "-H", f"Authorization: Bearer {os.environ.get('ASANA_PAT','')}",
         "-H", "Content-Type: application/json", "-d", body, "-w", "\n%{http_code}"],
        capture_output=True, text=True)
    status = r.stdout.rsplit('\n', 1)[-1]
    results.append({"moved_task": task_id, "to_section": sec_id, "status": status})

print(json.dumps({"tool":"asana","project_id":pid,"results":results}, indent=2))
PY
}

# ============================================================================
# CLICKUP — public API
# ============================================================================
# ClickUp "project" = Space (top) or List. We treat List as the project unit
# because that's where tasks live. Sections in ClickUp are statuses.

connect_clickup_fetch_project() {
  local url_or_id="$1"
  _con_require_env clickup || return 1
  local list_id; list_id=$(_con_extract_project_id clickup "$url_or_id")
  [[ -n "$list_id" ]] || { echo '{"error":"could not extract ClickUp list id"}' >&2; return 1; }

  local list statuses tasks
  list=$(clickup_get "/list/$list_id" --data-urlencode "include_closed=true") || true
  statuses=$(clickup_get "/list/$list_id/status") || true
  tasks=$(clickup_get "/list/$list_id/task" --data-urlencode "include_closed=true" \
    --data-urlencode "subtasks=true" --data-urlencode "page=0") || true

  python3 - "$list_id" "$list" "$statuses" "$tasks" <<'PY'
import json, sys
list_id, list_s, stat_s, task_s = sys.argv[1:5]
def safe(j):
    try: return json.loads(j or '{}')
    except Exception: return {}
l  = safe(list_s)
ss = safe(stat_s).get('statuses', [])
ts = safe(task_s).get('tasks', [])

sections = [{"id": s.get('id') or s.get('status',''), "name": s.get('status','')} for s in ss]
tasks = []
for t in ts:
    status_obj = t.get('status') or {}
    tasks.append({
        "id": t.get('id',''),
        "name": t.get('name',''),
        "notes": t.get('description','') or (t.get('text_content') or ''),
        "section_id": status_obj.get('id','') if isinstance(status_obj, dict) else '',
        "assignee": ((t.get('assignees') or [{}])[0].get('username','') if t.get('assignees') else ''),
        "due_date": (t.get('due_date') or '')[:10],
        "completed": bool(t.get('status', {}).get('type') == 'closed'),
    })
print(json.dumps({
    "tool": "clickup",
    "project_id": list_id,
    "project_name": l.get('name',''),
    "project_notes": l.get('description','') or '',
    "sections": sections,
    "tasks": tasks,
}, indent=2))
PY
}

connect_clickup_apply_changes() {
  local project_id="$1" changes_json="$2"
  _con_require_env clickup || return 1
  python3 - "$project_id" "$changes_json" <<'PY'
import json, sys, subprocess, os
pid, raw = sys.argv[1:3]
changes = json.loads(raw)
results = []
token = os.environ.get('CLICKUP_API_TOKEN','')
base  = 'https://api.clickup.com/api/v2'

for ch in changes.get("rewrites", []):
    tid = ch.get("task_id"); name = ch.get("name"); notes = ch.get("notes")
    body = json.dumps({k: v for k, v in (("name", name), ("description", notes)) if v is not None})
    r = subprocess.run(["curl","-sS","-X","PUT", f"{base}/task/{tid}",
        "-H", f"Authorization: {token}", "-H","Content-Type: application/json",
        "-d", body, "-w","\n%{http_code}"], capture_output=True, text=True)
    results.append({"task_id": tid, "status": r.stdout.rsplit('\n',1)[-1]})

for mv in changes.get("moves", []):
    task_id, status = mv.get("task_id"), mv.get("section_id") or mv.get("status")
    if not (task_id and status): continue
    body = json.dumps({"status": status})
    r = subprocess.run(["curl","-sS","-X","PUT", f"{base}/task/{task_id}",
        "-H", f"Authorization: {token}", "-H","Content-Type: application/json",
        "-d", body, "-w","\n%{http_code}"], capture_output=True, text=True)
    results.append({"moved_task": task_id, "status": r.stdout.rsplit('\n',1)[-1]})

print(json.dumps({"tool":"clickup","project_id":pid,"results":results}, indent=2))
PY
}

# ============================================================================
# MONDAY.COM — public API
# ============================================================================
# Monday.com uses GraphQL. "Project" = Board. "Sections" = Groups. "Tasks" = Items.

connect_monday_fetch_project() {
  local url_or_id="$1"
  _con_require_env monday || return 1
  local board_id; board_id=$(_con_extract_project_id monday "$url_or_id")
  [[ -n "$board_id" ]] || { echo '{"error":"could not extract Monday board id"}' >&2; return 1; }

  local board groups items
  board=$(monday_post "" "{\"query\":\"query($id:[ID!]){ boards(ids:$id){ name description } }\",\"variables\":{\"id\":[\"$board_id\"]}}") || true
  groups=$(monday_post "" "{\"query\":\"query($id:[ID!]){ boards(ids:$id){ groups { id title } } }\",\"variables\":{\"id\":[\"$board_id\"]}}") || true
  items=$(monday_post "" "{\"query\":\"query($id:[ID!]){ boards(ids:$id){ items_page(limit:200){ items { id name group { id } column_values { id text } } } } }\",\"variables\":{\"id\":[\"$board_id\"]}}") || true

  python3 - "$board_id" "$board" "$groups" "$items" <<'PY'
import json, sys
board_id, b_s, g_s, i_s = sys.argv[1:5]
def safe(j):
    try: return json.loads(j or '{}')
    except Exception: return {}
b  = (safe(b_s).get('data') or {}).get('boards') or [{}]
b  = b[0] if b else {}
gs = ((safe(g_s).get('data') or {}).get('boards') or [{}])[0].get('groups') or []
its = (((safe(i_s).get('data') or {}).get('boards') or [{}])[0].get('items_page') or {}).get('items') or []

sections = [{"id": g.get('id',''), "name": g.get('title','')} for g in gs]
tasks = []
for it in its:
    notes = ''
    for c in it.get('column_values') or []:
        if c.get('id') in ('text','long_text','notes','description'):
            notes = c.get('text','') or notes
    tasks.append({
        "id": it.get('id',''),
        "name": it.get('name',''),
        "notes": notes,
        "section_id": (it.get('group') or {}).get('id',''),
        "assignee": '',
        "due_date": '',
        "completed": False,
    })
print(json.dumps({
    "tool": "monday",
    "project_id": board_id,
    "project_name": b.get('name',''),
    "project_notes": b.get('description','') or '',
    "sections": sections,
    "tasks": tasks,
}, indent=2))
PY
}

connect_monday_apply_changes() {
  local project_id="$1" changes_json="$2"
  _con_require_env monday || return 1
  python3 - "$project_id" "$changes_json" <<'PY'
import json, sys, subprocess, os
pid, raw = sys.argv[1:3]
changes = json.loads(raw)
token = os.environ.get('MONDAY_API_TOKEN','')
base  = 'https://api.monday.com/v2'
results = []

for ch in changes.get("rewrites", []):
    iid = ch.get("task_id"); name = ch.get("name"); notes = ch.get("notes")
    cv = []
    if name is not None: cv.append({"id":"name","value":name})
    if notes is not None: cv.append({"id":"long_text","value":{"text":notes}})
    if not cv or not iid: continue
    body = json.dumps({"query":f"mutation {{ change_multiple_column_values(item_id:{iid}, board_id:{pid}, column_values:'{json.dumps(cv)}') {{ id }} }}"})
    r = subprocess.run(["curl","-sS","-X","POST",base,
        "-H",f"Authorization: {token}","-H","Content-Type: application/json",
        "-d",body,"-w","\n%{http_code}"], capture_output=True, text=True)
    results.append({"task_id": iid, "status": r.stdout.rsplit('\n',1)[-1]})

for sec in changes.get("create_sections", []):
    title = sec.get("name"); if not title: continue
    body = json.dumps({"query":f"mutation {{ create_group(board_id:{pid}, group_name:\"{title}\") {{ id }} }}"})
    r = subprocess.run(["curl","-sS","-X","POST",base,
        "-H",f"Authorization: {token}","-H","Content-Type: application/json",
        "-d",body,"-w","\n%{http_code}"], capture_output=True, text=True)
    results.append({"created_group": title, "status": r.stdout.rsplit('\n',1)[-1]})

for mv in changes.get("moves", []):
    iid, gid = mv.get("task_id"), mv.get("section_id")
    if not (iid and gid): continue
    body = json.dumps({"query":f"mutation {{ move_item_to_group(item_id:{iid}, group_id:\"{gid}\") {{ id }} }}"})
    r = subprocess.run(["curl","-sS","-X","POST",base,
        "-H",f"Authorization: {token}","-H","Content-Type: application/json",
        "-d",body,"-w","\n%{http_code}"], capture_output=True, text=True)
    results.append({"moved_item": iid, "to_group": gid, "status": r.stdout.rsplit('\n',1)[-1]})

print(json.dumps({"tool":"monday","project_id":pid,"results":results}, indent=2))
PY
}

# ============================================================================
# TRELLO — public API
# ============================================================================
# "Project" = Board. "Sections" = Lists. "Tasks" = Cards.

connect_trello_fetch_project() {
  local url_or_id="$1"
  _con_require_env trello || return 1
  local board_id; board_id=$(_con_extract_project_id trello "$url_or_id")
  [[ -n "$board_id" ]] || { echo '{"error":"could not extract Trello board id"}' >&2; return 1; }

  local board lists cards
  board=$(trello_get "/boards/$board_id" --data-urlencode "fields=name,desc") || true
  lists=$(trello_get "/boards/$board_id/lists" --data-urlencode "fields=name") || true
  cards=$(trello_get "/boards/$board_id/cards" --data-urlencode "fields=name,desc,idList,dueComplete,due,idMembers" \
    --data-urlencode "limit=200") || true

  python3 - "$board_id" "$board" "$lists" "$cards" <<'PY'
import json, sys
bid, b_s, l_s, c_s = sys.argv[1:5]
def safe(j):
    try: return json.loads(j or '{}')
    except Exception: return {}
b  = safe(b_s)
ls = safe(l_s)
cs = safe(c_s)

sections = [{"id": x.get('id',''), "name": x.get('name','')} for x in ls]
tasks = []
for c in cs:
    members = c.get('idMembers') or []
    due = c.get('due') or ''
    tasks.append({
        "id": c.get('id',''),
        "name": c.get('name',''),
        "notes": c.get('desc','') or '',
        "section_id": c.get('idList',''),
        "assignee": ','.join(members),
        "due_date": due[:10] if due else '',
        "completed": bool(c.get('dueComplete', False)),
    })
print(json.dumps({
    "tool": "trello",
    "project_id": bid,
    "project_name": b.get('name',''),
    "project_notes": b.get('desc','') or '',
    "sections": sections,
    "tasks": tasks,
}, indent=2))
PY
}

connect_trello_apply_changes() {
  local project_id="$1" changes_json="$2"
  _con_require_env trello || return 1
  python3 - "$project_id" "$changes_json" <<'PY'
import json, sys, subprocess, os
pid, raw = sys.argv[1:3]
changes = json.loads(raw)
key, token = os.environ.get('TRELLO_API_KEY',''), os.environ.get('TRELLO_API_TOKEN','')
base = 'https://api.trello.com/1'
results = []

for ch in changes.get("rewrites", []):
    cid = ch.get("task_id"); name = ch.get("name"); notes = ch.get("notes")
    if not cid: continue
    body = json.dumps({k: v for k, v in (("name", name), ("desc", notes)) if v is not None})
    r = subprocess.run(["curl","-sS","-X","PUT", f"{base}/cards/{cid}",
        "--data-urlencode", f"key={key}", "--data-urlencode", f"token={token}",
        "-H","Content-Type: application/json", "-d", body, "-w","\n%{http_code}"],
        capture_output=True, text=True)
    results.append({"card_id": cid, "status": r.stdout.rsplit('\n',1)[-1]})

for sec in changes.get("create_sections", []):
    name = sec.get("name"); if not name: continue
    body = json.dumps({"name": name, "idBoard": pid})
    r = subprocess.run(["curl","-sS","-X","POST", f"{base}/lists",
        "--data-urlencode", f"key={key}", "--data-urlencode", f"token={token}",
        "-H","Content-Type: application/json", "-d", body, "-w","\n%{http_code}"],
        capture_output=True, text=True)
    results.append({"created_list": name, "status": r.stdout.rsplit('\n',1)[-1]})

for mv in changes.get("moves", []):
    cid, lid = mv.get("task_id"), mv.get("section_id")
    if not (cid and lid): continue
    body = json.dumps({"idList": lid})
    r = subprocess.run(["curl","-sS","-X","PUT", f"{base}/cards/{cid}",
        "--data-urlencode", f"key={key}", "--data-urlencode", f"token={token}",
        "-H","Content-Type: application/json", "-d", body, "-w","\n%{http_code}"],
        capture_output=True, text=True)
    results.append({"moved_card": cid, "to_list": lid, "status": r.stdout.rsplit('\n',1)[-1]})

print(json.dumps({"tool":"trello","project_id":pid,"results":results}, indent=2))
PY
}

# ============================================================================
# NOTION — public API
# ============================================================================
# Notion doesn't have first-class "projects" — we treat a database page as the
# project. Sections = select/multi_select option groups (status). Tasks = pages.

connect_notion_fetch_project() {
  local url_or_id="$1"
  _con_require_env notion || return 1
  local db_id; db_id=$(_con_extract_project_id notion "$url_or_id")
  [[ -n "$db_id" ]] || { echo '{"error":"could not extract Notion database id"}' >&2; return 1; }

  local db pages
  db=$(notion_get "/databases/$db_id") || true
  pages=$(notion_post "/databases/$db_id/query" '{"page_size":200}') || true

  python3 - "$db_id" "$db" "$pages" <<'PY'
import json, sys
db_id, db_s, pg_s = sys.argv[1:4]
def safe(j):
    try: return json.loads(j or '{}')
    except Exception: return {}
db  = safe(db_s)
pgs = safe(pg_s).get('results', [])

# Build sections from a "Status" property if it exists, else single "Tasks" section.
props = db.get('properties') or {}
sections = [{"id":"unsectioned","name":"Tasks"}]
status_prop = None
for pn, pv in props.items():
    if pv.get('type') == 'select' and pv.get('select',{}).get('name','').lower() in ('status','stage','state'):
        status_prop = pn
        options = pv.get('select',{}).get('options') or []
        sections = [{"id": o.get('id') or o.get('name',''), "name": o.get('name','')} for o in options]
        break

def text(rt):
    if not rt: return ''
    if isinstance(rt, list):
        return ''.join((seg.get('plain_text') if isinstance(seg, dict) else '') for seg in rt)
    return str(rt)

tasks = []
for p in pgs:
    title = ''
    notes = ''
    sec_id = ''
    assignee = ''
    due = ''
    for pn, pv in (p.get('properties') or {}).items():
        ptype = pv.get('type')
        if ptype == 'title':
            title = text(pv.get('title', []))
        elif pn.lower() in ('notes','description','body','content'):
            notes = text(pv.get('rich_text', []))
        elif ptype == 'select' and pn == status_prop:
            sel = pv.get('select') or {}
            sec_id = sel.get('id') or sel.get('name','')
        elif pn.lower() == 'assignee':
            ppl = pv.get('people') or []
            if ppl: assignee = ','.join((x.get('name') or x.get('id','')) for x in ppl)
        elif pn.lower() in ('due','due date','duedate'):
            d = pv.get('date') or {}
            due = (d.get('start') or '')[:10]
    tasks.append({
        "id": p.get('id',''),
        "name": title,
        "notes": notes,
        "section_id": sec_id,
        "assignee": assignee,
        "due_date": due,
        "completed": False,
    })

print(json.dumps({
    "tool": "notion",
    "project_id": db_id,
    "project_name": db.get('title', [{}])[0].get('plain_text','') if db.get('title') else '',
    "project_notes": '',
    "sections": sections,
    "tasks": tasks,
}, indent=2))
PY
}

connect_notion_apply_changes() {
  local project_id="$1" changes_json="$2"
  _con_require_env notion || return 1
  python3 - "$project_id" "$changes_json" <<'PY'
import json, sys, subprocess, os
pid, raw = sys.argv[1:3]
changes = json.loads(raw)
key = os.environ.get('NOTION_API_KEY','')
base = 'https://api.notion.com/v1'
headers = ['-H', f'Authorization: Bearer {key}',
           '-H', 'Notion-Version: 2022-06-28',
           '-H', 'Content-Type: application/json']
results = []

for ch in changes.get("rewrites", []):
    pgid = ch.get("task_id"); name = ch.get("name"); notes = ch.get("notes")
    if not pgid: continue
    props = {}
    if name is not None:
        props["Name"] = {"title": [{"type":"text","text":{"content":name[:2000]}}]}
    if notes is not None:
        props["Notes"] = {"rich_text": [{"type":"text","text":{"content":notes[:2000]}}]}
    if not props: continue
    body = json.dumps({"properties": props})
    r = subprocess.run(["curl","-sS","-X","POST", f"{base}/pages/{pgid}",
        *headers, "-d", body, "-w","\n%{http_code}"], capture_output=True, text=True)
    results.append({"page_id": pgid, "status": r.stdout.rsplit('\n',1)[-1]})

for mv in changes.get("moves", []):
    pgid = mv.get("task_id"); sec = mv.get("section_id") or mv.get("status_name")
    if not (pgid and sec): continue
    body = json.dumps({"properties": {"Status": {"select": {"name": sec}}}})
    r = subprocess.run(["curl","-sS","-X","POST", f"{base}/pages/{pgid}",
        *headers, "-d", body, "-w","\n%{http_code}"], capture_output=True, text=True)
    results.append({"moved_page": pgid, "to_status": sec, "status": r.stdout.rsplit('\n',1)[-1]})

print(json.dumps({"tool":"notion","project_id":pid,"results":results}, indent=2))
PY
}

# ============================================================================
# JIRA — public API
# ============================================================================
# "Project" = Jira Project (e.g. ENG). "Tasks" = Issues. Sections are unlabeled;
# we synthesize a "Status" section per unique status. Move = transition issue.

connect_jira_fetch_project() {
  local url_or_id="$1"
  _con_require_env jira || return 1
  local project_key; project_key=$(_con_extract_project_id jira "$url_or_id")
  [[ -n "$project_key" ]] || { echo '{"error":"could not extract Jira project key"}' >&2; return 1; }

  local meta issues
  meta=$(jira_get "/project/$project_key") || true
  issues=$(jira_post "/search" "{\"jql\":\"project = $project_key ORDER BY created DESC\",\"maxResults\":200,\"fields\":[\"summary\",\"description\",\"status\",\"assignee\",\"duedate\"]}") || true

  python3 - "$project_key" "$meta" "$issues" <<'PY'
import json, sys
key, m_s, i_s = sys.argv[1:4]
def safe(j):
    try: return json.loads(j or '{}')
    except Exception: return {}
m = safe(m_s)
iss = safe(i_s).get('issues', [])

statuses = {}
tasks = []
for it in iss:
    f = it.get('fields', {})
    st = f.get('status', {})
    sid = st.get('id','')
    sname = st.get('name','')
    statuses[sid] = sname
    desc = f.get('description')
    if isinstance(desc, dict):  # ADF
        desc = json.dumps(desc)
    tasks.append({
        "id": it.get('key','') or it.get('id',''),
        "name": f.get('summary',''),
        "notes": desc or '',
        "section_id": sid,
        "assignee": (f.get('assignee') or {}).get('displayName','') if f.get('assignee') else '',
        "due_date": f.get('duedate','') or '',
        "completed": (st.get('statusCategory',{}).get('key','') == 'done'),
    })
sections = [{"id": sid, "name": sname} for sid, sname in sorted(statuses.items(), key=lambda x: x[1])]
print(json.dumps({
    "tool": "jira",
    "project_id": key,
    "project_name": m.get('name', key),
    "project_notes": m.get('description','') or '',
    "sections": sections,
    "tasks": tasks,
}, indent=2))
PY
}

connect_jira_apply_changes() {
  local project_id="$1" changes_json="$2"
  _con_require_env jira || return 1
  python3 - "$project_id" "$changes_json" <<'PY'
import json, sys, subprocess, os, base64
pid, raw = sys.argv[1:3]
changes = json.loads(raw)
email = os.environ.get('JIRA_EMAIL','')
token = os.environ.get('JIRA_API_TOKEN','')
basic = base64.b64encode(f"{email}:{token}".encode()).decode()
base  = os.environ.get('JIRA_BASE_URL','') + '/rest/api/3'
headers = ['-H', f'Authorization: Basic {basic}', '-H', 'Content-Type: application/json']
results = []

for ch in changes.get("rewrites", []):
    iid = ch.get("task_id"); name = ch.get("name"); notes = ch.get("notes")
    if not iid: continue
    fields = {}
    if name is not None: fields["summary"] = name
    if notes is not None:
        fields["description"] = {"type":"doc","version":1,"content":[{"type":"paragraph","content":[{"type":"text","text":notes[:32000]}]}]}
    if not fields: continue
    body = json.dumps({"fields": fields})
    r = subprocess.run(["curl","-sS","-X","PUT", f"{base}/issue/{iid}",
        *headers, "-d", body, "-w","\n%{http_code}"], capture_output=True, text=True)
    results.append({"issue_id": iid, "status": r.stdout.rsplit('\n',1)[-1]})

for mv in changes.get("moves", []):
    iid = mv.get("task_id"); target = mv.get("section_id") or mv.get("status_name")
    if not (iid and target): continue
    # Find transition id by name
    tr_body = json.dumps({"transition": {"name": target}}) if not str(target).isdigit() else json.dumps({"transition": {"id": target}})
    r = subprocess.run(["curl","-sS","-X","POST", f"{base}/issue/{iid}/transitions",
        *headers, "-d", tr_body, "-w","\n%{http_code}"], capture_output=True, text=True)
    results.append({"moved_issue": iid, "to_status": target, "status": r.stdout.rsplit('\n',1)[-1]})

print(json.dumps({"tool":"jira","project_id":pid,"results":results}, indent=2))
PY
}

# ============================================================================
# Generic dispatch — used by the MCP server so it can call any tool by name
# ============================================================================

# connect_<tool>_fetch_project  → dispatched by tool name
connect_dispatch_fetch() {
  local tool="$1" url_or_id="$2"
  case "$tool" in
    asana)   connect_asana_fetch_project   "$url_or_id" ;;
    clickup) connect_clickup_fetch_project "$url_or_id" ;;
    monday)  connect_monday_fetch_project  "$url_or_id" ;;
    trello)  connect_trello_fetch_project  "$url_or_id" ;;
    notion)  connect_notion_fetch_project  "$url_or_id" ;;
    jira)    connect_jira_fetch_project    "$url_or_id" ;;
    *) echo '{"error":"unsupported tool: '"$tool"'"}' >&2; return 1 ;;
  esac
}

connect_dispatch_apply() {
  local tool="$1" project_id="$2" changes_json="$3"
  case "$tool" in
    asana)   connect_asana_apply_changes   "$project_id" "$changes_json" ;;
    clickup) connect_clickup_apply_changes "$project_id" "$changes_json" ;;
    monday)  connect_monday_apply_changes  "$project_id" "$changes_json" ;;
    trello)  connect_trello_apply_changes  "$project_id" "$changes_json" ;;
    notion)  connect_notion_apply_changes  "$project_id" "$changes_json" ;;
    jira)    connect_jira_apply_changes    "$project_id" "$changes_json" ;;
    *) echo '{"error":"unsupported tool: '"$tool"'"}' >&2; return 1 ;;
  esac
}

# connect_supported_tools — list of tools whose env vars are currently set
connect_supported_tools() {
  local out=()
  [[ -n "${ASANA_PAT:-}" ]]         && out+=(asana)
  [[ -n "${CLICKUP_API_TOKEN:-}" ]] && out+=(clickup)
  [[ -n "${MONDAY_API_TOKEN:-}" ]]  && out+=(monday)
  [[ -n "${TRELLO_API_KEY:-}" && -n "${TRELLO_API_TOKEN:-}" ]] && out+=(trello)
  [[ -n "${NOTION_API_KEY:-}" ]]    && out+=(notion)
  [[ -n "${JIRA_BASE_URL:-}" && -n "${JIRA_EMAIL:-}" && -n "${JIRA_API_TOKEN:-}" ]] && out+=(jira)
  if [[ ${#out[@]} -eq 0 ]]; then
    echo "(none configured)"
  else
    printf '%s\n' "${out[@]}"
  fi
}

echo "connectors.sh loaded. Supported tools: $(connect_supported_tools | tr '\n' ' ')"