---
name: super-productivity-onboarding
description: >-
  Set up Super Productivity, its Local REST API MCP server, and the
  super-productivity-daily-schedule skill on this machine. Use this when the user
  wants to install/set up/onboard Super Productivity integration, when
  someone points you at this repo's ONBOARDING.md, or when
  super-productivity-daily-schedule's sp_health check fails and the user wants to
  fix it. Detects OS, briefs the user, gets explicit go-ahead, then runs the
  install end-to-end.
---

# Super Productivity: onboarding

You are setting up a brand-new machine (or repairing a broken install) so
Claude can manage the user's Super Productivity tasks. Follow these steps
in order. Do not skip the briefing/confirmation step even if the user
seems to already know what this is — installing software still needs
explicit go-ahead.

## 1. Detect the OS

Run a quick check (e.g. `$PSVersionTable`/`uname` depending on what shell
tool you have) to determine Windows vs macOS vs Linux. This decides which
installer script you run in step 3.

## 2. Brief the user and get explicit go-ahead

Before touching anything, tell the user in plain language what you're
about to do and why, then ask for confirmation (use AskUserQuestion if
available, otherwise a direct yes/no in chat) before proceeding:

- Check whether the **Super Productivity** desktop app is installed; if
  not, open its download page and stop, asking them to install it and
  bring you back.
- Install **Bun** if it's missing, using the official installer — no admin
  rights required:
  - Windows (PowerShell): `powershell -c "irm bun.sh/install.ps1 | iex"`
  - macOS/Linux (bash): `curl -fsSL https://bun.sh/install | bash`

  This is only used to compile the MCP server; it is not left running as
  a dependency.
- Download the `super-productivity-mcp` repo, compile it into a single
  standalone executable (no Node/Bun needed afterward), and register it
  with Claude Code (`claude mcp add -s user super-productivity -- <exe>`).
- Install both Claude skills (`super-productivity-onboarding`, this one,
  and `super-productivity-daily-schedule`) into `~/.claude/skills/`.
- Ask them to flip **one manual toggle** in the app: Settings → Misc →
  "Enable local REST API" — this can't be scripted safely since it's
  in-app UI state, not a config file.

Do not proceed past this point without a clear yes.

## 3. Run the installer for the detected OS

- Windows (PowerShell):
  `irm https://raw.githubusercontent.com/kailasas-auspicious/super-productivity-mcp/main/install/install.ps1 | iex`
- macOS/Linux (bash):
  `curl -fsSL https://raw.githubusercontent.com/kailasas-auspicious/super-productivity-mcp/main/install/install.sh | bash`

If the Super Productivity app isn't installed, the script opens the
download page and exits early — tell the user to install it and re-run
the same command (you can re-invoke it yourself once they confirm it's
installed).

The script installs Bun itself via the official installer
(https://bun.sh/install, https://bun.sh/install.ps1) if it detects it's
missing, so you normally don't need to run that command separately —
it's listed above so the briefing is accurate about what's about to
happen, and as a manual fallback if the script's auto-install step fails
for any reason.

Stream the script's output to the user rather than running it silently;
if any step fails, diagnose from the error text before retrying — don't
loop blindly.

## 4. Ask for the manual REST API toggle

Remind the user to open Super Productivity → Settings → Misc → enable
"Enable local REST API" (restart the app if it doesn't seem to take
effect). This is the one step that has to be done by hand.

## 5. Verify

Call the `sp_health` MCP tool (from the newly-registered
`super-productivity` server — this may require the user start a new
Claude Code session first, since MCP servers load at startup). It should
return `{"server":"up","rendererReady":true}`. If it returns
`CONNECTION_FAILED`, walk back through step 4.

## 6. Hand off

Tell the user setup is complete and that they can now ask things like
"what's on my task list today" or "help me plan my day" — the
`super-productivity-daily-schedule` skill and its `sp_*` tools take it from
here.
