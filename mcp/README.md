# MCP Server — asana-organizer

A minimal Model Context Protocol (MCP) server exposing a **normalized**,
**multi-tool** interface for project organization. Works with any
MCP-compatible client (Claude Desktop, Cursor, VS Code Continue, etc.).

## Tools exposed

| Tool             | What it does                                                   |
|------------------|----------------------------------------------------------------|
| `fetch_project`  | Fetch a project (sections + tasks) in a normalized JSON shape. |
| `apply_rewrites` | Apply task name/note rewrites to one or more tasks.             |
| `create_sections`| Create new sections / lists / groups in a project.             |
| `move_tasks`     | Move tasks between sections / statuses.                        |
| `get_health`     | Server health and which providers have credentials configured. |

All tools accept a `tool` parameter (`asana | clickup | monday | trello | notion | jira`)
so a single client can talk to any supported provider.

## Normalized project shape

```json
{
  "tool": "asana",
  "project_id": "1234567890",
  "project_name": "Q4 Launch",
  "sections": [{"id": "111", "name": "In Progress"}],
  "tasks": [
    {
      "id": "999",
      "name": "Deploy backend services",
      "notes": "Migrate API services to prod...",
      "section_id": "111",
      "assignee": "Jane Doe",
      "due_date": "2026-04-30",
      "completed": false
    }
  ]
}
```

---

## Prerequisites

1. Python 3.11+ on `PATH` (the server uses the official `mcp` SDK when
   available; falls back to a manual JSON-RPC loop on Python 3.9+).
2. `bash` and `curl` on `PATH`.
3. The connector layer at `./scripts/connectors.sh` (re-sources `./scripts/asana-api.sh`).
4. Environment variables for the providers you want to use (see below).

```bash
# Required env vars by provider
export ASANA_PAT='2/your-token'                   # Asana
export CLICKUP_API_TOKEN='pk_...'                 # ClickUp
export MONDAY_API_TOKEN='...'                     # Monday.com
export TRELLO_API_KEY='...'                       # Trello (also needs TRELLO_API_TOKEN)
export TRELLO_API_TOKEN='...'
export NOTION_API_KEY='secret_...'                # Notion
export JIRA_BASE_URL='https://yourco.atlassian.net'  # Jira
export JIRA_EMAIL='you@yourco.com'
export JIRA_API_TOKEN='...'                       # https://id.atlassian.com/manage-profile/security/api-tokens
```

Verify everything:

```bash
bash scripts/setup.sh --check
```

---

## Wire-up: Claude Desktop

Edit `~/Library/Application Support/Claude/claude_desktop_config.json`
(macOS) or `%APPDATA%\Claude\claude_desktop_config.json` (Windows) or
`~/.config/Claude/claude_desktop_config.json` (Linux):

```json
{
  "mcpServers": {
    "asana-organizer": {
      "command": "python3",
      "args": ["/ABSOLUTE/PATH/TO/repos/skill-asana-organizer/mcp/server.py"],
      "env": {
        "ASANA_PAT":         "2/your-asana-pat",
        "CLICKUP_API_TOKEN": "pk_your-clickup-token",
        "MONDAY_API_TOKEN":  "your-monday-token",
        "TRELLO_API_KEY":    "your-trello-key",
        "TRELLO_API_TOKEN":  "your-trello-token",
        "NOTION_API_KEY":    "secret_your-notion-key",
        "JIRA_BASE_URL":     "https://yourco.atlassian.net",
        "JIRA_EMAIL":        "you@yourco.com",
        "JIRA_API_TOKEN":    "your-jira-api-token"
      }
    }
  }
}
```

Restart Claude Desktop. You should see "asana-organizer" listed in the
MCP servers panel with 5 tools.

---

## Wire-up: Cursor

Edit `~/.cursor/mcp.json`:

```json
{
  "mcpServers": {
    "asana-organizer": {
      "command": "python3",
      "args": ["/ABSOLUTE/PATH/TO/repos/skill-asana-organizer/mcp/server.py"],
      "env": {
        "ASANA_PAT": "2/your-asana-pat"
      }
    }
  }
}
```

Add any provider env vars you want — only the ones you include will be
available. Restart Cursor after editing.

---

## Wire-up: VS Code Continue

Edit `~/.continue/config.json` (Continue >= 0.9 uses `mcpServers` at the
top level):

```json
{
  "mcpServers": {
    "asana-organizer": {
      "command": "python3",
      "args": ["/ABSOLUTE/PATH/TO/repos/skill-asana-organizer/mcp/server.py"],
      "env": {
        "ASANA_PAT": "2/your-asana-pat"
      }
    }
  }
}
```

Reload the VS Code window after editing.

---

## Smoke-test from the command line

```bash
echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"t","version":"0"}}}' \
  | python3 mcp/server.py
```

You should get back:

```json
{"jsonrpc":"2.0","id":1,"result":{"protocolVersion":"2024-11-05","serverInfo":{"name":"asana-organizer","version":"0.1.0"},"capabilities":{"tools":{}}}}
```

Then list tools:

```bash
echo '{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}' \
  | python3 mcp/server.py
```

---

## Architecture

```
┌──────────────────────┐
│  MCP client          │   Claude Desktop / Cursor / VS Code Continue / …
│  (JSON-RPC over stdio)│
└──────────┬───────────┘
           │  initialize / tools/list / tools/call
           ▼
┌──────────────────────┐
│  mcp/server.py       │   This server (FastMCP or manual JSON-RPC fallback)
│  Python 3.11+        │
└──────────┬───────────┘
           │  subprocess.run(["bash", "-c", "source connectors.sh && fn …"])
           ▼
┌──────────────────────┐
│  scripts/connectors.sh│  Unified connector layer (50 functions)
│   ├─ Asana (re-sourced from asana-api.sh)
│   ├─ ClickUp
│   ├─ Monday.com
│   ├─ Trello
│   ├─ Notion
│   └─ Jira
└──────────────────────┘
```

The Python layer is intentionally thin — it parses arguments, calls a
bash function, and returns the JSON. All provider-specific knowledge
lives in `connectors.sh` so it's easy to extend or test in isolation.

---

## Troubleshooting

| Symptom                                            | Fix                                                                                  |
|----------------------------------------------------|--------------------------------------------------------------------------------------|
| "missing ASANA_PAT"                                | Export the PAT (see env-var table above)                                             |
| `python3 server.py` exits immediately              | Check stderr — usually a path/permission issue or a missing dep                      |
| All auth probes return 401/403                     | Expected with dummy tokens; real tokens should return 200                            |
| Server starts but tools/list returns empty         | You're on Python < 3.11 with the FastMCP path broken — should auto-fall-back to manual loop. If not, check stderr. |
| Cursor / Claude Desktop doesn't see the server     | Restart the client after editing the config. Verify the absolute path is correct.    |

---

## Files

- `server.py` — the MCP server (entry point)
- `../scripts/connectors.sh` — connector layer (sourced by server.py)
- `../scripts/asana-api.sh` — Asana helpers (sourced by connectors.sh)
- `../scripts/setup.sh` — one-command verification (`bash scripts/setup.sh --check`)