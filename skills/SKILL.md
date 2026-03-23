---
name: bio-workflows-rnaflow
description: Complete RNA-seq analysis using RNAFlow pipeline - from raw FASTQ to interactive HTML report with AI interpretation. Covers QC, STAR mapping, RSEM quantification, DEG analysis (DESeq2), variant calling, alternative splicing (rMATS), gene fusion detection, and automated reporting. Use when running full RNA-seq analysis with RNAFlow.
tool_type: mixed
primary_tool: Snakemake
workflow: true
depends_on:
  - read-qc/fastp-workflow
  - read-alignment/star-align
  - rna-quantification/rsem-quant
  - differential-expression/deseq2-basics
  - alternative-splicing/rmats-analysis
  - variant-calling/gatk-rna-variants
  - reporting/quarto-reporting
qc_checkpoints:
  - after_qc: "Q30 >80%, adapter content <5%"
  - after_mapping: "STAR mapping rate >70%, >10M reads uniquely mapped"
  - after_quant: "RSEM quantification complete, TPM distribution reasonable"
  - after_de: "DESeq2 dispersion fit reasonable, PCA separates conditions"
---

## Version Compatibility

Reference examples tested with: Snakemake 8.0+, STAR 2.7.11+, RSEM 1.3.3+, DESeq2 1.42+, rMATS 4.1.2+, GATK 4.4+, fastp 0.23+, Quarto 1.4+, Python 3.9+, R 4.3+

Before using code patterns, verify installed versions match. If versions differ:
- Check RNAFlow version: `grep "RNAFlow" snakefile`
- Snakemake: `snakemake --version`
- Conda environments are automatically managed by RNAFlow

If code throws errors, check RNAFlow's config.schema.yaml and reference.yaml for valid configuration options.

# RNAFlow - Complete RNA-seq Analysis Workflow

**Locating RNAFlow:** First, read the `path_config.yaml` file in this skills directory to find:
- `RNAFLOW_ROOT`: The root directory of the RNAFlow installation (contains snakefile)
- `DEFAULT_ENV_NAME`: Recommended conda environment name
- Configuration templates and default parameters

**"Run full RNA-seq analysis with RNAFlow from FASTQ to interactive report"** → Orchestrate complete RNA-seq pipeline using RNAFlow Snakemake workflow with QC, STAR mapping, RSEM quantification, DESeq2 DEG, rMATS splicing, GATK variants, Arriba fusions, and Quarto HTML reports with AI interpretation.

## Workflow Overview

```
Raw FASTQ files
    |
    v
[1. MD5 Check] -----> md5sum validation
    |
    v
[2. QC & Trimming] -> FastQC + fastp
    |
    v
[3. Contamination] --> FastQ Screen (optional)
    |
    v
[4. Mapping] --------> STAR (2-pass mode)
    |         |
    |         +-----> Qualimap, RSeQC, Preseq
    |
    v
[5. Quantification] -> RSEM (gene/transcript)
    |
    v
[6. DEG Analysis] ---> DESeq2 + GO/KEGG enrichment
    |
    v
[7. Advanced Analysis]
    |
    +---> rMATS (alternative splicing)
    +---> GATK (variant calling)
    +---> Arriba (gene fusion)
    +---> StringTie (novel transcripts)
    |
    v
[8. Reporting] -------> MultiQC + BioReport (Quarto) + AI interpretation
    |
    v
Interactive HTML Report
```

## RNAFlow Configuration

### Step 1: Project Structure Setup

```bash
# Create recommended project structure
mkdir -p Project_Root/{00.raw_data,01.workflow,02.data_deliver}

# RNAFlow repository should be cloned separately
git clone --recurse-submodules git@github.com:xsx123123/RNAFlow.git
```

### Step 2: Create Project Config (config.yaml)

