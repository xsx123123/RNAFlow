#!/bin/bash
# RNAFlow Skills Installer for Codex
# Installs RNAFlow skills to .codex/skills directory

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RNAFLOW_SKILLS_DIR="$SCRIPT_DIR"

# Codex skills directory
CODEX_SKILLS_DIR="$HOME/.codex/skills"
TARGET_DIR="$CODEX_SKILLS_DIR/RNAFlow"

echo "=========================================="
echo "RNAFlow Skills Installer for Codex"
echo "=========================================="
echo "Source: $RNAFLOW_SKILLS_DIR"
echo "Target: $TARGET_DIR"
echo ""

# Check if .codex directory exists
if [ ! -d "$CODEX_SKILLS_DIR" ]; then
    echo "Error: Codex skills directory not found: $CODEX_SKILLS_DIR"
    echo "Please make sure Codex is installed and initialized."
    exit 1
fi

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

# Update paths in path_config.yaml
echo "Updating paths in path_config.yaml..."
RNAFLOW_PROJECT_ROOT=$(cd "$RNAFLOW_SKILLS_DIR/.." && pwd)
# Use a different delimiter for sed since paths contain slashes
sed -i "s|/home/zj/pipeline/RNAFlow|$RNAFLOW_PROJECT_ROOT|g" "$TARGET_DIR/path_config.yaml"

echo ""
echo "=========================================="
echo "Installation Complete!"
echo "=========================================="
echo ""
echo "RNAFlow skills have been installed to:"
echo "  $TARGET_DIR"
echo ""
echo "What's included:"
echo "  - SKILL.md: Main skill definition"
echo "  - path_config.yaml: Path configuration"
echo "  - start_rnaflow.sh: Enhanced startup script"
echo "  - examples/: Configuration templates"
echo ""
echo "Next steps:"
echo "1. Restart Codex to load the new skill"
echo "2. Edit $TARGET_DIR/path_config.yaml if needed"
echo "3. Try: 'Run RNAFlow analysis on my data'"
