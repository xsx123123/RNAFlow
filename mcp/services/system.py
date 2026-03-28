#!/usr/bin/env python3
"""
System services for RNAFlow MCP - environment checks, resource monitoring
"""

import subprocess
import shutil
from pathlib import Path
from typing import Optional, Dict, Any, List

from core.logger import logger
from core.config import MCP_PATHS, CONFIG_DIR
from db.crud import get_run_info, get_run_summary, update_run_status_in_db

try:
    import psutil

    PSUTIL_AVAILABLE = True
except ImportError:
    PSUTIL_AVAILABLE = False


def check_conda_environment(env_name: Optional[str] = None) -> Dict[str, Any]:
    """Check if required conda environment exists and is valid"""
    logger.info("=== 调用工具: check_conda_environment ===")
    env_name = env_name or MCP_PATHS.get("default_env", "rnaflow")
    conda_bin = MCP_PATHS.get("conda_path", "conda")
    logger.info(f"检查环境: {env_name}")
    logger.info(f"Conda 路径: {conda_bin}")

    try:
        result = subprocess.run(
            [conda_bin, "--version"], capture_output=True, text=True
        )
        if result.returncode != 0:
            return {
                "available": False,
                "error": f"Conda not found at '{conda_bin}'.",
            }

        result = subprocess.run(
            [conda_bin, "env", "list"], capture_output=True, text=True
        )
        env_exists = env_name in result.stdout

        snakemake_available = False
        if env_exists:
            try:
                result = subprocess.run(
                    [conda_bin, "run", "-n", env_name, "snakemake", "--version"],
                    capture_output=True,
                    text=True,
                    timeout=15,  # Increased timeout for robustness
                )
                snakemake_available = result.returncode == 0
            except subprocess.TimeoutExpired:
                logger.warning(f"Snakemake version check timed out for env: {env_name}")
                snakemake_available = False
            except Exception:
                snakemake_available = False

        result_data = {
            "available": env_exists,
            "env_name": env_name,
            "snakemake_available": snakemake_available,
            "conda_version": result.stdout.strip().split("\n")[0]
            if result.stdout
            else "unknown",
            "message": "Success"
            if env_exists
            else f"Environment '{env_name}' not found.",
        }
        logger.info(
            f"环境检查结果: available={env_exists}, snakemake_available={snakemake_available}"
        )
        logger.info("=== 工具完成: check_conda_environment ===")
        return result_data
    except FileNotFoundError:
        error_msg = f"Conda executable '{conda_bin}' not found."
        logger.error(error_msg)
        return {"available": False, "error": error_msg}
    except Exception as e:
        logger.error(f"Conda环境检查失败: {str(e)}", exc_info=True)
        return {"available": False, "error": str(e)}


def check_system_resources() -> Dict[str, Any]:
    """Check system resources including CPU, memory, and disk usage"""
    logger.info("=== 调用工具: check_system_resources ===")
    resources = {
        "status": "healthy",
        "warnings": [],
        "cpu": {},
        "memory": {},
        "disk": {},
    }

    if PSUTIL_AVAILABLE:
        try:
            cpu_count = psutil.cpu_count(logical=True)
            cpu_percent = psutil.cpu_percent(interval=0.5)
            resources["cpu"] = {
                "total_cores": cpu_count,
                "usage_percent": cpu_percent,
                "available_cores": max(
                    1, cpu_count - int(cpu_count * cpu_percent / 100)
                ),
            }
            if cpu_percent > 80:
                resources["warnings"].append(f"高CPU使用率: {cpu_percent}%")
                resources["status"] = "warning"
        except Exception as e:
            resources["cpu"] = {"error": str(e)}
    else:
        resources["cpu"] = {"warning": "psutil not available"}

    if PSUTIL_AVAILABLE:
        try:
            mem = psutil.virtual_memory()
            resources["memory"] = {
                "total_gb": round(mem.total / (1024**3), 2),
                "available_gb": round(mem.available / (1024**3), 2),
                "used_percent": mem.percent,
            }
            if mem.percent > 85:
                resources["warnings"].append(f"内存使用率过高: {mem.percent}%")
                resources["status"] = "warning"
            if mem.available < 4 * 1024**3:
                resources["warnings"].append("可用内存不足4GB")
                resources["status"] = "warning"
        except Exception as e:
            resources["memory"] = {"error": str(e)}
    else:
        resources["memory"] = {"warning": "psutil not available"}

    try:
        disk_usage = shutil.disk_usage("/")
        resources["disk"]["root"] = {
            "total_gb": round(disk_usage.total / (1024**3), 2),
            "used_gb": round(disk_usage.used / (1024**3), 2),
            "free_gb": round(disk_usage.free / (1024**3), 2),
            "used_percent": round((disk_usage.used / disk_usage.total) * 100, 1),
        }
        if disk_usage.free < 50 * 1024**3:
            resources["warnings"].append("根目录磁盘空间不足50GB")
            resources["status"] = "warning"
    except Exception as e:
        resources["disk"]["error"] = str(e)
        logger.error(f"磁盘检查失败: {str(e)}")

    logger.info(f"系统资源状态: {resources['status']}")
    logger.info("=== 工具完成: check_system_resources ===")
    return resources


def list_runs(
    project_name: str = None, status: str = None, limit: int = 50
) -> List[Dict[str, Any]]:
    """List RNAFlow project run records"""
    logger.info("=== 调用工具: list_runs ===")
    try:
        runs = get_run_info(project_name=project_name, status=status, limit=limit)
        logger.info(f"查询到 {len(runs)} 条运行记录")
        logger.info("=== 工具完成: list_runs ===")
        return runs
    except Exception as e:
        logger.error(f"查询运行记录失败: {str(e)}", exc_info=True)
        return [{"error": str(e)}]


