#!/bin/bash
# Script to run RNAFlow with the new logger plugin

echo "Running RNAFlow with the new logger plugin..."

# Install the logger plugin if not already installed
echo "Checking if logger plugin is installed..."
if python3 -c "import logger_plugin" &> /dev/null; then
    echo "Logger plugin is already available."
else
    echo "Installing logger plugin..."
    cd src/logger_plugin
    pip install -e .
    cd ../..
fi

# Run RNAFlow with the logger plugin
echo "Starting RNAFlow pipeline with logger plugin..."
snakemake --logger-plugin rnaflow --dry-run --cores 1

echo ""
echo "Check the logs/ directory for detailed runtime information."
echo "Logs are saved with names like: RNAFlow_[PROJECT_NAME]_runtime_[TIMESTAMP].log"