#!/usr/bin/env python3
"""
Lazy database session management - initialize database on first access
"""

from pathlib import Path

_db_path = None


def get_db_path() -> Path:
    """
    Get database path with lazy initialization

    Returns:
        Path to the database file
    """
    global _db_path
    if _db_path is None:
        from db.database import init_database
        _db_path = init_database()
    return _db_path


def get_db_connection():
    """
    Get database connection using lazy-initialized path

    Returns:
        SQLite connection object
    """
    import sqlite3
    return sqlite3.connect(get_db_path())
