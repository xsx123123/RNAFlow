#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
from typing import Any, Iterable


PATH_KEYS = {
    "index",
    "genome_fa",
    "genome_gtf",
    "genome_gff",
    "rsem_index",
    "rsem_index_dir",
    "bed12",
    "go_annotation",
    "obo",
    "ref_all",
}


def _resolve_paths(value: Any, root_dir: str, key: str = "") -> Any:
    if isinstance(value, dict):
        return {name: _resolve_paths(item, root_dir, name) for name, item in value.items()}
    if isinstance(value, list):
        return [_resolve_paths(item, root_dir, key) for item in value]
    if key in PATH_KEYS and isinstance(value, str) and not os.path.isabs(value):
        return os.path.join(root_dir, value)
    return value


def resolve_reference_paths(config, index_keys: Iterable[str], base_path=None):
    """Resolve reference paths for the selected genome and shared databases.

    Only path-valued keys are rewritten. Metadata such as ``gene_col`` remains
    unchanged, and the input config is updated once during workflow startup.
    """
    root_dir = base_path or config.get("reference_path")
    if not root_dir:
        return

    genome_version = config.get("Genome_Version")
    for section_name in index_keys:
        section = config.get(section_name)
        if not isinstance(section, dict):
            continue

        selected = {}
        if genome_version in section and isinstance(section[genome_version], dict):
            selected[genome_version] = section[genome_version]
        if section_name == "STAR_index" and isinstance(section.get("GO"), dict):
            selected["GO"] = section["GO"]

        if selected:
            section.update(_resolve_paths(selected, root_dir))
