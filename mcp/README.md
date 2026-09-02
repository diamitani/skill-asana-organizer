# Asana Organizer — MCP Server

A minimal Model Context Protocol (MCP) server that exposes the asana-organizer skill as standard MCP tools. Works with Claude Desktop, Cursor, VS Code (with Continue), and any other MCP-compatible client.

## What you get

Five MCP tools that wrap the multi-tool connector layer:

| Tool | Purpose |
|------|---------|
| `fetch_project(tool, project_url_or_id)` | Fetch a project from Asana/ClickUp/Monday/Trello/Notion/Jira, return normalized JSON |
| `apply_rewrites(tool, project_id, rewrites[])` | Apply task name + description rewrites |
| `create_sections(tool, project_id, sections[])` | Create new sections, return their IDs |
| `move_tasks(tool, moves[])` | Move tasks to new sections |
| `get_health()` | Server health + supported tools list |

## Install

```bash
# 1. Set your API token (Asana example)
export ASANA_PAT='2/your-token-here'

# 2. Verify
bash ../scripts/setup.sh

# 3. Test the MCP server boots
python3 server.py < /dev/null
# Expected: "[asana-organizer v1.0.0] MCP server started"
```

## Claude Desktop

Edit `~/Library/Application Support/Claude/claude_desktop_config.json` (macOS) or `%APPDATA%\Claude\claude_desktop_config.json` (Windows):

```json
{
  "mcpServers": {
    "asana-organizer": {
      "command": "python3",
      "args": ["/absolute/path/to/skill-asana-organizer/mcp/server.py"],
      "env": {
        "ASANA_PAT": "2/your-token-here"
      }
    }
  }
}
```

Restart Claude Desktop. You should see "asana-organizer" listed in the MCP servers panel.

## Cursor

Edit `~/.cursor/mcp.json`:

```json
{
  "mcpServers": {
    "asana-organizer": {
      "command": "python3",
      "args": ["/absolute/path/to/skill-asana-organizer/mcp/server.py"],
      "env": {
        "ASANA_PAT": "2/your-token-here"
      }
    }
  }
}
```

## VS Code (Continue extension)

Edit `~/.continue/config.json`:

```json
{
  "experimental": {
    "modelContextProtocolServers": [
      {
        "name": "asana-organizer",
        "transport": {
          "type": "stdio",
          "command": "python3",
          "args": ["/absolute/path/to/skill-asana-organizer/mcp/server.py"],
          "env": {
            "ASANA_PAT": "2/your-token-here"
          }
        }
      }
    ]
  }
}
```

## Multi-Tool Configuration

The server respects whichever tokens you set. Add any combination to the `env` block:

```json
"env": {
  "ASANA_PAT": "...",
  "CLICKUP_API_TOKEN": "...",
  "MONDAY_API_TOKEN": "...",
  "TRELLO_API_KEY": "...",
  "TRELLO_API_TOKEN": "...",
  "NOTION_API_KEY": "secret_...",
  "JIRA_BASE_URL": "https://yourcompany.atlassian.net",
  "JIRA_EMAIL": "you@yourcompany.com",
  "JIRA_API_TOKEN": "..."
}
```

If a tool's env vars aren't set, that tool's MCP calls will return a friendly "missing env" error — other tools continue to work.

## Example Conversation

In Claude Desktop with the MCP server connected:

> **You:** Organize my Asana project at https://app.asana.com/0/1234567890/list for a leadership review
>
> **Claude (via fetch_project):** I found 47 open tasks across 6 sections. Here's the project structure...
>
> **Claude (via apply_rewrites):** I rewrote all 47 tasks for an exec audience. Want me to preview the first 10?
>
> **You:** Yes
>
> **Claude (via create_sections):** Created 5 new sections: 🔴 Blocked, 🟡 In Progress, 🟢 Up Next, ⬜ Backlog, ✅ Complete
>
> **Claude (via move_tasks):** Moved all 47 tasks to their new sections. Project is now organized for your leadership review.

## Architecture

```
MCP Client (Claude Desktop / Cursor / VS Code)
    │
    │  JSON-RPC over stdio
    ▼
mcp/server.py  ← This file (~330 lines, stdlib only)
    │
    │  subprocess: bash -c "source connectors.sh && connect_<tool>_<action>"
    ▼
scripts/connectors.sh  ← Multi-tool bash helpers
    │
    ├─ Asana    (REST v1.0)
    ├─ ClickUp  (API v2)
    ├─ Monday   (GraphQL v2)
    ├─ Trello   (REST)
    ├─ Notion   (REST v1)
    └─ Jira     (Cloud REST v3)
```

The MCP server is a thin protocol shim — all real work happens in `connectors.sh`, which returns normalized JSON. This means the same logic is reusable from bash, Python, or any MCP client.

## Protocol Notes

- Implements MCP `2024-11-05` spec
- Methods: `initialize`, `tools/list`, `tools/call`, `ping`
- No external dependencies — pure Python 3.8+ stdlib
- Handles malformed JSON-RPC gracefully (returns parse error)
- All tool errors returned as `{ok: false, error: "..."}` with `isError: true` so clients can show them

## Troubleshooting

**"connectors.sh not found"** — The server expects `../scripts/connectors.sh` relative to `mcp/server.py`. Make sure you cloned the full repo.

**"MCP server started" but no tools appear** — Restart your MCP client. Config changes require a restart.

**Tool returns `{ok: false, error: "401"}`** — Your API token is invalid or missing. Check the `env` block in your config.

**Need a new tool added?** — Edit `connectors.sh` to add the tool, then add its schema to `TOOL_SCHEMAS` and a handler to `TOOL_HANDLERS` in `server.py`. The normalized interface is the same for all tools.
