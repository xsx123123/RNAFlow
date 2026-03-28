#!/usr/bin/env python3
"""
Configuration module for RNAFlow MCP

Optimized with:
- Cached config loading with LRU cache
- Lazy config loading pattern
"""

import functools
import os
import sys
import yaml
from pathlib import Path


# Add parent directory to path to access RNAFlow
sys.path.insert(0, str(Path(__file__).parent.parent.parent))

# Path definitions
RNAFLOW_ROOT = Path(__file__).parent.parent.parent
SKILLS_DIR = RNAFLOW_ROOT / "skills"
CONFIG_DIR = RNAFLOW_ROOT / "config"
EXAMPLES_DIR = Path(__file__).parent.parent / "skills" / "examples"
MCP_CONFIG_FILE = Path(__file__).parent.parent / "mcp_config.yaml"


@functools.lru_cache(maxsize=1)
def load_mcp_config():
    """
    Load local MCP configuration for tool paths (cached)

    Uses LRU cache to avoid repeated file I/O.

    Returns:
        Dict with conda_path, snakemake_path, default_env, etc.
    """
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
        except Exception as e:
            # Import logger lazily to avoid circular dependency
            import logging
            logging.warning(f"Failed to加载 MCP config: {e}")
    return config


# Load config at module import time (cached)
MCP_PATHS = load_mcp_config()


def reload_config():
    """
    Force reload of MCP configuration

    Clears LRU cache and reloads from disk.
    Use this when configuration is updated at runtime.
    """
    load_mcp_config.cache_clear()
    return load_mcp_config()