```yaml
# === Basic Project Info ===
project_name: 'PRJNA1224991'
Genome_Version: "Lsat_Salinas_v11"
species: 'Lsat Salinas'
client: 'Internal_Test'

# === Data Paths ===
raw_data_path:
  - /path/to/Project_Root/00.raw_data
sample_csv: /path/to/Project_Root/01.workflow/samples.csv
paired_csv: /path/to/Project_Root/01.workflow/contrasts.csv
workflow: /path/to/Project_Root/01.workflow
data_deliver: /path/to/Project_Root/02.data_deliver

# === Execution Parameters ===
execution_mode: local
Library_Types: fr-firststrand

# === Analysis Module Switches (snake_case) ===
only_qc: false
deg: true
call_variant: true
detect_novel_transcripts: true
rmats: true
gene_fusion: true     # Enable fusion detection (Arriba)
fastq_screen: true
report: true

# === Resource Recommendations ===
# Standard Mode: 4-8 cores/sample, 32GB+ RAM
# Complete Mode (GATK/Fusion): 8+ cores/sample, 64GB+ RAM
# Cluster: Recommended for >10 samples

# === Optional Monitoring ===
loki_url: "http://your-loki-server:3100"
```

### Step 3: Create Sample Metadata (samples.csv)

```csv
sample,sample_name,group
L1MKL2302060-CKX2_23_15_1,CKX2_1,CKX2
L1MKL2302061-CKX2_23_15_2,CKX2_2,CKX2
L1MKL2302062-CKX2_23_15_3,CKX2_3,CKX2
L1MKL2302063-Wo408_1,Wo408_1,Wo408
L1MKL2302064-Wo408_2,Wo408_2,Wo408
L1MKL2302065-Wo408_3,Wo408_3,Wo408
```

### Step 4: Create Contrast Table (contrasts.csv)

```csv
Control,Treat
Wo408,CKX2
```

### Step 5: Environment Setup and Validation (Recommended)

Use the enhanced startup script for automated conda environment checking:

```bash
# Option 1: Use the enhanced startup script (Recommended)
cd /path/to/RNAFlow/skills
./start_rnaflow.sh /path/to/project_config.yaml

# The script will automatically:
# 1. Check if conda is installed
# 2. Verify the RNAFlow conda environment exists
# 3. Check for Snakemake in the environment
# 4. Ask for user confirmation before activating
# 5. Run dry run and ask for final confirmation
```

**Configuring RNAFlow Paths:**
The startup script reads from `path_config.yaml` to locate:
- `RNAFLOW_ROOT`: Path to RNAFlow installation
- `DEFAULT_ENV_NAME`: Conda environment name (default: "rnaflow")
- `AUTO_ACTIVATE`: Set to true to skip confirmation prompts

### Step 6: Manual Environment Setup (Alternative)

If not using the startup script, perform these checks manually:

```bash
# 1. Check conda installation
conda --version

# 2. List available environments
conda env list

# 3. Activate your RNAFlow environment (confirm with user first!)
# Ask user: "Do you want to activate environment 'rnaflow'?"
conda activate rnaflow

# 4. Verify Snakemake
snakemake --version

# 5. Dry Run
cd /path/to/RNAFlow
snakemake -n --config analysisyaml=/path/to/project_config.yaml
```

**QC Checkpoint 1:** Verify all inputs are found and rules are correctly generated.

### Step 7: Run Full Analysis

```bash
# If using startup script, it will proceed automatically after confirmation

# Manual execution:
cd /path/to/RNAFlow

snakemake \
    --cores=60 \
    -p \
    --conda-frontend=mamba \
    --use-conda \
    --rerun-triggers mtime \
    --logger rich-loguru \
    --config analysisyaml=/path/to/project_config.yaml
```

**QC Checkpoint 2:** Monitor logs for:
- STAR mapping rate >70%
- >10M uniquely mapped reads
- RSEM quantification completes successfully

**QC Checkpoint 3:** After DE analysis:
- Check PCA plot in report
- Verify dispersion fit
- No sample outliers

## Supported Genome Versions

RNAFlow includes pre-configured references for:

| Genome Version | Species | Description |
|----------------|---------|-------------|
| Lsat_Salinas_v8 | Lettuce | Lettuce reference v8 |
| Lsat_Salinas_v11 | Lettuce | Lettuce reference v11 |
| ITAG4.1 | Tomato | Tomato reference |
| GRCm39 | Mouse | Mouse reference |
| TAIR10.1 | Arabidopsis | Arabidopsis reference |
| hg38 | Human | Human reference |

Add new genomes in `config/reference.yaml`.

## Analysis Module Configuration

### Complete Analysis (Default)

```yaml
only_qc: false
deg: true
call_variant: true
detect_novel_transcripts: true
rmats: true
fastq_screen: true
report: true
```

### QC-Only Mode (Fast Screening)

