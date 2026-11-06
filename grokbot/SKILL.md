---
name: project-board-organizer
description: >-
  Use when someone wants a messy project board (Asana, ClickUp, Monday, Trello,
  Notion, or Jira) cleaned up: task names rewritten for a specific audience and
  sections reorganized, with a preview before anything changes.
---

# Project board organizer

Clean up a messy project board so stakeholders can scan it. Detect the tool from
the URL, fetch the board, rewrite tasks for the audience, propose a section
structure, preview every change, then apply — without deleting anything.

Prefer the installed Grok Bot / Cursor connector for that tool over a raw API
token. Save a local snapshot before any write so changes can be undone.

## When to run

Trigger phrases include: organize my Asana/ClickUp/Monday/Trello/Notion/Jira,
clean up this project, rewrite tasks for leadership, group by status/team/priority,
format for [audience], sort through my tasks.

## Step 0 — Connect

1. Detect the tool from the project URL the user pastes:

| Host pattern | Tool |
|---|---|
| `app.asana.com` | Asana |
| `app.clickup.com` | ClickUp |
| `monday.com` | Monday |
| `trello.com` | Trello |
| `notion.so` | Notion |
| `atlassian.net` / Jira key | Jira |

2. Prefer the matching installed connector (check GetMcpServerStatus / connected
   tools, then SearchPlugins). Ask the user to connect it if it is installed but
   not signed in.
3. Only fall back to a user-provided API token / env var when no connector can do
   the job. Never invent or print a token.
4. If the user has not named an audience or grouping, ask ONE short question:
   who the board is for, and whether to group by status, team, priority, or deadline.

## Step 1 — Fetch and summarize

Fetch project metadata, sections, and tasks (open + complete when the API allows),
including assignee, due date, and current section.

Summarize to the user before rewriting:
- Project name
- Total / open / completed counts
- Section names
- Overdue, unassigned, and undated open tasks

## Step 2 — Snapshot (required before writes)

Write a JSON snapshot under `/workspace/board-snapshots/<tool>-<project_id>-<timestamp>.json`
with the fetched project, sections, and tasks (ids, names, notes, section, assignee,
due). Tell the user the path. This is the undo reference if a later apply goes wrong.

## Step 3 — Rewrite for the audience

Rewrite task names and notes. Show a before/after preview; do not apply yet.

**Name rules:** verb-first, outcome-focused, under ~80 characters, no stakeholder-unfamiliar jargon, consistent tense across the board.

**Notes rules (keep ≤3 sentences):** what it is, why it matters, done-when criteria.

Audience cues:
- Exec / leadership → impact-first, no jargon
- Direct manager → what + ETA + blockers
- Cross-functional → owner clear, dependencies named
- Engineering → precise, acceptance criteria
- Sales / GTM → deal context, revenue impact

## Step 4 — Propose section structure

Design sections from the user's grouping preference. Always put blocked/urgent
first and completed last. Example for status:

1. Blocked / Needs Decision
2. In Progress
3. Up Next (This Week)
4. Backlog
5. Completed

List which tasks move where. Wait for the user to approve the plan (or a revised one)
before applying.

## Step 5 — Apply (only after preview approval)

1. Reuse an existing section with the same name; do not create duplicates.
2. Create missing sections.
3. Update approved task name/notes rewrites.
4. Move tasks into their assigned sections.
5. Preserve due dates, assignees, custom fields, and dependencies unless the user
   explicitly asked to change them.
6. Never delete tasks. Never delete sections the user did not ask to remove.
7. If an API/connector call fails, log it, continue with the rest, and report failures.

## Step 6 — Final summary

Report:
- Project name + link
- Rewrites applied, sections created, tasks moved
- New structure with counts per section
- Snapshot path (for undo)
- Anything that failed

## Rules

- Connector first; raw token only as fallback the user supplied.
- Snapshot before the first write.
- Preview rewrites and the section plan; apply only after the user confirms.
- Never delete tasks.
- Idempotent: re-running on an already-organized board should reuse sections and
  avoid duplicate renames when names already match the plan.
- Do not expose tokens, PATs, or connector secrets in user-facing output.
