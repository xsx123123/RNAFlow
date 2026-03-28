#!/usr/bin/env python3
"""
Services package for RNAFlow MCP

Modules:
- project_mgr: Project management services
- snakemake: Snakemake execution services
- system: System checks and resource monitoring
"""

from . import project_mgr
from . import snakemake
from . import system

# Project management exports
from .project_mgr import (
    list_supported_genomes,
    get_config_template,
    create_project_structure,
    generate_config_file,
    create_sample_csv,
    create_contrasts_csv,
    validate_config,
    get_project_structure,
    setup_complete_project,
    run_simple_qc_analysis,
)

# Snakemake exports
from .snakemake import run_rnaflow

# System exports
from .system import (
    check_conda_environment,
    check_system_resources,
    list_runs,
    get_run_details,
    get_run_statistics,
    check_project_name_conflict,
    check_snakemake_status,
    get_snakemake_log,
)
