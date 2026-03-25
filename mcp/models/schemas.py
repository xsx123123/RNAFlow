#!/usr/bin/env python3
"""
Pydantic data models for RNAFlow MCP
"""

import sys
import yaml
from pathlib import Path
from typing import Optional, List
from pydantic import BaseModel, Field, field_validator


# Add parent directory to path to access config
sys.path.insert(0, str(Path(__file__).parent.parent.parent))


# Load supported genome versions from config/reference.yaml
def load_supported_genomes():
    """Load supported genome versions from reference.yaml"""
    config_path = Path(__file__).parent.parent.parent / "config" / "reference.yaml"
    if not config_path.exists():
        # Fallback to default list if config not found
        return [
            "Lsat_Salinas_v8",
            "Lsat_Salinas_v11",
            "ITAG4.1",
            "TAIR10.1",
            "GRCm39",
            "hg38",
            "Lsat_Salinas_v11_wx",
        ]

    try:
        with open(config_path, "r", encoding="utf-8") as f:
            ref_config = yaml.safe_load(f)

        if "mcp_genome_version" in ref_config and ref_config["mcp_genome_version"]:
            return list(ref_config["mcp_genome_version"].keys())
        elif "can_use_genome_version" in ref_config:
            return ref_config["can_use_genome_version"]
        else:
            return [
                "Lsat_Salinas_v8",
                "Lsat_Salinas_v11",
                "ITAG4.1",
                "TAIR10.1",
                "GRCm39",
                "hg38",
                "Lsat_Salinas_v11_wx",
            ]
    except Exception as e:
        print(f"Warning: Failed to load genome versions from config: {e}")
        return [
            "Lsat_Salinas_v8",
            "Lsat_Salinas_v11",
            "ITAG4.1",
            "TAIR10.1",
            "GRCm39",
            "hg38",
            "Lsat_Salinas_v11_wx",
        ]


# Get supported genome list
SUPPORTED_GENOMES = load_supported_genomes()


class ProjectConfig(BaseModel):
    """Complete project configuration model matching RNAFlow specs"""

    # === Basic Project Information ===
    project_name: str = Field(..., description="Name of the project")
    Genome_Version: str = Field(
        ..., description="Genome version (must be one of the supported versions)"
    )
    species: str = Field(
        ..., description="Species name (e.g., Mus musculus, Homo_sapiens)"
    )
    client: str = Field(default="Research_Lab", description="Client or lab name")

    # === Data Path Configuration ===
    raw_data_path: List[str] = Field(
        ..., description="Paths to raw data directories (e.g., [/project/00.raw_data])"
    )
    sample_csv: str = Field(
        ..., description="Path to samples.csv (e.g., /project/01.workflow/samples.csv)"
    )
    paired_csv: str = Field(
        ...,
        description="Path to contrasts.csv (e.g., /project/01.workflow/contrasts.csv)",
    )
    workflow: str = Field(
        ..., description="Workflow directory (e.g., /project/01.workflow)"
    )
    data_deliver: str = Field(
        ..., description="Output directory (e.g., /project/02.data_deliver)"
    )

    # === Execution Parameters ===
    execution_mode: str = Field(
        default="local", description="Execution mode: local or cluster"
    )
    Library_Types: str = Field(
        default="fr-firststrand",
        description="Library type: fr-firststrand, fr-unstranded, etc.",
    )

    # === Analysis Module Switches ===
    only_qc: bool = Field(default=False, description="Only run QC analysis")
    deg: bool = Field(default=True, description="Enable DESeq2 DEG analysis")
    call_variant: bool = Field(default=False, description="Enable GATK variant calling")
    detect_novel_transcripts: bool = Field(
        default=False, description="Enable StringTie novel transcript detection"
    )
    rmats: bool = Field(
        default=False, description="Enable rMATS alternative splicing analysis"
    )
    fastq_screen: bool = Field(
        default=True, description="Enable FastQ Screen contamination check"
    )
    report: bool = Field(default=True, description="Enable HTML report generation")

    # === Optional Monitoring ===
    loki_url: Optional[str] = Field(
        default=None, description="Loki URL for monitoring (optional)"
    )

    @field_validator("Genome_Version")
    @classmethod
    def validate_genome_version(cls, v):
        """Validate that genome version is supported"""
        if v not in SUPPORTED_GENOMES:
            raise ValueError(
                f"Genome version '{v}' is not supported. "
                f"Supported versions are: {', '.join(SUPPORTED_GENOMES)}"
            )
        return v

    @classmethod
    def get_supported_genomes(cls):
        """Get list of supported genome versions"""
        return SUPPORTED_GENOMES

    model_config = {"validate_assignment": True}
