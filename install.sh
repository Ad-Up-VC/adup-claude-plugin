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

# Set the API key as environment variable
export ADUP_API_KEY="$API_KEY"

echo -e "${YELLOW}Step 1/3:${NC} Setting API key..."
echo "  export ADUP_API_KEY=****${API_KEY: -4}"

# Persist the API key in shell profile
SHELL_PROFILE=""
if [ -f "$HOME/.zshrc" ]; then
  SHELL_PROFILE="$HOME/.zshrc"
elif [ -f "$HOME/.bashrc" ]; then
  SHELL_PROFILE="$HOME/.bashrc"
elif [ -f "$HOME/.bash_profile" ]; then
  SHELL_PROFILE="$HOME/.bash_profile"
fi

if [ -n "$SHELL_PROFILE" ]; then
  # Remove any existing ADUP_API_KEY line and add new one
  grep -v "export ADUP_API_KEY=" "$SHELL_PROFILE" > "$SHELL_PROFILE.tmp" 2>/dev/null || true
  mv "$SHELL_PROFILE.tmp" "$SHELL_PROFILE"
  echo "export ADUP_API_KEY=\"$API_KEY\"" >> "$SHELL_PROFILE"
  echo -e "  ${GREEN}✓${NC} API key saved to $SHELL_PROFILE"
else
  echo -e "  ${YELLOW}!${NC} Could not find shell profile. Add this to your shell config:"
  echo "    export ADUP_API_KEY=\"$API_KEY\""
fi

echo ""
echo -e "${YELLOW}Step 2/3:${NC} Installing plugin..."

# Get the directory where this script lives (the plugin directory)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

claude plugin install adup --plugin-dir "$SCRIPT_DIR"

echo ""
echo -e "${YELLOW}Step 3/3:${NC} Verifying installation..."
echo -e "  ${GREEN}✓${NC} Plugin installed successfully!"
echo ""
echo "  ┌─────────────────────────────────────────┐"
echo "  │  Open Claude Code and run:               │"
echo "  │                                          │"
echo "  │    /adup:connect                         │"
echo "  │                                          │"
echo "  │  to verify your connection.              │"
echo "  └─────────────────────────────────────────┘"
echo ""
