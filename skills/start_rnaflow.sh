#!/bin/bash
# RNAFlow Enhanced Execution Script with Conda Environment Check
# Usage: ./start_rnaflow.sh /path/to/config.yaml
# Version: 1.0

set -e

# ==================== Configuration ====================
# Load path config if available
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PATH_CONFIG="${SCRIPT_DIR}/path_config.yaml"

# Default values
RNAFLOW_ROOT="/home/zj/pipeline/RNAFlow"
DEFAULT_CONDA_ENV="rnaflow"
AUTO_ACTIVATE=false

# Load config from YAML if available
if [ -f "$PATH_CONFIG" ]; then
    echo "Loading configuration from $PATH_CONFIG"
    # Parse YAML (simple parsing, no external dependencies)
    RNAFLOW_ROOT=$(grep '^RNAFLOW_ROOT:' "$PATH_CONFIG" | cut -d' ' -f2 | tr -d '"')
    DEFAULT_CONDA_ENV=$(grep '^  DEFAULT_ENV_NAME:' "$PATH_CONFIG" | cut -d' ' -f4 | tr -d '"')
    AUTO_ACTIVATE=$(grep '^  AUTO_ACTIVATE:' "$PATH_CONFIG" | cut -d' ' -f4)
fi

# ==================== Usage Check ====================
if [ $# -eq 0 ]; then
    echo "Usage: $0 <path_to_config.yaml>"
    echo ""
    echo "This script will:"
    echo "1. Check if conda is installed"
    echo "2. Check if the RNAFlow conda environment exists"
    echo "3. Ask for user confirmation before activating environment"
    echo "4. Run RNAFlow analysis"
    exit 1
fi

CONFIG_FILE="$1"

# ==================== File Checks ====================
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: Config file not found: $CONFIG_FILE"
    exit 1
fi

if [ ! -d "$RNAFLOW_ROOT" ]; then
    echo "Error: RNAFlow directory not found: $RNAFLOW_ROOT"
    echo "Please update RNAFLOW_ROOT in this script or in path_config.yaml"
    exit 1
fi

# ==================== Conda Environment Setup ====================
echo "=========================================="
echo "RNAFlow Analysis Pipeline - Environment Check"
echo "=========================================="
echo ""

# Check 1: Is conda installed?
echo "[1/5] Checking if conda is installed..."
if ! command -v conda &> /dev/null; then
    echo "ERROR: conda is not installed!"
    echo ""
    echo "Please install conda first:"
    echo "  - Miniconda: https://docs.conda.io/en/latest/miniconda.html"
    echo "  - Anaconda: https://www.anaconda.com/download"
    exit 1
fi
CONDA_VERSION=$(conda --version)
echo "✓ conda found: $CONDA_VERSION"
echo ""

# Check 2: Does the conda environment exist?
echo "[2/5] Checking conda environment..."
ENV_EXISTS=false
if conda env list | grep -q "^${DEFAULT_CONDA_ENV} "; then
    ENV_EXISTS=true
    echo "✓ Conda environment '$DEFAULT_CONDA_ENV' found"
else
    echo "WARNING: Conda environment '$DEFAULT_CONDA_ENV' not found!"
    echo ""
    echo "You can either:"
    echo "1. Create the environment manually:"
    echo "   conda create -n $DEFAULT_CONDA_ENV -c conda-forge -c bioconda snakemake mamba"
    echo ""
    echo "2. Use a different existing environment"
    echo ""
    read -p "Do you want to continue with a different environment name? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Exiting. Please create the conda environment first."
        exit 1
    fi
    read -p "Enter conda environment name: " USER_ENV_NAME
    DEFAULT_CONDA_ENV="$USER_ENV_NAME"
    
    # Check again
    if ! conda env list | grep -q "^${DEFAULT_CONDA_ENV} "; then
        echo "ERROR: Environment '$DEFAULT_CONDA_ENV' also not found!"
        exit 1
    fi
fi
echo ""

# Check 3: Verify snakemake is available in the environment
echo "[3/5] Checking Snakemake in environment..."
# Temporarily activate to check
SNAKEMAKE_IN_ENV=$(conda run -n "$DEFAULT_CONDA_ENV" which snakemake 2>/dev/null || true)
if [ -z "$SNAKEMAKE_IN_ENV" ]; then
    echo "WARNING: Snakemake not found in environment '$DEFAULT_CONDA_ENV'"
    echo ""
    echo "You can install it with:"
    echo "  conda activate $DEFAULT_CONDA_ENV"
    echo "  conda install -c conda-forge -c bioconda snakemake mamba"
    echo ""
    read -p "Do you want to continue anyway? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
else
    SNAKEMAKE_VERSION=$(conda run -n "$DEFAULT_CONDA_ENV" snakemake --version 2>/dev/null)
    echo "✓ Snakemake found: v$SNAKEMAKE_VERSION"
fi
echo ""

# ==================== User Confirmation ====================
echo "[4/5] Environment Summary"
echo "=========================================="
echo "RNAFlow Root:      $RNAFLOW_ROOT"
echo "Config File:       $CONFIG_FILE"
echo "Conda Environment: $DEFAULT_CONDA_ENV"
echo "=========================================="
echo ""

# Ask for confirmation to activate environment
echo "[5/5] User Confirmation Required"
if [ "$AUTO_ACTIVATE" = "true" ]; then
    echo "Auto-activate is enabled in configuration"
    CONFIRM_ACTIVATE="y"
else
    read -p "Do you want to activate conda environment '$DEFAULT_CONDA_ENV' and proceed? (y/n) " -n 1 -r
    echo
    CONFIRM_ACTIVATE="$REPLY"
fi

if [[ ! $CONFIRM_ACTIVATE =~ ^[Yy]$ ]]; then
    echo "Analysis cancelled by user."
    exit 0
fi

# ==================== Start Analysis ====================
echo ""
echo "=========================================="
echo "Starting RNAFlow Analysis"
echo "=========================================="
echo ""

# Activate conda environment and run
cd "$RNAFLOW_ROOT"

# Source conda to make activate available
if [ -f "$HOME/miniconda3/etc/profile.d/conda.sh" ]; then
    source "$HOME/miniconda3/etc/profile.d/conda.sh"
elif [ -f "$HOME/anaconda3/etc/profile.d/conda.sh" ]; then
    source "$HOME/anaconda3/etc/profile.d/conda.sh"
else
    # Try to find conda.sh
    CONDA_BASE=$(conda info --base 2>/dev/null)
    if [ -n "$CONDA_BASE" ] && [ -f "$CONDA_BASE/etc/profile.d/conda.sh" ]; then
        source "$CONDA_BASE/etc/profile.d/conda.sh"
    fi
fi

# Activate environment
echo "Activating conda environment: $DEFAULT_CONDA_ENV"
conda activate "$DEFAULT_CONDA_ENV"

echo "Working directory: $(pwd)"
echo "Config file: $CONFIG_FILE"
echo ""

# Step 1: Dry Run
echo "Step 1: Performing dry run..."
snakemake -n --config analysisyaml="$CONFIG_FILE"
echo ""

# Ask user if they want to proceed
read -p "Dry run complete. Do you want to proceed with the full analysis? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Analysis cancelled by user."
    exit 0
fi

# Step 2: Full Analysis
echo ""
echo "Step 2: Running full analysis..."
echo "This may take several hours depending on data size."
echo ""

snakemake \
    --cores=60 \
    -p \
    --conda-frontend=mamba \
    --use-conda \
    --rerun-triggers mtime \
    --logger rich-loguru \
    --config analysisyaml="$CONFIG_FILE"

echo ""
echo "=========================================="
echo "Analysis complete!"
echo "=========================================="
echo "Check the data_deliver directory for results."
echo "Open Analysis_Report/index.html to view the interactive report."
