#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
RNAFlow Pipeline - Result Manifest Module (ARDP v1.0)

Implements the terminal-state result delivery manifest contract defined by the
OmicHub "Analysis Result Delivery Protocol" (ARDP):
    Protocol/分析流程结果交付协议_v1.md   (OmicHub repo)

Functions:
- build_success_manifest(): assemble the end-of-run success manifest dict
- build_failure_manifest(): minimal failed-run manifest for the onerror hook
- collect_delivered_files(): build files[] from the delivery layout (existence-checked)
- build_comparisons(): legacy {Control}_vs_{Treat} -> ARDP {Treat}_vs_{Control}
- write_manifest_atomic(): atomic write (tmp + fsync + os.replace, ARDP §3.2)

Design notes:
- All functions are pure / side-effect-light so they can be unit-tested standalone.
- config["platform"] is injected by the OmicHub platform and echoed back as-is;
  it is absent in standalone runs, which is legal (ARDP §4.2, FlowFrame §17).
- Comparison naming: the manifest follows FlowFrame §8.5 ({Treat}_vs_{Control});
  RNAFlow artifacts still use the legacy direction {Control}_vs_{Treat}
  (FlowFrame §15.3 alignment item), so files[].path respects the real file
  names while comparisons[].name uses the new convention.
"""

import datetime
import json
import os
from pathlib import Path
from typing import Dict, List, Optional

MANIFEST_VERSION = "1.0"
MANIFEST_KIND = "omichub.analysis.result"
MANIFEST_FILENAME = "result_manifest.json"

# RNAFlow module switch config key -> ARDP modules key (FlowFrame §5.1 registry
# vocabulary). "DEG" is RNAFlow's legacy upper-case key (FlowFrame §15.1 P0);
# the manifest normalizes it to lower-case.
_MODULE_KEY_MAP = [
    ("qc_clean", "qc_clean"),
    ("mapping", "mapping"),
    ("count", "count"),
    ("DEG", "deg"),
    ("call_variant", "call_variant"),
    ("detect_novel_transcripts", "detect_novel_transcripts"),
    ("rmats", "rmats"),
    ("gene_fusion", "gene_fusion"),
]


def _utc_now() -> datetime.datetime:
    return datetime.datetime.now(datetime.timezone.utc)


def _parse_pipeline_version(raw: str) -> Dict[str, str]:
    """Split "RNAFlow v0.1.9" into {"name", "version"}; tolerant fallback."""
    raw = (raw or "").strip()
    if not raw:
        return {"name": "RNAFlow", "version": ""}
    parts = raw.split(None, 1)
    if len(parts) == 2:
        return {"name": parts[0], "version": parts[1]}
    return {"name": "RNAFlow", "version": raw}


def _rel(path: Path, root: Path) -> str:
    return path.relative_to(root).as_posix()


def _file_entry(
    path: Path, root: Path, name: str, ftype: str, category: str, **kw
) -> Dict:
    entry = {
        "name": name,
        "path": _rel(path, root),
        "type": ftype,
        "category": category,
    }
    if path.is_file():
        entry["size_bytes"] = path.stat().st_size
    entry.update(kw)
    return entry


def collect_delivered_files(deliver_dir) -> List[Dict]:
    """Build ARDP files[] by scanning the RNAFlow delivery layout.

    Every entry is existence-checked: modules that were disabled simply yield
    fewer entries. Paths are relative to the delivery root (ARDP §3.1).
    """
    root = Path(deliver_dir)
    entries: List[Dict] = []

    def add(rel_path: str, name: str, ftype: str, category: str, **kw):
        p = root / rel_path
        if p.exists():
            entries.append(_file_entry(p, root, name, ftype, category, **kw))

    # Primary HTML report (is_primary kept consistent with report.entry, ARDP §4.8)
    add("Analysis_Report/index.html", "HTML 分析报告", "html", "report", is_primary=True)

    # QC / summary
    add("01_QC/Overall_MultiQC/multiqc_report.html", "Overall MultiQC 报告", "html", "qc")
    add("Summary/qc_general_stats.txt", "QC 汇总表", "tsv", "qc")
    add("Summary/mapping_general_stats.txt", "比对汇总表", "tsv", "qc")

    # Expression matrices
    for tag, label in [("tpm", "TPM"), ("counts", "Counts"), ("fpkm", "FPKM")]:
        add(
            f"03_Expression/Matrix/merge_rsem_{tag}.tsv",
            f"表达矩阵（{label}）",
            "tsv",
            "expression",
        )

    # DEG tables (per-contrast + all-contrast statistics)
    deg_dir = root / "05_DEG" / "DESEQ2"
    if deg_dir.is_dir():
        for f in sorted(deg_dir.glob("*_DEG.csv")):
            # File names keep the legacy {Control}_vs_{Treat} direction
            contrast = f.stem.replace("_DEG", "")
            entries.append(
                _file_entry(f, root, f"DEG 结果（{contrast}）", "csv", "deg", group=contrast)
            )
        add("05_DEG/DESEQ2/All_Contrast_DEG_Statistics.csv", "全部比较组 DEG 统计", "csv", "deg")

    # Directory-level artifacts
    for rel, name, category in [
        ("06_Enrichments", "富集分析结果目录", "enrichment"),
        ("07_AS", "可变剪接结果目录", "splicing"),
    ]:
        p = root / rel
        if p.is_dir():
            entries.append(
                {"name": name, "path": _rel(p, root) + "/", "type": "dir", "category": category}
            )

    # Delivery integrity manifest produced by RNAFlow_Deliver_Tool (ARDP §6.5)
    add("delivery_manifest.json", "交付清单", "other", "log")
    add("delivery_manifest.md5", "交付 MD5", "other", "log")

    return entries


def _modules_status(config: Dict) -> Dict[str, Dict]:
    """Normalized module switches (set by DataDeliver) -> ARDP modules block."""
    return {
        ardp_key: {"status": "completed" if config.get(cfg_key) else "skipped"}
        for cfg_key, ardp_key in _MODULE_KEY_MAP
    }


def build_comparisons(all_contrasts: Optional[List[str]]) -> List[Dict]:
    """ALL_CONTRASTS entries ("{Control}_vs_{Treat}", legacy) -> ARDP comparisons.

    comparisons[].name uses the new {Treat}_vs_{Control} convention
    (FlowFrame §8.5); result_path points at the real (legacy-named) artifact.
    """
    comparisons = []
    for legacy_name in all_contrasts or []:
        if "_vs_" not in legacy_name:
            continue
        ctrl, treat = legacy_name.split("_vs_", 1)
        comparisons.append(
            {
                "name": f"{treat}_vs_{ctrl}",
                "control": ctrl,
                "treat": treat,
                "result_path": f"05_DEG/DESEQ2/{legacy_name}_DEG.csv",
            }
        )
    return comparisons


def _estimate_timing(config: Dict):
    """Best-effort started_at/duration from the earliest artifact's mtime.

    Lower-bound estimate only; the platform's task-system timing wins
    (ARDP §4.3). Returns (started_datetime | None, duration_seconds).
    """
    workflow = config.get("workflow") or ""
    candidate = (
        Path(workflow) / "00.raw_data" / config.get("convert_md5", "link_dir") / "raw_data_md5.json"
    )
    try:
        started = datetime.datetime.fromtimestamp(candidate.stat().st_mtime, datetime.timezone.utc)
    except OSError:
        return None, 0
    return started, int((_utc_now() - started).total_seconds())


def build_success_manifest(
    config: Dict,
    samples_records: List[Dict],
    all_contrasts: Optional[List[str]],
    deliver_dir: str,
    report_enabled,
) -> Dict:
    """Assemble the terminal success manifest (ARDP §4).

    samples_records: [{"sample", "sample_name", "group"}, ...] from samples.csv.
    report_enabled: same gate expression as ReportData() (config.get("report")).
    """
    root = Path(deliver_dir)
    html_path = root / "Analysis_Report" / "index.html"
    has_report = bool(report_enabled) and html_path.exists()
    started, duration = _estimate_timing(config)
    now = _utc_now()

    comparisons = build_comparisons(all_contrasts)
    group_count = len({r.get("group") for r in samples_records if r.get("group")})

    report_container = ((config.get("parameter") or {}).get("Report") or {}).get("docker_version")

    manifest: Dict = {
        "manifest_version": MANIFEST_VERSION,
        "kind": MANIFEST_KIND,
        "platform": config.get("platform") or {},  # platform-injected, echoed (ARDP §4.2)
        "run": {
            "pipeline": _parse_pipeline_version(config.get("pipeline_version", "")),
            "engine": "snakemake",
            "status": "completed" if has_report else "completed_no_report",
            "finished_at": now.isoformat(),
            "duration_seconds": duration,
            "execution_mode": config.get("execution_mode", "local"),
            # Reference only; the platform locates via tasks.result_dir (ARDP §4.3 / §6.2)
            "output_dir": str(root),
        },
        "project": {
            "project_name": config.get("project_name", ""),
            "client": config.get("client"),
            "species": config.get("species"),
            "genome_version": config.get("Genome_Version"),
            "library_type": config.get("Library_Types"),
        },
        "samples": samples_records,
        "stats": {
            "sample_count": len(samples_records),
            "group_count": group_count,
            "comparison_count": len(comparisons),
        },
        "comparisons": comparisons,
        "files": collect_delivered_files(root),
        "modules": _modules_status(config),
        "extra": {"x_rnaflow": {"report_container": report_container}},
    }

    if started is not None:
        manifest["run"]["started_at"] = started.isoformat()
    if has_report:
        manifest["report"] = {
            "format": "html",
            "entry": "Analysis_Report/index.html",
            "self_contained": True,  # bioreport Quarto renders with embed-resources
            "size_bytes": html_path.stat().st_size,
        }

    # Drop None-valued project entries (keep "" for project_name)
    manifest["project"] = {k: v for k, v in manifest["project"].items() if v is not None}
    return manifest


def build_failure_manifest(config: Dict, message: str, failed_rule=None) -> Dict:
    """Minimal failed-run manifest written by the onerror hook (ARDP §4.12)."""
    return {
        "manifest_version": MANIFEST_VERSION,
        "kind": MANIFEST_KIND,
        "platform": config.get("platform") or {},
        "run": {
            "pipeline": _parse_pipeline_version(config.get("pipeline_version", "")),
            "status": "failed",
            "finished_at": _utc_now().isoformat(),
            "duration_seconds": 0,
            "output_dir": config.get("data_deliver") or "",
        },
        "project": {"project_name": config.get("project_name", "")},
        "stats": {"sample_count": 0},
        "error": {
            "rule": str(failed_rule) if failed_rule else None,
            "message": (str(message) or "pipeline failed")[:2000],
        },
    }


def write_manifest_atomic(manifest: Dict, deliver_dir: str) -> str:
    """Atomic write (ARDP §3.2): tmp file + fsync + os.replace."""
    os.makedirs(deliver_dir, exist_ok=True)
    target = os.path.join(deliver_dir, MANIFEST_FILENAME)
    tmp = target + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(manifest, f, ensure_ascii=False, indent=2)
        f.flush()
        os.fsync(f.fileno())
    os.replace(tmp, target)
    return target
