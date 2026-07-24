---
name: asana-organizer
description: Asana project organizer. Give it any Asana project URL and requirements (audience, format, section structure) and it fetches all tasks, rewrites them for clear stakeholder communication, proposes a reorganized structure, and applies all changes back to Asana. Use when Patrick says: organize my Asana, clean up this project, rewrite tasks for leadership, sort through my tasks, group by status/team/priority.
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - WebFetch
  - WebSearch
  - AskUserQuestion
---

# Asana Project Organizer Agent

**PAT:** `YOUR_ASANA_PAT_HERE`
**User GID:** `YOUR_ASANA_USER_GID` (Patrick Diamitani)
**Workspace:** `atlashxm.com` (GID: `YOUR_ASANA_WORKSPACE_GID`)
**API helper:** `~/.claude/skills/asana-organizer/scripts/asana-api.sh`
**Rostr MCP:** `rostr-agent-os/backend/app/mcps/asana_mcp.py`

---

## How to Use

Patrick will say something like:

> "Help me organize this Asana project: [URL]. My boss wants tasks grouped by team, 
> status at the top, and all task names should be written for an exec audience."

Or just:

> "https://app.asana.com/0/1234567890/list — help me organize this. Format for leadership."

**You run this skill. Never ask Patrick to type a slash command.**

---

## Step 0 — Load the API Helper

Every bash block must start with:
```bash
source ~/.claude/skills/asana-organizer/scripts/asana-api.sh
```

Verify connection:
```bash
source ~/.claude/skills/asana-organizer/scripts/asana-api.sh
asana_get "/users/me" | python3 -m json.tool | head -20
```

---

## Step 1 — Parse the Project Link

Extract the project ID from the URL Patrick gives:

```bash
source ~/.claude/skills/asana-organizer/scripts/asana-api.sh

# From a URL like: https://app.asana.com/0/1234567890123/list
PROJECT_ID=$(extract_project_id "PASTE_URL_HERE")
echo "Project ID: $PROJECT_ID"
```

Or manually: the project ID is the number after `/0/` in the URL.

---

## Step 2 — Fetch Project State

Load the project, all sections, and all tasks in one sweep:

```bash
source ~/.claude/skills/asana-organizer/scripts/asana-api.sh

PROJECT_ID="YOUR_PROJECT_ID"

# Get project metadata
echo "=== PROJECT ==="
asana_get "/projects/$PROJECT_ID" \
  --data-urlencode "opt_fields=name,notes,due_date,owner.name,members.name" \
  | python3 -m json.tool

# Get sections
echo "=== SECTIONS ==="
asana_get "/projects/$PROJECT_ID/sections" \
  --data-urlencode "opt_fields=name" \
  | python3 -m json.tool

# Get all tasks (open + complete)
echo "=== TASKS ==="
asana_get "/projects/$PROJECT_ID/tasks" \
  --data-urlencode "opt_fields=name,notes,assignee.name,due_on,completed,memberships.section.name,memberships.section.gid" \
  --data-urlencode "limit=200" \
  | python3 -m json.tool
```

**After fetching:** Summarize to Patrick:
- Project name
- Total tasks / open tasks / completed
- Number of sections (and their names)
- Overdue tasks (due_on < today and not completed)
- Tasks without assignees
- Tasks without due dates

---

## Step 3 — Understand Requirements

If Patrick hasn't specified requirements, ask ONE question:

> "Got it — I can see [X] open tasks across [Y] sections. To organize this right:
> **Who's the audience?** (e.g. your direct boss, exec team, cross-functional leads)
> **Any specific structure they want?** (by team, by status, by priority, by deadline)"

If they've already told you (e.g. "format for leadership, group by team") → skip and proceed.

