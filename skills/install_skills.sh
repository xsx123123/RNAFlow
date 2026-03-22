#!/bin/bash
# RNAFlow Skills Installer
# Installs RNAFlow skills to opencode/AI agent skills directory

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RNAFLOW_SKILLS_DIR="$SCRIPT_DIR"

# Determine target directory - check standard locations
TARGET_DIR=""
SKILLS_TYPE=""

# Priority 1: .claude/skills (Claude Code)
if [ -d "$HOME/.claude/skills" ]; then
    TARGET_DIR="$HOME/.claude/skills/RNAFlow"
    SKILLS_TYPE="Claude Code"
    echo "Found Claude Code skills directory"
fi

# Priority 2: .codex/skills (Codex)
if [ -z "$TARGET_DIR" ] && [ -d "$HOME/.codex/skills" ]; then
    TARGET_DIR="$HOME/.codex/skills/RNAFlow"
    SKILLS_TYPE="Codex"
    echo "Found Codex skills directory"
fi

# Priority 3: .config/opencode/skills (OpenCode)
if [ -z "$TARGET_DIR" ] && [ -d "$HOME/.config/opencode" ]; then
    TARGET_DIR="$HOME/.config/opencode/skills/RNAFlow"
    SKILLS_TYPE="OpenCode"
    echo "Found OpenCode config directory"
fi

# If no standard directory found, ask user
if [ -z "$TARGET_DIR" ]; then
    echo "Could not find standard skills directory."
    echo "Available options:"
    echo "  1. Claude Code: $HOME/.claude/skills"
    echo "  2. Codex: $HOME/.codex/skills"
    echo "  3. Custom directory"
    echo ""
    read -p "Please select (1-3): " CHOICE
    
    case $CHOICE in
        1)
            if [ ! -d "$HOME/.claude/skills" ]; then
                mkdir -p "$HOME/.claude/skills"
            fi
            TARGET_DIR="$HOME/.claude/skills/RNAFlow"
            SKILLS_TYPE="Claude Code"
            ;;
        2)
            if [ ! -d "$HOME/.codex/skills" ]; then
                mkdir -p "$HOME/.codex/skills"
            fi
            TARGET_DIR="$HOME/.codex/skills/RNAFlow"
            SKILLS_TYPE="Codex"
            ;;
        3)
            echo "Please enter the target directory for installing RNAFlow skills:"
            read -p "Target directory: " USER_TARGET
            if [ -z "$USER_TARGET" ]; then
                echo "Error: No target directory specified"
                exit 1
            fi
            TARGET_DIR="$USER_TARGET/RNAFlow"
            SKILLS_TYPE="Custom"
            ;;
        *)
            echo "Invalid choice"
            exit 1
            ;;
    esac
fi

echo "=========================================="
echo "RNAFlow Skills Installer"
echo "=========================================="
echo "Source: $RNAFLOW_SKILLS_DIR"
echo "Target: $TARGET_DIR"
echo ""

# Ask for confirmation
read -p "Do you want to proceed with installation? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Installation cancelled."
    exit 0
fi

# Create target directory
echo ""
echo "Creating target directory..."
mkdir -p "$TARGET_DIR"

# Copy files
echo "Copying skills files..."

# Essential skill files
cp "$RNAFLOW_SKILLS_DIR/SKILL.md" "$TARGET_DIR/"
cp "$RNAFLOW_SKILLS_DIR/path_config.yaml" "$TARGET_DIR/"
cp "$RNAFLOW_SKILLS_DIR/start_rnaflow.sh" "$TARGET_DIR/"

# Documentation
cp "$RNAFLOW_SKILLS_DIR/README.md" "$TARGET_DIR/"
cp "$RNAFLOW_SKILLS_DIR/usage-guide.md" "$TARGET_DIR/"

# Examples
mkdir -p "$TARGET_DIR/examples"
cp "$RNAFLOW_SKILLS_DIR/examples/"*.yaml "$TARGET_DIR/examples/" 2>/dev/null || true
cp "$RNAFLOW_SKILLS_DIR/examples/"*.csv "$TARGET_DIR/examples/" 2>/dev/null || true
cp "$RNAFLOW_SKILLS_DIR/examples/"*.sh "$TARGET_DIR/examples/" 2>/dev/null || true

# Make scripts executable
chmod +x "$TARGET_DIR/start_rnaflow.sh"
chmod +x "$TARGET_DIR/examples/run_rnaflow.sh" 2>/dev/null || true

echo ""
echo "=========================================="
echo "Installation Complete!"
echo "=========================================="
echo ""
echo "RNAFlow skills have been installed for $SKILLS_TYPE to:"
echo "  $TARGET_DIR"
echo ""
echo "What's included:"
echo "  - SKILL.md: Main skill definition"
echo "  - path_config.yaml: Path configuration"
echo "  - start_rnaflow.sh: Enhanced startup script"
echo "  - examples/: Configuration templates"
echo ""
echo "Next steps:"
echo "1. Restart $SKILLS_TYPE to load the new skill"
echo "2. Edit $TARGET_DIR/path_config.yaml if needed"
echo "3. Try: 'Run RNAFlow analysis on my data'"
