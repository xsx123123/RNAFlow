#!/usr/bin/env python3
"""
Core package for RNAFlow MCP

Exports:
- logger: Configured logger instance
- config: Configuration utilities
- session: Database session management (lazy)
- middleware: Tool tracking and async helpers
- legacy_dispatcher: Legacy tool name routing
"""

from . import config
from . import logger
from . import middleware
from . import legacy_dispatcher

from .config import *
from .logger import logger, current_log_file
from .middleware import track_tool_latency, run_in_executor
from .legacy_dispatcher import LEGACY_MAP, legacy_dispatcher
