#!/usr/bin/env python3
"""
Database package for RNAFlow MCP

Exports:
- session: Lazy database session management
- database: Database initialization and connection
- crud: Database CRUD operations
"""

from . import session
from . import database
from . import crud

from .session import get_db_path, get_db_connection
from .database import init_database, get_db_connection as legacy_get_db_connection
from .crud import (
    record_run_start,
    check_run_id_conflict,
    get_run_info,
    get_run_summary,
    update_run_status_in_db,
)
