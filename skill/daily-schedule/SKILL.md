---
name: super-productivity-daily-schedule
description: >-
  Daily schedule planning and task tracking in the Super Productivity desktop
  app via its Local REST API (MCP tools prefixed sp_*). Use this whenever the
  user wants to add a todo, plan or review their day, check what's on their
  plate today, start/stop time tracking on a task, mark something done, or
  otherwise manage their Super Productivity task list — even if they just say
  "add that to my todos", "what am I working on", or "help me plan my day".
  Requires the MCP server already be set up — if sp_health fails, use the
  super-productivity-onboarding skill instead.
---

# Super Productivity: planning & tracking

Talk to the user's local Super Productivity desktop app through the `sp_*`
MCP tools. The app must be running with **Settings → Misc → Enable local
REST API** turned on — it listens on `http://127.0.0.1:3876` and only
accepts localhost connections (no auth).

## Before anything else

Call `sp_health` once at the start of a task-management conversation. If it
fails with `CONNECTION_FAILED`, tell the user to open Super Productivity and
enable the local REST API in Settings → Misc, then retry — don't guess or
fabricate task data.

## Core tools

- `sp_list_tasks` — search/filter tasks. Use `tagId: "TODAY"` for today's
  list, `includeDone: true` to include finished tasks, `source: "archived"`
  for the archive.
- `sp_get_task` — fetch one task by id.
- `sp_create_task` — create a task. **Always run `sp_list_tasks` with a
  `query` match first** to avoid creating a duplicate of something that
  already exists.
- `sp_update_task` — patch title, notes, isDone, estimates, project, tags,
  due date, etc.
- `sp_delete_task` — permanent removal; confirm with the user before calling
  this, since it can't be undone through the API.
- `sp_start_task` / `sp_stop_current_task` — time tracking.
- `sp_get_current_task` / `sp_get_status` — what's active right now and
  overall counts.
- `sp_archive_task` / `sp_restore_task` — archive lifecycle.
- `sp_list_projects` / `sp_list_tags` — look up ids before filtering or
  assigning a task to a project/tag; task creation needs the project/tag
  **id**, not its display title.

## Known limitation: no create/update for projects or tags

Super Productivity's Local REST API exposes `/projects` and `/tags` as
**read-only** (GET only) — there is no HTTP way to create or rename a
project or tag. `sp_list_projects`/`sp_list_tags` only ever list what
already exists.

If the user asks to file a task under a project or tag that doesn't exist
yet, **don't fail silently or invent an id.** Tell them the project/tag
needs to be created inside the Super Productivity app first (sidebar → +
next to Projects/Tags), then retry once they've done that. This is a
platform limitation, not a bug — the only programmatic way around it is
Super Productivity's separate in-app Plugin API (`addProject`/`addTag`),
which is a different, unsandboxed extension mechanism this MCP server
does not implement.

## Conventions

- Task ids are opaque strings returned by the API — don't invent them.
- `dueDay` is `YYYY-MM-DD`; `dueWithTime` and `plannedAt` are Unix ms
  timestamps.
- When the user references a task by name ("mark the report done"),
  resolve it with `sp_list_tasks({query: ...})` first and confirm the match
  before mutating if more than one task matches.

## Daily planning workflow

When the user wants to plan or review their day:

1. `sp_get_status` + `sp_list_tasks({tagId: "TODAY"})` to see what's already
   scheduled and what's currently being tracked.
2. If they're brain-dumping new items, batch-create with `sp_create_task`
   (checking for duplicates first per above), and use `dueDay`/`plannedAt`
   to slot them into today or a specific time.
3. If they ask "what should I work on", surface undone tasks sorted by
   what's overdue (`dueDay` in the past) or explicitly planned for now,
   rather than guessing priority yourself — ask if it's ambiguous.
4. When they say "I'm starting X", call `sp_start_task`; when they say
   "done" or "stop", call `sp_stop_current_task` (and `sp_update_task` with
   `isDone: true` if they also finished it, not just paused).
5. For an end-of-day review, list today's tasks with `includeDone: true`
   and summarize what got done vs. carried over — offer to reschedule
   carry-overs (`dueDay`) rather than leaving them dangling.
