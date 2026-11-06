# All-Platform Packaging — asana-organizer

One skill (`SKILL.md` + `scripts/` + `mcp/server.py`), packaged for every major
agent platform. Nothing here has been submitted anywhere yet — each folder has
the manifest and the exact submission steps. Status tracking lives in the
companion Google Sheet (see CHECKLIST.md).

| Platform | Package | Submission route |
|---|---|---|
| Claude Code / Claude Desktop (local) | This repo as-is | None — git clone |
| Anthropic Claude Directory | `claude/` (`.claude-plugin/plugin.json`) | claude.ai/directory/manage |
| ChatGPT / Codex (OpenAI plugin directory) | `openai/` (`plugin.json` + skills/) | platform.openai.com plugins (ZIP upload) |
| Grok Bot Marketplace (+ Cursor listing) | `grok/` (`.grok-plugin/plugin.json`) | x.ai/bot/marketplace/submit-a-plugin or PR to xai-org/plugin-marketplace |
| Official MCP Registry | `mcp-registry/` (`server.json`) | `mcp-publisher` CLI |
| Gemini skills | Manual instructions | Inside Gemini app (no marketplace) |
| Cursor / VS Code Continue (local) | `cursor/` config snippet | None — paste config |
| Microsoft Copilot | Manual instructions | Copilot Studio / Partner Center |

Two distribution shapes cover everything:
1. **The skill** — SKILL.md instructions + bash/python helpers. Runs where an
   agent can execute shell (Claude Code, Codex, Cursor, Continue). Chat-only
   surfaces (Gemini, Copilot) get the workflow instructions without script
   execution.
2. **The MCP server** — `mcp/server.py` stdio server. Any MCP client
   (Claude Desktop, Cursor, VS Code, Grok) can call `fetch_project`,
   `apply_rewrites`, `create_sections`, `move_tasks` directly.
