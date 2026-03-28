#!/usr/bin/env python3
"""
Middleware decorators for tool tracking and performance monitoring
"""

import asyncio
import inspect
import time
from functools import wraps

from core.logger import logger


def track_tool_latency(func):
    """
    Decorator to track tool execution latency

    Logs completion time in milliseconds to the configured logger
    """
    async def async_wrapper(*args, **kwargs):
        start_time = time.perf_counter()
        func_name = func.__name__

        try:
            result = await func(*args, **kwargs)
            elapsed_ms = (time.perf_counter() - start_time) * 1000
            logger.debug(f"[TOOL] {func_name} completed in {elapsed_ms:.1f}ms")
            return result
        except Exception as e:
            elapsed_ms = (time.perf_counter() - start_time) * 1000
            logger.error(f"[TOOL] {func_name} failed after {elapsed_ms:.1f}ms: {e}")
            raise

    def sync_wrapper(*args, **kwargs):
        start_time = time.perf_counter()
        func_name = func.__name__

        try:
            result = func(*args, **kwargs)
            elapsed_ms = (time.perf_counter() - start_time) * 1000
            logger.debug(f"[TOOL] {func_name} completed in {elapsed_ms:.1f}ms")
            return result
        except Exception as e:
            elapsed_ms = (time.perf_counter() - start_time) * 1000
            logger.error(f"[TOOL] {func_name} failed after {elapsed_ms:.1f}ms: {e}")
            raise

    if inspect.iscoroutinefunction(func):
        return async_wrapper
    else:
        return sync_wrapper


async def run_in_executor(func, *args, **kwargs):
    """
    Run a blocking sync function in an executor

    Use this for file I/O or system calls that would block the event loop

    Args:
        func: The blocking function to run
        *args: Positional args for the function
        **kwargs: Keyword args for the function

    Returns:
        Function result
    """
    loop = asyncio.get_event_loop()
    return await loop.run_in_executor(None, func, *args, **kwargs)