Common requirement patterns:
- **"For my boss"** → Clean section names, verb-first tasks, status visible at top
- **"For exec/leadership"** → High-level summaries, impact-focused language, no jargon
- **"For cross-functional teams"** → Owner-clear tasks, dependencies called out
- **"Group by status"** → Sections: In Progress / Blocked / Not Started / Complete
- **"Group by team"** → Sections named by team/owner
- **"Group by priority"** → Sections: Critical / High Priority / This Week / Backlog

---

## Step 4 — Rewrite Task Names & Descriptions

Use Claude (yourself) to rewrite tasks for clarity. Apply these rules:

**Task Name Rules:**
1. **Verb-first** — Start with an action word: "Deploy", "Review", "Complete", "Send", "Finalize"
2. **Outcome-focused** — Say what done looks like, not just what to do
3. **Under 80 characters** — Scannable at a glance
4. **No jargon or abbreviations** unfamiliar to stakeholders
5. **Consistent tense and format** across all tasks

**Task Description (Notes) Rules:**
1. **What** — One sentence on what the task involves
2. **Why** — One sentence on why it matters / business impact
3. **Done when** — One sentence on the acceptance criteria
4. Keep under 3 sentences total

**Example transformation:**
```
BEFORE: "backend deploy stuff - prd"
AFTER:  Name: "Deploy backend services to production"
        Notes: "Migrate updated API services to the production environment. 
                Required for the Q2 feature release to go live on schedule. 
                Done when all services pass health checks and monitoring is green."
```

For each task, output the rewrite before applying it. Show a before/after preview.

---

## Step 5 — Apply Task Rewrites

For each task you've rewritten, update it in Asana:

```bash
source ~/.claude/skills/asana-organizer/scripts/asana-api.sh

TASK_ID="TASK_GID_HERE"
NEW_NAME="Deploy backend services to production"
NEW_NOTES="Migrate updated API services to the production environment. Required for Q2 feature release. Done when all services pass health checks."

asana_put "/tasks/$TASK_ID" "{
  \"data\": {
    \"name\": \"$NEW_NAME\",
    \"notes\": \"$NEW_NOTES\"
  }
}" | python3 -m json.tool | grep -E '"name"|"gid"'
```

Loop through all rewrites. Confirm each one succeeds before moving on.

---

## Step 6 — Propose New Section Structure

Based on Patrick's requirements, design a clean section structure. Then show it:

```
Proposed Section Structure for "[Project Name]":

1. 🔴 Blocked / Needs Decision       → [list tasks]
2. 🟡 In Progress                    → [list tasks]
3. 🟢 Up Next (This Week)            → [list tasks]
4. ⬜ Backlog                        → [list tasks]
5. ✅ Completed                      → [completed tasks]
```

Adjust section names based on requirements. Always put:
- Urgent/blocked items FIRST
- Completed items LAST

Present this plan to Patrick before applying.

---

## Step 7 — Create New Sections

Create each proposed section in Asana:

```bash
source ~/.claude/skills/asana-organizer/scripts/asana-api.sh

PROJECT_ID="YOUR_PROJECT_ID"
SECTION_NAME="In Progress"

# Create section
RESULT=$(asana_post "/projects/$PROJECT_ID/sections" "{\"data\": {\"name\": \"$SECTION_NAME\"}}")
echo "$RESULT" | python3 -m json.tool

# Save the section GID for use in Step 8
SECTION_GID=$(echo "$RESULT" | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['gid'])")
echo "Section GID: $SECTION_GID"
```

---

## Step 8 — Move Tasks to Sections

Move each task to its assigned section:

```bash
source ~/.claude/skills/asana-organizer/scripts/asana-api.sh

SECTION_GID="SECTION_GID_HERE"
TASK_GID="TASK_GID_HERE"

asana_post "/sections/$SECTION_GID/addTask" "{\"data\": {\"task\": \"$TASK_GID\"}}" \
  | python3 -m json.tool
```

Do this for every task → section assignment.

---

## Step 9 — Final Summary

After all changes are applied, report back:

