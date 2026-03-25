#!/usr/bin/env python3
"""
Configuration module for RNAFlow MCP
"""

import os
import sys
import yaml
from pathlib import Path


# Add the parent directory to path to access RNAFlow
sys.path.insert(0, str(Path(__file__).parent.parent.parent))

# Path definitions
RNAFLOW_ROOT = Path(__file__).parent.parent.parent
SKILLS_DIR = RNAFLOW_ROOT / "skills"
CONFIG_DIR = RNAFLOW_ROOT / "config"
EXAMPLES_DIR = Path(__file__).parent.parent / "skills" / "examples"
MCP_CONFIG_FILE = Path(__file__).parent.parent / "mcp_config.yaml"


def load_mcp_config():
    """Load local MCP configuration for tool paths"""
    config = {
        "conda_path": "conda",
        "snakemake_path": "snakemake",
        "default_env": "rnaflow",
    }
    if MCP_CONFIG_FILE.exists():
        try:
            with open(MCP_CONFIG_FILE, "r") as f:
                user_config = yaml.safe_load(f)
                if user_config:
                    config.update(user_config)
        except Exception:
            pass
    return config


MCP_PATHS = load_mcp_config()
