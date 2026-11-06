# OpenAI (ChatGPT + Codex) plugin directory — submission steps

Route: upload a ZIP at the plugin portal (platform.openai.com plugins section,
"Upload new or existing plugin"). A plugin can be skills-only, app-only (MCP),
or app+skills. This package is **skills-only** (no hosted MCP server yet).

Docs: https://developers.openai.com/plugins/deploy/submission and
https://learn.chatgpt.com/docs/submit-plugins

## Build the ZIP
```
plugin.json            <- this folder's file (at ZIP root)
skills/asana-organizer/SKILL.md
skills/asana-organizer/scripts/asana-api.sh
skills/asana-organizer/scripts/connectors.sh
skills/asana-organizer/scripts/setup.sh
assets/                <- icon + logo PNGs (see manifest fields)
```

## Before you upload (required materials)
- [ ] Verified developer identity in the OpenAI Platform org (individual
      verification for publishing under Patrick's name) — the form will not
      list the identity otherwise.
- [ ] Submitter has Apps Management = Write on the org role.
- [ ] Privacy policy URL and terms URL (placeholders in plugin.json marked
      `_NEEDED`) — the GitHub Pages site has neither; host both first.
- [ ] Icons/logo PNGs under `assets/` referenced by the manifest.
- [ ] 5 positive + 3 negative test cases with expected behavior.
- [ ] Starter prompts (drafted in plugin.json `defaultPrompt`).
- [ ] No secrets in the ZIP.

## Known packaging decision
The bash/python helpers need a shell. ChatGPT skills can carry instructions +
files, but API execution there is limited vs Claude Code/Codex. Two options:
1. Submit skills-only now; SKILL.md still drives the rewrite/reorg workflow
   with the user pasting API output.
2. Add a hosted MCP server later and resubmit as app+skills (an MCP server
   cannot be added to an existing skills-only plugin afterwards — it must be
   in the initial ZIP, so decide before first upload).

## Submit
- [ ] Upload ZIP, resolve automated findings, submit for review.
- [ ] Publish when approved (you choose when).
