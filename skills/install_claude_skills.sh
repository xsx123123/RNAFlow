#!/bin/bash
# RNAFlow Skills Installer for Claude Code
# Thin wrapper around the generic installer

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Ensure Claude Code skills directory exists
if [ ! -d "$HOME/.claude/skills" ]; then
    echo "Creating Claude skills directory: $HOME/.claude/skills"
    mkdir -p "$HOME/.claude/skills"
fi

# Pre-set target directory and delegate to generic installer
export TARGET_DIR="$HOME/.claude/skills/RNAFlow"
echo "Installing RNAFlow skills for Claude Code..."
exec "$SCRIPT_DIR/install_skills.sh"