```yaml
only_qc: true
```

### Standard Analysis (Skip Time-Consuming Modules)

```yaml
only_qc: false
deg: true
call_variant: false
detect_novel_transcripts: false
rmats: false
report: true
```

## Key STAR Parameters in RNAFlow

RNAFlow uses optimized STAR parameters:

```yaml
# From config/run_parameter.yaml
star_params:
  --peOverlapNbasesMin: 12
  --peOverlapMMp: 0.1
  --twopassMode: Basic
  --outFilterMismatchNoverLmax: 0.04
  --alignMatesGapMax: 1000000
  --chimSegmentMin: 12
  --quantMode: TranscriptomeSAM
```

These parameters provide:
- Better short-fragment mapping with PE overlap merging
- Higher junction accuracy with 2-pass mode
- Stringent mismatch filtering (4%)
- Fusion gene detection capability

## Output Directory Structure

```
02.data_deliver/
├── 00_Raw_Data/             # Raw data summary
├── 01_QC/                   # QC reports (MultiQC)
├── 02_Mapping/              # Mapping statistics
├── 03_Expression/           # Expression matrices (TPM/FPKM/Counts)
├── 05_DEG/                  # DEG results and visualizations
├── 06_Enrichments/          # GO/KEGG enrichment plots
├── 07_AS/                   # Alternative splicing results
├── Summary/                 # Project summary statistics
├── Analysis_Report/         # Interactive HTML report (index.html)
├── report_data/             # Report supporting data
└── delivery_manifest.json   # Delivery manifest with MD5 checksums
```

## BioReport Generation

RNAFlow automatically generates interactive HTML reports:

### 1. Automatic Mode (Recommended)

Report generation is built into the workflow. When `report: true` in config:

```bash
# Report will be generated automatically at:
# 02.data_deliver/Analysis_Report/index.html
```

### 2. Manual Report Regeneration

```bash
# Using Docker (recommended)
docker run -it --rm \
  --user $(id -u):$(id -g) \
  -v /path/to/analysis_data:/data:rw \
  -v /path/to/project_summary.json:/app/project_summary.json:rw \
  -v /path/to/output_report:/workspace:rw \
  bioreportrna:v0.0.5

# Or locally if environment is configured
python report/bioreport/main.py --input results_dir --output report_dir --ai
```

## Troubleshooting Guide

| Issue | Likely Cause | Solution |
|-------|--------------|----------|
| STAR index not found | Reference path incorrect | Check `config/reference.yaml` reference_path |
| Low mapping rate | Wrong genome version | Verify Genome_Version matches your species |
| Conda environment errors | Network issue | Check conda channels, try mamba |
| Samples not found | sample_csv format wrong | Verify sample names match FASTQ filenames |
| DEG not running | contrasts.csv missing | Create contrasts.csv with Control/Treat columns |
| Report not generating | Docker missing | Install Docker or run report locally |
| Memory issues | Cluster resources insufficient | Check `config/cluster_config.yaml` |

## Cluster Execution (Slurm)

For cluster environments:

```yaml
# config.yaml
execution_mode: cluster
queue_id: fat_x86
```

```bash
# Install Slurm executor plugin first
conda install snakemake-executor-plugin-slurm

# Run on cluster
snakemake \
    --executor slurm \
    --jobs 100 \
    --use-conda \
    --conda-frontend mamba \
    --config analysisyaml=config.yaml
```

## Monitoring with Loki + Grafana

Enable real-time monitoring:

```yaml
# config.yaml
loki_url: "http://your-loki-server:3100"
```

```bash
# Install logger plugin
pip install snakemake_logger_plugin_rich_loguru==0.1.4

# Run with monitoring
snakemake \
    --cores 60 \
    --use-conda \
    --logger rich-loguru \
    --config analysisyaml=config.yaml
```

View logs in Grafana dashboard.

## Related Skills

- read-qc/fastp-workflow - Detailed fastp QC parameters
- read-alignment/star-align - STAR alignment details
- rna-quantification/rsem-quant - RSEM quantification
- differential-expression/deseq2-basics - DESeq2 analysis
- alternative-splicing/rmats-analysis - rMATS splicing
- variant-calling/gatk-rna-variants - GATK RNA variant calling
- reporting/quarto-reporting - Quarto report generation
- workflow-management/snakemake-workflows - Snakemake best practices
