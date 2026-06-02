#!/bin/bash
# RNAFlow Skills Installer for Codex
# Thin wrapper around the generic installer

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Check if Codex directory exists
if [ ! -d "$HOME/.codex" ]; then
    echo "Error: Codex directory not found: $HOME/.codex"
    echo "Please make sure Codex is installed and initialized."
    exit 1
fi

# Ensure Codex skills directory exists
if [ ! -d "$HOME/.codex/skills" ]; then
    echo "Creating Codex skills directory: $HOME/.codex/skills"
    mkdir -p "$HOME/.codex/skills"
fi

# Pre-set target directory and delegate to generic installer
export TARGET_DIR="$HOME/.codex/skills/RNAFlow"
echo "Installing RNAFlow skills for Codex..."
exec "$SCRIPT_DIR/install_skills.sh"