def get_run_details(run_id: str) -> Dict[str, Any]:
    """Get details for a specific run"""
    logger.info("=== 调用工具: get_run_details ===")
    logger.info(f"查询运行ID: {run_id}")
    try:
        runs = get_run_info(run_id=run_id, limit=1)
        if runs:
            logger.info(f"找到运行记录: {run_id}")
            logger.info("=== 工具完成: get_run_details ===")
            return runs[0]
        else:
            logger.warning(f"未找到运行记录: {run_id}")
            logger.info("=== 工具完成: get_run_details ===")
            return {"error": f"Run ID '{run_id}' not found"}
    except Exception as e:
        logger.error(f"获取运行详情失败: {str(e)}", exc_info=True)
        return {"error": str(e)}


def get_run_statistics(start_date: str = None, end_date: str = None) -> Dict[str, Any]:
    """Get run statistics for a period"""
    logger.info("=== 调用工具: get_run_statistics ===")
    try:
        stats = get_run_summary(start_date=start_date, end_date=end_date)
        logger.info(f"统计结果: {stats}")
        logger.info("=== 工具完成: get_run_statistics ===")
        return stats
    except Exception as e:
        logger.error(f"获取统计信息失败: {str(e)}", exc_info=True)
        return {"error": str(e)}


def check_project_name_conflict(project_name: str) -> Dict[str, Any]:
    """Check if project name already exists"""
    logger.info("=== 调用工具: check_project_name_conflict ===")
    logger.info(f"检查项目名称: {project_name}")
    try:
        existing_runs = get_run_info(project_name=project_name, limit=100)
        result = {
            "project_name": project_name,
            "has_conflict": len(existing_runs) > 0,
            "existing_runs_count": len(existing_runs),
            "existing_runs": existing_runs[:5],
        }
        logger.info("=== 工具完成: check_project_name_conflict ===")
        return result
    except Exception as e:
        logger.error(f"检查项目名称冲突失败: {str(e)}", exc_info=True)
        return {"error": str(e)}


def check_snakemake_status(run_id: str = None) -> Dict[str, Any]:
    """Check Snakemake run status"""
    logger.info("=== 调用工具: check_snakemake_status ===")
    logger.info(f"检查运行ID: {run_id}")
    try:
        if run_id:
            runs = get_run_info(run_id=run_id, limit=1)
        else:
            runs = get_run_info(status="running", limit=100)

        if not runs:
            return {
                "message": "没有找到运行中的任务"
                if not run_id
                else f"未找到运行ID: {run_id}"
            }

        results = []
        for run in runs:
            pid = run.get("pid")
            log_file = run.get("log_file")
            current_run_id = run.get("run_id")
            status_info = {
                "run_id": current_run_id,
                "project_name": run.get("project_name"),
                "pid": pid,
                "log_file": log_file,
                "process_status": "unknown",
                "recent_logs": [],
            }

            if pid and PSUTIL_AVAILABLE:
                try:
                    if psutil.pid_exists(pid):
                        process = psutil.Process(pid)
                        if process.is_running():
                            status_info["process_status"] = "running"
                        else:
                            status_info["process_status"] = "exited"
                            update_run_status_in_db(current_run_id, "completed")
                    else:
                        status_info["process_status"] = "not_found"
                        update_run_status_in_db(current_run_id, "failed")
                except Exception as e:
                    status_info["process_status"] = f"error: {str(e)}"

            if log_file and Path(log_file).exists():
                try:
                    with open(log_file, "r", encoding="utf-8") as f:
                        lines = f.readlines()
                        status_info["recent_logs"] = [
                            line.rstrip() for line in lines[-20:]
                        ]
                except Exception as e:
                    status_info["recent_logs"] = [f"无法读取日志: {str(e)}"]

            results.append(status_info)

        logger.info(f"检查了 {len(results)} 个任务的状态")
        logger.info("=== 工具完成: check_snakemake_status ===")
        return {"checked_runs": results}
    except Exception as e:
        logger.error(f"检查Snakemake状态失败: {str(e)}", exc_info=True)
        return {"error": str(e)}


def get_snakemake_log(run_id: str, lines: int = 50) -> Dict[str, Any]:
    """Get Snakemake run log"""
    logger.info("=== 调用工具: get_snakemake_log ===")
    logger.info(f"运行ID: {run_id}, 获取行数: {lines}")
    try:
        runs = get_run_info(run_id=run_id, limit=1)
        if not runs:
            return {"error": f"未找到运行ID: {run_id}"}

        log_file = runs[0].get("log_file")
        if not log_file:
            return {"error": "该运行没有记录日志文件路径"}

        log_path = Path(log_file)
        if not log_path.exists():
            return {"error": f"日志文件不存在: {log_file}"}

        with open(log_path, "r", encoding="utf-8") as f:
            all_lines = f.readlines()
            recent_lines = all_lines[-lines:] if len(all_lines) > lines else all_lines

        logger.info(f"成功读取日志文件: {log_file}")
        logger.info("=== 工具完成: get_snakemake_log ===")
        return {
            "run_id": run_id,
            "log_file": log_file,
            "total_lines": len(all_lines),
            "returned_lines": len(recent_lines),
            "logs": [line.rstrip() for line in recent_lines],
        }
    except Exception as e:
        logger.error(f"获取Snakemake日志失败: {str(e)}", exc_info=True)
        return {"error": str(e)}
