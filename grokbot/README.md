# Use in Grok Bot

This directory is the **Grok Bot** packaging of the Project board organizer skill
([sand-workflow:project-board-organizer](sand-workflow:project-board-organizer)).

It is available as a Grok Bot skill in the skill library, and can ship inside a
shareable **Project Organizer** bot template so anyone can spin up their own copy
with the Asana (or other) connector attached.

How it differs from the root Claude Code `SKILL.md`:
- Prefers the Grok Bot / Cursor app connector over a raw API token
- Writes a local snapshot before any board writes (for undo)
- Same multi-tool flow: detect from URL → fetch → rewrite for audience → preview → apply
- Never deletes tasks

To use it: add this skill to a Grok Bot (or install the Project Organizer template),
connect the project-management connector you need, then paste a board URL and say
who the audience is.
