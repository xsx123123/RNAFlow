#!/usr/bin/env python3
"""
Database CRUD operations for RNAFlow MCP
"""

import json
import sqlite3
from datetime import datetime
from typing import Optional, List, Dict, Any

from core.logger import logger
from db.database import get_db_connection


def record_run_start(
    run_id: str,
    project_name: str,
    config_path: str,
    config_dict: Dict,
    cores: int,
    log_file: str,
    pid: int = None,
):
    """Record project run start"""
    try:
        conn = get_db_connection()
        cursor = conn.cursor()

        # Read key information from config.yaml
        genome_version = config_dict.get(
            "Genome_Version", config_dict.get("genome_version", "")
        )
        species = config_dict.get("species", "")

        cursor.execute(
            """
            INSERT INTO runs 
            (run_id, project_name, genome_version, species, config_path, 
             config_json, cores, start_time, status, log_file, pid)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
            (
                run_id,
                project_name,
                genome_version,
                species,
                config_path,
                json.dumps(config_dict, ensure_ascii=False),
                cores,
                datetime.now().isoformat(),
                "running",
                log_file,
                pid,
            ),
        )

        conn.commit()
        conn.close()
        logger.info(f"已记录运行开始: run_id={run_id}, project={project_name}")
        return True
    except sqlite3.IntegrityError:
        logger.warning(f"运行ID冲突: {run_id}")
        return False
    except Exception as e:
        logger.error(f"记录运行开始失败: {str(e)}", exc_info=True)
        return False


def check_run_id_conflict(run_id: str) -> bool:
    """Check if run ID already exists"""
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("SELECT id FROM runs WHERE run_id = ?", (run_id,))
    exists = cursor.fetchone() is not None
    conn.close()
    return exists


def get_run_info(
    run_id: str = None, project_name: str = None, status: str = None, limit: int = 50
) -> List[Dict]:
    """Query run information

    Args:
        run_id: Query by run ID
        project_name: Query by project name
        status: Query by status (running, completed, failed)
        limit: Limit number of results returned
    """
    conn = get_db_connection()
    conn.row_factory = sqlite3.Row
    cursor = conn.cursor()

    query = "SELECT * FROM runs WHERE 1=1"
    params = []

    if run_id:
        query += " AND run_id = ?"
        params.append(run_id)
    if project_name:
        query += " AND project_name LIKE ?"
        params.append(f"%{project_name}%")
    if status:
        query += " AND status = ?"
        params.append(status)

    query += " ORDER BY start_time DESC LIMIT ?"
    params.append(limit)

    cursor.execute(query, params)
    rows = cursor.fetchall()

    results = []
    for row in rows:
        result = dict(row)
        if result.get("config_json"):
            try:
                result["config"] = json.loads(result["config_json"])
            except:
                result["config"] = None
        del result["config_json"]
        results.append(result)

    conn.close()
    return results


def get_run_summary(start_date: str = None, end_date: str = None) -> Dict:
    """Get run statistics for a period of time

    Args:
        start_date: Start date (YYYY-MM-DD)
        end_date: End date (YYYY-MM-DD)
    """
    conn = get_db_connection()
    cursor = conn.cursor()

    query = "SELECT status, COUNT(*) as count FROM runs WHERE 1=1"
    params = []

    if start_date:
        query += " AND date(start_time) >= ?"
        params.append(start_date)
    if end_date:
        query += " AND date(start_time) <= ?"
        params.append(end_date)

    query += " GROUP BY status"
    cursor.execute(query, params)
    rows = cursor.fetchall()

    summary = {"total_runs": 0, "by_status": {}}

    for status, count in rows:
        summary["by_status"][status] = count
        summary["total_runs"] += count

    # Get total number of projects
    cursor.execute("SELECT COUNT(DISTINCT project_name) FROM runs")
    summary["unique_projects"] = cursor.fetchone()[0]

    conn.close()
    return summary


def update_run_status_in_db(run_id: str, status: str, end_time: str = None):
    """Update run status in database"""
    try:
        conn = get_db_connection()
        cursor = conn.cursor()

        if end_time:
            cursor.execute(
                "UPDATE runs SET status = ?, end_time = ? WHERE run_id = ?",
                (status, end_time, run_id),
            )
        else:
            cursor.execute(
                "UPDATE runs SET status = ? WHERE run_id = ?", (status, run_id)
            )

        conn.commit()
        conn.close()
        logger.info(f"已更新运行状态: run_id={run_id}, status={status}")
        return True
    except Exception as e:
        logger.error(f"更新运行状态失败: {str(e)}", exc_info=True)
        return False
