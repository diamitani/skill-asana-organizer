# Official MCP Registry — publish steps

Route: official `mcp-publisher` CLI against https://registry.modelcontextprotocol.io
(registry is in PREVIEW — breaking changes/resets possible).

Docs: https://modelcontextprotocol.io/registry/quickstart and
https://modelcontextprotocol.io/registry/authentication

## Prep
- [ ] Package `mcp/server.py` for PyPI (registry hosts metadata only, not
      artifacts). Single-file server; a minimal pyproject.toml is enough.
- [ ] Publish the package to PyPI (needs a PyPI account — Patrick's call).
- [ ] Update server.json `packages` with the real PyPI identifier, then remove
      the `_comment` field.
- [ ] Name stays `io.github.diamitani/asana-organizer` under GitHub auth.

## Publish
- [ ] `npm install -g @modelcontextprotocol/mcp-publisher` (or per quickstart).
- [ ] `mcp-publisher login github` (device-flow OAuth with the diamitani account).
- [ ] `mcp-publisher publish` from the directory containing server.json.
- [ ] Verify the listing resolves in the registry API.

Alternative discovery (no submission needed): the MCP server already works
locally in Claude Desktop / Cursor / VS Code — see platforms/cursor/README.md.
