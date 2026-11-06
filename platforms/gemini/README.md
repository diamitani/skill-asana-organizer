# Gemini skills — install steps (no marketplace)

Google announced skills in Gemini chat on 2026-09-30 (rolling out globally,
replacing Gems; already in Gemini Spark). There is no public skill marketplace
or developer submission route today — skills are created inside the Gemini app.

Source: https://blog.google/products-and-platforms/products/gemini/automate-tasks-with-skills/

## Steps
- [ ] Open Gemini (gemini.google.com or the app) -> Skills -> Create skill.
- [ ] Paste the workflow instructions from SKILL.md (Steps 0-9, rewrite rules,
      audience table, trigger phrases) as the skill instructions.
- [ ] Caveat: Gemini chat cannot run the bash/python helpers. The skill works
      there as instructions-only: the user pastes their board export or task
      list, Gemini rewrites and restructures it, and the user applies changes.
- [ ] Re-check for a public Gemini skill directory — the rollout was in
      progress as of Nov 2026.
