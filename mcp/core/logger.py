#!/usr/bin/env python3
"""
Logging configuration module for RNAFlow MCP
"""

import logging
from datetime import datetime
from pathlib import Path


def setup_logging():
    """Configure logging system, output to logs/mcp/ directory"""
    log_dir = Path(__file__).parent.parent / "logs" / "mcp"
    log_dir.mkdir(parents=True, exist_ok=True)

    # Generate timestamped log filename
    log_filename = datetime.now().strftime("mcp_server_%Y%m%d_%H%M%S.log")
    log_file = log_dir / log_filename

    # Configure log format
    log_format = logging.Formatter(
        "%(asctime)s - %(name)s - %(levelname)s - %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S",
    )

    # File handler
    file_handler = logging.FileHandler(log_file, encoding="utf-8")
    file_handler.setFormatter(log_format)
    file_handler.setLevel(logging.DEBUG)

    # Console handler
    console_handler = logging.StreamHandler()
    console_handler.setFormatter(log_format)
    console_handler.setLevel(logging.INFO)

    # Get logger
    logger = logging.getLogger("RNAFlowMCP")
    logger.setLevel(logging.DEBUG)
    logger.addHandler(file_handler)
    logger.addHandler(console_handler)

    # Also set logging for third-party libraries
    logging.getLogger("fastmcp").setLevel(logging.INFO)

    logger.info(f"=== RNAFlow MCP Server 启动 ===")
    logger.info(f"日志文件: {log_file}")

    return logger, log_file


# Initialize logging system
logger, current_log_file = setup_logging()
