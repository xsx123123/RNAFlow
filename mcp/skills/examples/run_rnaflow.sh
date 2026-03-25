#!/bin/bash
# RNAFlow Execution Script (Simplified Example)
# Usage: ./run_rnaflow.sh /path/to/config.yaml
# 
# For full conda environment checking and user confirmation,
# use ../start_rnaflow.sh instead!

set -e

# Check if config file is provided
if [ $# -eq 0 ]; then
    echo "Usage: $0 <path_to_config.yaml>"
    echo ""
    echo "NOTE: For conda environment checking and user confirmation,"
    echo "      please use the enhanced script: ../start_rnaflow.sh"
    exit 1
fi

CONFIG_FILE="$1"

# Check if config file exists
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: Config file not found: $CONFIG_FILE"
    exit 1
fi

# Try to load RNAFLOW_DIR from path_config.yaml if available
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PATH_CONFIG="${SCRIPT_DIR}/../path_config.yaml"

# Default value
RNAFLOW_DIR="/path/to/RNAFlow"

# Try to parse from path_config.yaml
if [ -f "$PATH_CONFIG" ]; then
    RNAFLOW_DIR=$(grep '^RNAFLOW_ROOT:' "$PATH_CONFIG" | cut -d' ' -f2 | tr -d '"')
fi

# Check if RNAFlow directory exists
if [ ! -d "$RNAFLOW_DIR" ]; then
    echo "Error: RNAFlow directory not found: $RNAFLOW_DIR"
    echo "Please update RNAFLOW_DIR in this script or set it in path_config.yaml"
    exit 1
fi

cd "$RNAFLOW_DIR"

echo "=========================================="
echo "RNAFlow Analysis Pipeline (Simplified)"
echo "=========================================="
echo "Config file: $CONFIG_FILE"
echo "RNAFlow directory: $RNAFLOW_DIR"
echo ""
echo "TIP: For conda environment checks, use ../start_rnaflow.sh"
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
    --cores=40 \
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
