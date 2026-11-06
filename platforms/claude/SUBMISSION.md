# Anthropic Claude Directory — submission steps

Route: developer portal at https://claude.ai/directory/manage (submit from a
GitHub repo; Anthropic reviews each version before it goes live; users add it
from claude.ai for chat, Cowork and Claude Code).

## Prep
- [ ] GitHub account connected on claude.ai.
- [ ] `.claude-plugin/plugin.json` (in this folder) merged to the default
      branch — the directory reads it from GitHub. Move it to the repo root
      `.claude-plugin/` before submitting, or point the directory at the path.
- [ ] SKILL.md frontmatter passes spec: name <=64 chars lowercase-hyphen,
      description <=1024 chars, third person (done in PR).
- [ ] LICENSE present (added in this PR — directory and Grok both require it).

## Submit
- [ ] Open https://claude.ai/directory/manage, choose the repo, submit.
- [ ] Answer review findings if any; publish when approved.

Local-install path (no review): users git clone the repo into
`~/.claude/skills/asana-organizer/` or a project's `.claude/skills/`.

Docs: https://claude.com/docs/plugins/submit and
https://platform.claude.com/docs/en/agents-and-tools/agent-skills/overview
