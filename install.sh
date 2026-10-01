#!/bin/bash
#
# ADUP Claude Plugin Installer (v2.0.0 — OAuth sign-in, no key)
#
# Usage:
#   ./install.sh                        install the plugin, then sign in from Claude
#   ./install.sh --automation emp_KEY   ALSO add a key-based connector for a machine
#                                       that cannot open a browser (servers, CI)
#

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo ""
echo "  ╔══════════════════════════════════════╗"
echo "  ║     ADUP Claude Plugin Installer     ║"
echo "  ╚══════════════════════════════════════╝"
echo ""

AUTOMATION_KEY=""
case "${1:-}" in
  "") ;;
  --automation)
    AUTOMATION_KEY="${2:-}"
    if [ -z "$AUTOMATION_KEY" ]; then
      echo -e "${RED}Error:${NC} --automation needs the employee API key (emp_…) from Tara → My MCP setup."
      exit 1
    fi
    ;;
  emp_*)
    # v1 called this script with the key as the first argument. Keys are no
    # longer needed for interactive use — say so instead of silently storing it.
    echo -e "${YELLOW}Note:${NC} since v2.0.0 the plugin signs in with OAuth — no key is needed."
    echo "  For a machine that cannot open a browser, use: ./install.sh --automation emp_…"
    echo ""
    ;;
  *)
    echo "  Usage: ./install.sh [--automation emp_KEY]"
    exit 1
    ;;
esac

if ! command -v claude &> /dev/null; then
  echo -e "${RED}Error:${NC} Claude Code CLI not found."
  echo ""
  echo "  Please install Claude Code first:"
  echo "  https://claude.ai/download"
  echo ""
  exit 1
fi

echo -e "${YELLOW}Step 1/2:${NC} Installing the plugin for this user ($USER)..."

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --force allows a second macOS user to install without hitting "already
# installed" from a previous user's registration.
claude plugin install adup --plugin-dir "$SCRIPT_DIR" --force 2>/dev/null || \
  claude plugin install adup --plugin-dir "$SCRIPT_DIR"

echo -e "  ${GREEN}✓${NC} Plugin installed"
echo ""

if [ -n "$AUTOMATION_KEY" ]; then
  echo -e "${YELLOW}Step 2/2:${NC} Adding the key-based automation connector..."
  # A second connector, kept apart from the plugin's own OAuth connector. The
  # skills reference tools by name, so they work over either. The key is held
  # by Claude Code's own MCP config for this user — treat it like a password
  # and rotate it from Tara (My MCP setup → Regenerate key) if it may have leaked.
  claude mcp remove adup-automation --scope user 2>/dev/null || true
  claude mcp add --transport http --scope user adup-automation https://gateway.adup.io/mcp \
    --header "Authorization: Bearer ${AUTOMATION_KEY}"
  echo -e "  ${GREEN}✓${NC} Connector 'adup-automation' added (key ending …${AUTOMATION_KEY: -4})"
  echo ""
  echo "  The plugin's own 'adup' connector will keep offering to authenticate on this"
  echo "  machine; that is expected — the automation connector serves the tools here."
  echo ""
  exit 0
fi

echo -e "${YELLOW}Step 2/2:${NC} Sign in from Claude"
echo ""
echo "  ┌──────────────────────────────────────────────────────────┐"
echo "  │  Run this once in a terminal:                            │"
echo "  │                                                          │"
echo "  │    claude mcp login plugin:adup:adup                     │"
echo "  │                                                          │"
echo "  │  Your browser opens Tara: sign in and click Approve.     │"
echo "  │  (In a Claude Code session: /mcp → adup → Authenticate.) │"
echo "  │                                                          │"
echo "  │  Then, in Claude Code or Cowork:                         │"
echo "  │                                                          │"
echo "  │    /adup:connect                                         │"
echo "  │                                                          │"
echo "  │  to verify the connection.                               │"
echo "  └──────────────────────────────────────────────────────────┘"
echo ""
