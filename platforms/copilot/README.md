# Microsoft Copilot — status and path

No direct SKILL.md import. Options:

1. **Copilot Studio declarative agent** — wrap the organizer workflow as
   instructions + the MCP server as an action. Build in Copilot Studio,
   publish to the org catalog; store listing goes through Microsoft Partner
   Center (requires a verified publisher account).
2. **GitHub Copilot (VS Code)** — repo works as-is via the MCP server block in
   VS Code settings (`mcp` section) plus SKILL.md as `.github/copilot-instructions.md`
   style context.

No public "skill marketplace" exists for consumer Copilot. Recommended: skip a
dedicated build until the MCP server is packaged (mcp-registry/), then register
it as a Copilot Studio action.