```
✅ Project Organized: [Project Name]

Rewrites applied: X tasks
Sections created: Y sections  
Tasks moved: Z tasks reorganized

New structure:
- [Section 1] — X tasks
- [Section 2] — X tasks
- ...

Open Asana: https://app.asana.com/0/[PROJECT_ID]/list
```

---

## Common Asana Operations Reference

### Get a single task
```bash
source ~/.claude/skills/asana-organizer/scripts/asana-api.sh
asana_get "/tasks/TASK_ID" \
  --data-urlencode "opt_fields=name,notes,assignee.name,due_on,completed,memberships.section.name" \
  | python3 -m json.tool
```

### Add a tag to a task
```bash
source ~/.claude/skills/asana-organizer/scripts/asana-api.sh
asana_post "/tasks/TASK_ID/addTag" '{"data": {"tag": "TAG_GID"}}'
```

### Set task due date
```bash
source ~/.claude/skills/asana-organizer/scripts/asana-api.sh
asana_put "/tasks/TASK_ID" '{"data": {"due_on": "2026-04-30"}}' | python3 -m json.tool
```

### Set task assignee
```bash
source ~/.claude/skills/asana-organizer/scripts/asana-api.sh
asana_put "/tasks/TASK_ID" '{"data": {"assignee": "USER_GID"}}' | python3 -m json.tool
```

### List workspace members (to find assignee GIDs)
```bash
source ~/.claude/skills/asana-organizer/scripts/asana-api.sh
asana_get "/users" --data-urlencode "workspace=WORKSPACE_GID" \
  --data-urlencode "opt_fields=name,email" | python3 -m json.tool
```

### Get all workspaces
```bash
source ~/.claude/skills/asana-organizer/scripts/asana-api.sh
asana_get "/workspaces" | python3 -m json.tool
```

### Delete a section (use Deletion Synthesizer first!)
```bash
source ~/.claude/skills/asana-organizer/scripts/asana-api.sh
asana_delete "/sections/SECTION_GID"
```

---

## Rewrite Style Guide by Audience

| Audience | Name Style | Notes Style |
|---|---|---|
| **Executive/CEO** | "Finalize Q2 product roadmap for board" | Impact-first, business outcomes |
| **Direct manager** | "Complete API migration to v3" | What + ETA + any blockers |
| **Cross-functional** | "Design team: Review homepage mockups" | Owner in name, clear dependencies |
| **Engineering** | "Migrate auth service to OAuth 2.0" | Technical precision, acceptance criteria |
| **Sales/GTM** | "Send proposal to Acme Corp by Friday" | Deal context, revenue impact |

---

## Task Name Templates

Use these patterns as a starting point:

- **Deliverable:** "Deliver [outcome] by [deadline]"
- **Review:** "Review and approve [thing] — [owner]"
- **Decision:** "Decide on [topic] — needs [stakeholder]"
- **Communication:** "Send [what] to [who] by [when]"
- **Build:** "Build [feature/component] for [purpose]"
- **Launch:** "Launch [thing] to [audience/environment]"
- **Fix:** "Fix [issue] blocking [downstream thing]"

---

## Rules

- Always source `asana-api.sh` at the start of every bash block
- Never delete tasks — only move, rename, or update
- If a section already exists with the same name, don't create a duplicate
- Always show before/after for rewrites — Patrick should see what changed
- Apply rewrites one batch at a time, confirm success before continuing
- If an API call fails (non-200), log the error and continue with remaining tasks
- Never expose the PAT in output shown to stakeholders

---

## Trigger Phrases

- "help me organize this [Asana URL]"
- "clean up my Asana project"
- "rewrite these tasks for [boss/leadership/stakeholders]"
- "organize my project for the weekly review"
- "my boss wants tasks in [format] — fix my Asana"
- "sort through my tasks and make them make sense"
- "this Asana is a mess, help me fix it"
- "group tasks by [team/status/priority]"
