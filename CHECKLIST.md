# Asana Organizer — All-Platform Launch Checklist

Skill: `diamitani/skill-asana-organizer` · Landing page: https://diamitani.github.io/asana-organizer-site/
Status: NOTHING submitted or published anywhere yet. Every submission needs Patrick's explicit go.

## Phase 0 — Done in this PR
- [x] SKILL.md frontmatter fixed to Agent Skills spec (name, description <=1024 chars, license, compatibility, metadata; allowed-tools no longer swallowed into description)
- [x] MIT LICENSE added (site claimed MIT; repo had no license file)
- [x] Platform manifests written: `.claude-plugin/plugin.json`, OpenAI `plugin.json`, `.grok-plugin/plugin.json`, MCP `server.json` (draft)
- [x] Per-platform submission guides under `platforms/`
- [x] Platform tracker spreadsheet (Google Sheet, in Drive "Artispreneur - Instinct outputs")
- [x] This checklist as a phone-readable PDF (same Drive folder)

## Phase 1 — Live now, zero submission (Patrick can use today)
- [ ] Claude Code: `git clone` into `~/.claude/skills/` — works now
- [ ] Cursor / VS Code Continue: paste the MCP config from `platforms/cursor/README.md`
- [ ] Gemini: paste workflow into a Gemini skill (instructions-only, no script execution)

## Phase 2 — Ready to submit, needs Patrick's go per platform
- [ ] Anthropic Claude Directory — claude.ai/directory/manage (connect GitHub, submit repo, review) — `platforms/claude/SUBMISSION.md`
- [ ] OpenAI ChatGPT plugin directory — ZIP upload at platform.openai.com (needs: verified identity, privacy policy URL, terms URL, icons, 5 positive + 3 negative test cases; decide skills-only vs app+skills BEFORE first upload) — `platforms/openai/SUBMISSION.md`
- [ ] Grok Bot Marketplace (+ Cursor) — x.ai/bot/marketplace/submit-a-plugin (needs: org handle, square logo with background, test instructions; listings must be free) or PR to xai-org/plugin-marketplace — `platforms/grok/SUBMISSION.md`

## Phase 3 — Needs build work first
- [ ] Official MCP Registry — package `mcp/server.py` to PyPI, then `mcp-publisher login github && mcp-publisher publish` (registry is in preview) — `platforms/mcp-registry/PUBLISH.md`
- [ ] Microsoft Copilot — wait for MCP packaging, then register as a Copilot Studio action (Partner Center for store listing)

## Decisions for Patrick
1. Go / no-go per Phase 2 platform (I do the submission, you approve each one)
2. Skills-only vs app+skills for ChatGPT (affects whether a hosted MCP server gets built first)
3. PyPI account for MCP Registry packaging
4. Privacy policy + terms pages (needed for OpenAI; GitHub Pages site has neither — I can draft both)
