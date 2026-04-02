#!/bin/bash
#
# ADUP Claude Plugin Installer
# Usage: ./install.sh YOUR_API_KEY
#

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo ""
echo "  ╔══════════════════════════════════════╗"
echo "  ║     ADUP Claude Plugin Installer     ║"
echo "  ╚══════════════════════════════════════╝"
echo ""

# Check for API key argument
if [ -z "$1" ]; then
  echo -e "${RED}Error:${NC} Please provide your ADUP API key."
  echo ""
  echo "  Usage: ./install.sh YOUR_API_KEY"
  echo ""
  echo "  You can find your API key in the ADUP onboarding dashboard."
  exit 1
fi

API_KEY="$1"

# Check if claude CLI is available
if ! command -v claude &> /dev/null; then
  echo -e "${RED}Error:${NC} Claude Code CLI not found."
  echo ""
  echo "  Please install Claude Code first:"
  echo "  https://claude.ai/download"
  echo ""
  exit 1
fi

# Set the API key for this terminal session
export ADUP_API_KEY="$API_KEY"

echo -e "${YELLOW}Step 1/3:${NC} Saving API key for this user ($USER)..."
echo "  ADUP_API_KEY=****${API_KEY: -4}"

# ── Method 1: macOS LaunchAgent (the correct approach for GUI apps) ──────────
#
# On macOS, GUI apps (like Cowork and Claude Code desktop) do NOT source shell
# profiles (.zshrc, .bashrc). The only reliable way to set an env var that
# a desktop app can read is via launchctl.
#
# We create a per-user LaunchAgent plist in ~/Library/LaunchAgents/ — this
# directory is owned by and isolated to the current macOS user, so two different
# Mac users will each have their own independent key here.
#
# The plist runs `launchctl setenv ADUP_API_KEY <value>` at login, making the
# env var available to all GUI apps launched by that user.
# launchctl setenv also takes effect immediately in the current session.

LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"
PLIST_FILE="$LAUNCH_AGENTS_DIR/io.adup.env.ADUP_API_KEY.plist"

mkdir -p "$LAUNCH_AGENTS_DIR"

cat > "$PLIST_FILE" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>io.adup.env.ADUP_API_KEY</string>
    <key>ProgramArguments</key>
    <array>
        <string>launchctl</string>
        <string>setenv</string>
        <string>ADUP_API_KEY</string>
        <string>${API_KEY}</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
</dict>
</plist>
PLIST

# Load it immediately so desktop apps can pick it up right now
launchctl unload "$PLIST_FILE" 2>/dev/null || true
launchctl load "$PLIST_FILE"
launchctl setenv ADUP_API_KEY "$API_KEY"

echo -e "  ${GREEN}✓${NC} API key registered as macOS LaunchAgent — available to all desktop apps for this user"
echo -e "     Saved to: ~/Library/LaunchAgents/io.adup.env.ADUP_API_KEY.plist"

# ── Method 2: Claude Code CLI settings (for claude CLI users) ────────────────
#
# Claude Code CLI reads ~/.claude/settings.json at startup and injects env vars
# into MCP servers. This covers the `claude` terminal workflow.

mkdir -p "$HOME/.claude"
SETTINGS_FILE="$HOME/.claude/settings.json"

python3 - "$SETTINGS_FILE" "$API_KEY" <<'PYEOF'
import json, sys

settings_path = sys.argv[1]
api_key = sys.argv[2]

try:
    with open(settings_path, "r") as f:
        settings = json.load(f)
except (FileNotFoundError, json.JSONDecodeError):
    settings = {}

settings.setdefault("env", {})
settings["env"]["ADUP_API_KEY"] = api_key

with open(settings_path, "w") as f:
    json.dump(settings, f, indent=2)
PYEOF

echo -e "  ${GREEN}✓${NC} API key saved to ~/.claude/settings.json (for Claude Code CLI)"

# ── Method 3: Shell profile (for terminal sessions) ──────────────────────────

SHELL_PROFILE=""
if [ -f "$HOME/.zshrc" ]; then
  SHELL_PROFILE="$HOME/.zshrc"
elif [ -f "$HOME/.bashrc" ]; then
  SHELL_PROFILE="$HOME/.bashrc"
elif [ -f "$HOME/.bash_profile" ]; then
  SHELL_PROFILE="$HOME/.bash_profile"
fi

if [ -n "$SHELL_PROFILE" ]; then
  grep -v "export ADUP_API_KEY=" "$SHELL_PROFILE" > "$SHELL_PROFILE.tmp" 2>/dev/null || true
  mv "$SHELL_PROFILE.tmp" "$SHELL_PROFILE"
  echo "export ADUP_API_KEY=\"$API_KEY\"" >> "$SHELL_PROFILE"
  echo -e "  ${GREEN}✓${NC} API key added to $SHELL_PROFILE (for new terminal sessions)"
fi

echo ""
echo -e "${YELLOW}Step 2/3:${NC} Installing plugin for this user..."

# Get the directory where this script lives (the plugin directory)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Install the plugin. --force allows a second macOS user to install without
# hitting "already installed" from a previous user's registration.
claude plugin install adup --plugin-dir "$SCRIPT_DIR" --force 2>/dev/null || \
  claude plugin install adup --plugin-dir "$SCRIPT_DIR"

echo ""
echo -e "${YELLOW}Step 3/3:${NC} Verifying installation..."
echo -e "  ${GREEN}✓${NC} Plugin installed successfully!"
echo ""
echo "  ┌──────────────────────────────────────────────────┐"
echo "  │  Open Claude Code or Cowork and run:             │"
echo "  │                                                  │"
echo "  │    /adup:connect                                 │"
echo "  │                                                  │"
echo "  │  to verify your connection.                      │"
echo "  │                                                  │"
echo "  │  Note: Cowork needs to be restarted once to      │"
echo "  │  pick up the new environment variable.           │"
echo "  └──────────────────────────────────────────────────┘"
echo ""
