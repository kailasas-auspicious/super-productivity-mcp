#!/usr/bin/env bash
# Onboards Super Productivity + its MCP server + its Claude skill on macOS/Linux.
# Run via:
#   curl -fsSL https://raw.githubusercontent.com/kailasas-auspicious/super-productivity-mcp/main/install/install.sh | bash
set -euo pipefail

REPO_URL="https://github.com/kailasas-auspicious/super-productivity-mcp"
INSTALL_DIR="$HOME/.super-productivity-mcp"
ONBOARDING_SKILL_DIR="$HOME/.claude/skills/super-productivity-onboarding"
DAILY_SCHEDULE_SKILL_DIR="$HOME/.claude/skills/super-productivity-daily-schedule"
BIN_PATH="$INSTALL_DIR/super-productivity-mcp"

step() { printf "\033[36m==> %s\033[0m\n" "$1"; }
ok()   { printf "    \033[32m%s\033[0m\n" "$1"; }
warn() { printf "    \033[33m%s\033[0m\n" "$1"; }

step "Checking for Super Productivity desktop app"
SP_FOUND=0
if [[ "$(uname)" == "Darwin" ]] && [[ -d "/Applications/Super Productivity.app" ]]; then
  SP_FOUND=1
elif command -v superProductivity >/dev/null 2>&1; then
  SP_FOUND=1
elif pgrep -if "superProductivity|Super Productivity" >/dev/null 2>&1; then
  SP_FOUND=1
fi

if [[ "$SP_FOUND" -eq 0 ]]; then
  warn "Super Productivity doesn't look installed."
  warn "Opening the download page — install it, then re-run this script."
  if [[ "$(uname)" == "Darwin" ]]; then
    open "https://super-productivity.com/" || true
  else
    xdg-open "https://super-productivity.com/" >/dev/null 2>&1 || echo "Visit https://super-productivity.com/"
  fi
  exit 0
fi
ok "Super Productivity found"

step "Checking for Bun"
if ! command -v bun >/dev/null 2>&1; then
  warn "Bun not found — installing (no admin rights required)"
  curl -fsSL https://bun.sh/install | bash
  export PATH="$HOME/.bun/bin:$PATH"
  if ! command -v bun >/dev/null 2>&1; then
    echo "Bun install did not complete. Restart your shell and re-run this script." >&2
    exit 1
  fi
fi
ok "Bun available: $(bun --version)"

step "Building the MCP server"
mkdir -p "$INSTALL_DIR"
TMP_TARBALL="$INSTALL_DIR/src.tar.gz"
curl -fsSL "$REPO_URL/archive/refs/heads/main.tar.gz" -o "$TMP_TARBALL"
tar -xzf "$TMP_TARBALL" -C "$INSTALL_DIR"
rm -f "$TMP_TARBALL"
REPO_DIR="$(find "$INSTALL_DIR" -maxdepth 1 -type d -name "*-main" | head -n1)"

(
  cd "$REPO_DIR"
  bun install
  bun build ./src/index.ts --compile --outfile "$BIN_PATH"
)
chmod +x "$BIN_PATH"
ok "Built $BIN_PATH"

step "Installing the Claude skills"
mkdir -p "$ONBOARDING_SKILL_DIR" "$DAILY_SCHEDULE_SKILL_DIR"
cp "$REPO_DIR/skill/onboarding/SKILL.md" "$ONBOARDING_SKILL_DIR/SKILL.md"
cp "$REPO_DIR/skill/daily-schedule/SKILL.md" "$DAILY_SCHEDULE_SKILL_DIR/SKILL.md"
ok "Skills installed to $ONBOARDING_SKILL_DIR and $DAILY_SCHEDULE_SKILL_DIR"

step "Registering MCP server with Claude Code"
if ! command -v claude >/dev/null 2>&1; then
  warn "Claude Code CLI ('claude') not found on PATH."
  warn "Install Claude Code, then run:"
  warn "  claude mcp add -s user super-productivity -- \"$BIN_PATH\""
else
  claude mcp remove -s user super-productivity >/dev/null 2>&1 || true
  claude mcp add -s user super-productivity -- "$BIN_PATH"
  ok "Registered 'super-productivity' MCP server (user scope)"
fi

echo ""
printf "\033[36mOne manual step left:\033[0m\n"
printf "\033[36m  Open Super Productivity -> Settings -> Misc -> enable 'Local REST API'\033[0m\n"
printf "\033[36m  (restart the app if the toggle doesn't take effect immediately)\033[0m\n"
echo ""
printf "\033[32mDone. Start a new Claude Code session and ask it about your tasks.\033[0m\n"
