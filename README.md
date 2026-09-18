# Asana Project Organizer

![Category](https://img.shields.io/badge/category-Project%20Management-blue) ![Status](https://img.shields.io/badge/status-active-green) ![Multi--Tool](https://img.shields.io/badge/multi--tool-Asana%20%7C%20ClickUp%20%7C%20Monday%20%7C%20Trello%20%7C%20Notion%20%7C%20Jira-purple)

Tired of project boards that are impossible to read at a glance? This skill takes any project (Asana, ClickUp, Monday, Trello, Notion, or Jira), rewrites task names so they actually make sense to stakeholders, proposes a logical section structure, and pushes all the changes back automatically.

## What It Does

- Fetches all tasks from any project via URL
- Rewrites task names and descriptions for clear stakeholder communication
- Proposes an organized section structure (by status, team, priority, or custom)
- Applies all changes back to the source tool — no copy-paste needed
- Preserves due dates, assignees, and custom fields
- **Multi-tool**: works with Asana, ClickUp, Monday.com, Trello, Notion, and Jira
- **MCP server**: drop-in Model Context Protocol server for Any AI Agent / Desktop Assistant, Cursor, VS Code

## Quick Start

In Claude Code, say:
> "Organize my Asana project at [URL] for a leadership review"
> "Clean up my ClickUp board and group tasks by team"
> "Rewrite my Monday project for executive review"

Or use the MCP server — see [mcp/README.md](mcp/README.md) for setup.

## How to Use

### Option 1 — As a Skill (Claude Code)
Just describe what you want in plain language. The skill auto-detects your tool from the URL.

### Option 2 — As a Bash Script
```bash
export ASANA_PAT='2/your-token-here'
source ./scripts/asana-api.sh
./scripts/connectors.sh  # multi-tool support
asana_ping  # verify auth
```

### Option 3 — As an MCP Server
```bash
export ASANA_PAT='...'
python3 ./mcp/server.py
```
Add to your `claude_desktop_config.json`:
```json
{
  "mcpServers": {
    "asana-organizer": {
      "command": "python3",
      "args": ["/path/to/skill-asana-organizer/mcp/server.py"],
      "env": {"ASANA_PAT": "your-token-here"}
    }
  }
}
```

## Supported Tools

| Tool | Env Vars | Auto-Detect |
|------|----------|-------------|
| Asana | `ASANA_PAT` | `app.asana.com` |
| ClickUp | `CLICKUP_API_TOKEN` | `app.clickup.com` |
| Monday | `MONDAY_API_TOKEN` | `monday.com` |
| Trello | `TRELLO_API_KEY`, `TRELLO_API_TOKEN` | `trello.com` |
| Notion | `NOTION_API_KEY` | `notion.so` |
| Jira | `JIRA_BASE_URL`, `JIRA_EMAIL`, `JIRA_API_TOKEN` | `atlassian.net` |

Get Asana PAT: https://app.asana.com/0/my-apps

## Trigger Phrases

- "organize my [Asana/ClickUp/Monday/Trello/Notion/Jira]"
- "clean up this project"
- "rewrite tasks for leadership"
- "sort through my tasks"
- "group by status/team/priority"
- "format for [audience]"

## Category

Project Management

## Author

Patrick Diamitani · [GitHub](https://github.com/diamitani)

---

> Open source · MIT · Works with your existing project management tools
