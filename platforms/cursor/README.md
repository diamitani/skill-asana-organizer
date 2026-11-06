# Cursor + VS Code Continue — local install (no submission)

## Cursor
Add the MCP server in Settings -> MCP, or `.cursor/mcp.json`:

```json
{
  "mcpServers": {
    "asana-organizer": {
      "command": "python3",
      "args": ["/ABSOLUTE/PATH/skill-asana-organizer/mcp/server.py"],
      "env": {
        "ASANA_PAT": "your-token-here"
      }
    }
  }
}
```

The repo also works as context: clone it and Cursor reads SKILL.md as project
instructions.

Marketplace listing: the xAI form (platforms/grok/SUBMISSION.md, Route A)
distributes to Cursor users from the same submission.

## VS Code Continue
Same server block in `~/.continue/config.json` under `mcpServers`.
Full wire-up examples: `mcp/README.md` in this repo.
