#!/usr/bin/env bash
# remote-install.sh — One-liner installer for Claude Code Skills
# Usage: curl -fsSL https://raw.githubusercontent.com/USER/claude-code-skills/main/remote-install.sh | bash

set -euo pipefail

# Configuration
REPO_URL="${CLAUDE_SKILLS_REPO:-https://github.com/USER/claude-code-skills.git}"
INSTALL_DIR="${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}Claude Code Skills Installer${NC}"
echo "════════════════════════════════════════════════════"
echo ""

# Check dependencies
if ! command -v git &> /dev/null; then
    echo -e "${RED}Error:${NC} git is required but not installed."
    exit 1
fi

if ! command -v python3 &> /dev/null; then
    echo -e "${RED}Error:${NC} python3 is required but not installed."
    exit 1
fi

# Check if already installed
if [ -d "$INSTALL_DIR" ]; then
    echo -e "${YELLOW}Skills already installed at:${NC} $INSTALL_DIR"
    echo ""
    echo "To update:"
    echo "  cd $INSTALL_DIR && bash install.sh --update"
    echo ""
    echo "To reinstall (removes existing):"
    echo "  rm -rf $INSTALL_DIR && curl -fsSL <this-url> | bash"
    exit 1
fi

# Clone repository
echo -e "Cloning to ${BLUE}$INSTALL_DIR${NC}..."
git clone --depth 1 "$REPO_URL" "$INSTALL_DIR"

# Run installer
echo ""
bash "$INSTALL_DIR/install.sh"

echo ""
echo "════════════════════════════════════════════════════"
echo -e "${GREEN}Installation complete!${NC}"
echo ""
echo "Skills are now active in all new Claude Code sessions."
echo ""
echo "Commands:"
echo "  bash $INSTALL_DIR/install.sh --status       # Show installed skills"
echo "  bash $INSTALL_DIR/install.sh --update       # Update to latest"
echo "  bash $INSTALL_DIR/install.sh --uninstall    # Remove all skills"
echo "  bash $INSTALL_DIR/install.sh --init-project # Add project templates"
