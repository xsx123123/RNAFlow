#!/usr/bin/env python3
"""
Unified response format module for RNAFlow MCP tools
"""

from typing import Any, Dict


def success_response(data: Any = None, message: str = "") -> Dict[str, Any]:
    """
    Create a standardized success response

    Args:        data: Response data payload
        message: Optional success message

    Returns:        Standardized response dict with status="success"
    """
    response = {"status": "success"}
    if message:
        response["message"] = message
    if data is not None:
        response["data"] = data
    return response


def error_response(message: str, details: str = "") -> Dict[str, Any]:
    """
    Create a standardized error response

    Args:
        message: Error message
        details: Optional error details

    Returns:
        Standardized response dict with status="error"
    """
    response = {"status": "error", "message": message}
    if details:
        response["details"] = details
    return response
