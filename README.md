# super-productivity-mcp

An MCP server and two Claude skills for [Super Productivity](https://super-productivity.com/)'s
[Local REST API](https://github.com/super-productivity/super-productivity/wiki/3.01-API),
plus a one-line installer so a teammate can onboard by pointing their Claude
co-worker at this repo.

Super Productivity's API runs on `http://127.0.0.1:3876`, requires no auth
(localhost-only), and must be turned on manually via **Settings → Misc →
Enable local REST API**.

## The two skills

- **`super-productivity-onboarding`** — drives setup itself: detects the
  user's OS, briefs them on what it's about to install and why, gets
  explicit go-ahead, then installs Super Productivity (if missing), Bun,
  builds and registers the MCP server, installs both skills, and verifies
  everything works.
- **`super-productivity-daily-schedule`** — day-to-day use: planning the
  day, adding/checking off tasks, time tracking, end-of-day review, via
  the `sp_*` MCP tools.

## Onboard someone else

Point their Claude Code at the raw URL of [`ONBOARDING.md`](./ONBOARDING.md)
and ask it to follow the steps — it directs Claude to read and execute
`skill/onboarding/SKILL.md`, which will:

1. Detect their OS and brief them on the plan, then wait for a clear
   go-ahead before installing anything.
2. Check for the Super Productivity desktop app (and open the download page
   if it's missing).
3. Install [Bun](https://bun.sh) if needed (no admin rights required).
4. Download this repo and compile the MCP server into a single standalone
   executable — no Node/Bun required at runtime after this.
5. Install both Claude skills into `~/.claude/skills/`.
6. Register the server with Claude Code: `claude mcp add -s user
   super-productivity -- <path-to-exe>`.
7. Ask the user to flip the "Enable local REST API" checkbox in the app's
   Settings — the one step that can't be scripted safely, since it's
   in-app UI state rather than a config file — then verify with `sp_health`.

Manual equivalent (Windows PowerShell):

```powershell
irm https://raw.githubusercontent.com/kailasas-auspicious/super-productivity-mcp/main/install/install.ps1 | iex
```

Manual equivalent (macOS/Linux):

```bash
curl -fsSL https://raw.githubusercontent.com/kailasas-auspicious/super-productivity-mcp/main/install/install.sh | bash
```

## What's in here

- `src/` — the MCP server (TypeScript), wraps every endpoint of the Local
  REST API (`sp_list_tasks`, `sp_create_task`, `sp_update_task`,
  `sp_start_task`, `sp_get_status`, `sp_list_projects`, etc).
- `skill/onboarding/SKILL.md` — drives first-time setup (OS detection,
  briefing, install, verify).
- `skill/daily-schedule/SKILL.md` — day-to-day task/schedule management via
  the `sp_*` tools.
- `install/` — the underlying install scripts the onboarding skill runs.
- `ONBOARDING.md` — a thin pointer for Claude, not a human, to the
  onboarding skill.

## Local dev

```bash
bun install
bun run dev          # runs src/index.ts directly via tsx
bun run build        # tsc -> dist/
bun build ./src/index.ts --compile --outfile dist/super-productivity-mcp
```

Point Claude Code at your local build for testing:

```bash
claude mcp add -s user super-productivity -- bun run --cwd /path/to/super-productivity-mcp src/index.ts
```

## Config

Set `SP_API_URL` if Super Productivity's API isn't on the default
`http://127.0.0.1:3876`.
