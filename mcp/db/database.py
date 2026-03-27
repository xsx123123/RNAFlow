#!/usr/bin/env python3
"""
Database connection and initialization module for RNAFlow MCP
"""

import sqlite3
from pathlib import Path

from core.logger import logger


def init_database():
    """Initialize SQLite database, create project run records table"""
    db_dir = Path(__file__).parent.parent / "data"
    db_dir.mkdir(parents=True, exist_ok=True)
    db_path = db_dir / "rnaflow_runs.db"

    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()

    # Create project run records table
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS runs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            run_id TEXT UNIQUE NOT NULL,
            project_name TEXT NOT NULL,
            genome_version TEXT,
            species TEXT,
            config_path TEXT NOT NULL,
            config_json TEXT,
            cores INTEGER,
            start_time TEXT NOT NULL,
            end_time TEXT,
            status TEXT DEFAULT 'running',
            log_file TEXT,
            pid INTEGER,
            created_at TEXT DEFAULT CURRENT_TIMESTAMP
        )
    """)

    # Create indexes
    cursor.execute("CREATE INDEX IF NOT EXISTS idx_run_id ON runs(run_id)")
    cursor.execute("CREATE INDEX IF NOT EXISTS idx_project_name ON runs(project_name)")
    cursor.execute("CREATE INDEX IF NOT EXISTS idx_status ON runs(status)")
    cursor.execute("CREATE INDEX IF NOT EXISTS idx_start_time ON runs(start_time)")

    conn.commit()
    conn.close()

    logger.info(f"数据库已初始化: {db_path}")
    return db_path


def get_db_connection():
    """Get database connection"""
    db_path = Path(__file__).parent.parent / "data" / "rnaflow_runs.db"
    return sqlite3.connect(db_path)
