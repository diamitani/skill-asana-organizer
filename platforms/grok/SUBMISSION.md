# Grok Bot Marketplace (+ Cursor users) — submission steps

Two routes, pick one:

## Route A — xAI web form (also lists to Cursor users)
Form: https://x.ai/bot/marketplace/submit-a-plugin
- [ ] First name, last name, work email.
- [ ] Organization name + unique handle (no spaces/capitals), e.g. `diamitani`.
- [ ] Website URL: https://diamitani.github.io/asana-organizer-site/
- [ ] Logotype URL: square (1:1) SVG or PNG with a solid background plate.
- [ ] Where to list: Grok Bot, Cursor, or both.
- [ ] Public GitHub repo URL (repo is public — OK) or hosted MCP server URL.
- [ ] Brief description (draft in marketplace-entry.json).
- [ ] Testing instructions: clone steps + a sample board; reviewers need a way
      to try it (a test Asana/ClickUp workspace with sample tasks + token, or
      the read-only `fetch_project` against a public board).
- [ ] Test it in Grok Bot first — the form requires the "tested locally and
      in-app" checkbox.
- [ ] Read Publisher Terms: listings must be FREE to users, open-source parts
      must be permissive-licensed (MIT is fine), no training on user data,
      publisher owns support and security reports.

## Route B — PR to the marketplace index repo
Repo: https://github.com/xai-org/plugin-marketplace
- [ ] Fork, branch from main.
- [ ] Add marketplace-entry.json contents to `.grok-plugin/marketplace.json`
      with the real pinned HEAD sha (40-char, lowercase).
- [ ] `python3 scripts/generate-plugin-index.py` (never hand-edit the index).
- [ ] Validate: `scripts/validate-catalog.py` and `generate-plugin-index.py --check`.
- [ ] Open the PR, fill the template, wait for CI + code-owner review.

Note: their review statically audits scripts for supply-chain risk — our
scripts call only the six documented PM APIs with user-provided tokens, no
telemetry, no downloads. Declare that in the PR body.
