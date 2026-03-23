# RNAFlow Usage Guide

## Overview

This guide helps you use RNAFlow - a complete Snakemake-based RNA-seq analysis pipeline that takes you from raw FASTQ files to interactive HTML reports with AI-powered interpretation.

## Prerequisites

```bash
# Install Snakemake and Mamba
conda install -c conda-forge -c bioconda snakemake mamba

# Optional: Install enhanced logger plugin for monitoring
pip install snakemake_logger_plugin_rich_loguru==0.1.4

# Clone RNAFlow repository
git clone --recurse-submodules git@github.com:xsx123123/RNAFlow.git
cd RNAFlow
```

## Quick Start

Tell your AI agent what you want to do:
- "Run a complete RNA-seq analysis with RNAFlow on my FASTQ files"
- "Set up RNAFlow for my project with 3 control and 3 treated samples"
- "Generate the interactive HTML report from my existing RNAFlow results"

## Example Prompts

### Starting from Scratch
> "I have raw RNA-seq FASTQ files for lettuce, help me set up and run RNAFlow"

> "Create a complete RNAFlow configuration for my mouse RNA-seq experiment"

> "Run RNAFlow with all modules enabled including variant calling and alternative splicing"

### Customizing the Analysis
> "Run RNAFlow but skip the variant calling module to save time"

> "Use RNAFlow in QC-only mode to quickly check my data quality"

> "Add Loki monitoring to my RNAFlow run"

### Cluster Execution
> "Configure RNAFlow to run on our Slurm cluster"

> "Set up cluster resource allocation for RNAFlow jobs"

### Report Generation
> "Regenerate the BioReport HTML report from my completed RNAFlow analysis"

> "Run the AI-powered interpretation on my DEG results"

## Input Requirements

| Input | Format | Description | Required |
|-------|--------|-------------|----------|
| FASTQ files | .fastq.gz | Raw sequencing reads (paired-end) | Yes |
| config.yaml | YAML | Project configuration | Yes |
| samples.csv | CSV | Sample metadata (sample, sample_name, group) | Yes |
| contrasts.csv | CSV | DEG contrasts (Control, Treat) | For DEG |
| Reference genome | FASTA+GTF | Indexed reference | Pre-configured |

## Project Structure

RNAFlow recommends this 3-tier directory structure:

```
Project_Root/
├── 00.raw_data/             # Raw FASTQ files (read-only)
├── 01.workflow/             # Working directory for analysis
│   ├── config.yaml          # Project config
│   ├── samples.csv          # Sample info
│   ├── contrasts.csv        # DEG contrasts
│   ├── 01.qc/              # Intermediate QC files
│   ├── 02.mapping/         # Intermediate mapping files
│   ├── 03.count/           # Intermediate count files
│   ├── logs/               # Log files
│   └── benchmarks/         # Resource usage stats
└── 02.data_deliver/        # Final results (auto-generated)
```

## Configuration Options

### Basic Configuration (config.yaml)

```yaml
project_name: 'MyProject'
Genome_Version: "GRCm39"
species: 'Mus musculus'
client: 'MyLab'

raw_data_path:
  - /path/to/00.raw_data
sample_csv: /path/to/01.workflow/samples.csv
paired_csv: /path/to/01.workflow/contrasts.csv
workflow: /path/to/01.workflow
data_deliver: /path/to/02.data_deliver

execution_mode: local
Library_Types: fr-firststrand
```

### Module Switches

All switches use snake_case naming:

| Module | Default | Description |
|--------|---------|-------------|
| only_qc | false | Only run QC and mapping |
| deg | true | Differential expression with DESeq2 |
| call_variant | false | Variant calling with GATK |
| detect_novel_transcripts | false | Novel transcripts with StringTie |
| rmats | true | Alternative splicing with rMATS |
| fastq_screen | true | Contamination detection |
| report | true | Generate HTML report |

### Library Types

| Library_Type | Description |
|--------------|-------------|
| fr-unstranded | Non-stranded library |
| fr-firststrand | dUTP, NSR, NNSR |
| fr-secondstrand | Ligation, Standard SOLiD |

## Supported Genomes

RNAFlow comes pre-configured for:

- **Lsat_Salinas_v8/v11** - Lettuce
- **ITAG4.1** - Tomato
- **GRCm39** - Mouse
- **TAIR10.1** - Arabidopsis
- **hg38** - Human

Add new genomes in `config/reference.yaml`.

## Typical Workflow

### 1. Set up Project

```bash
# Create directory structure
mkdir -p MyProject/{00.raw_data,01.workflow,02.data_deliver}

# Link or copy FASTQ files
cp /path/to/your/*.fastq.gz MyProject/00.raw_data/
```

### 2. Create Metadata Files

**samples.csv:**
```csv
sample,sample_name,group
sample1_R1, sample1, control
sample2_R1, sample2, control
sample3_R1, sample3, control
sample4_R1, sample4, treated
sample5_R1, sample5, treated
sample6_R1, sample6, treated
```

**contrasts.csv:**
```csv
Control,Treat
control,treated
```

### 3. Create config.yaml

Copy a template from RNAFlow and customize.

### 4. Dry Run

```bash
cd RNAFlow
snakemake -n --config analysisyaml=/path/to/config.yaml
```

### 5. Run Analysis

```bash
snakemake \
    --cores=60 \
    -p \
    --conda-frontend=mamba \
    --use-conda \
    --rerun-triggers mtime \
    --logger rich-loguru \
    --config analysisyaml=/path/to/config.yaml
```

### 6. View Results

Open `MyProject/02.data_deliver/Analysis_Report/index.html` in a browser.

## Choosing Analysis Modules

### Scenario 1: Quick Quality Check

```yaml
only_qc: true
```
- Runs: QC, trimming, mapping
- Skips: DEG, variants, splicing, etc.
- Use for: Data screening, quality assessment

### Scenario 2: Standard DEG Analysis

```yaml
only_qc: false
deg: true
call_variant: false
detect_novel_transcripts: false
rmats: false
fastq_screen: true
report: true
```
- Focuses on: DEG and enrichment
- Skips: Time-consuming modules
- Use for: Routine gene expression studies

### Scenario 3: Comprehensive Analysis

```yaml
only_qc: false
deg: true
call_variant: true
detect_novel_transcripts: true
rmats: true
fastq_screen: true
report: true
```
- Runs: All modules
- Use for: Deep transcriptome characterization

## Output Interpretation

### Key Output Files

| Location | Content |
|----------|---------|
| 01_QC/ | MultiQC report, fastp HTMLs |
| 02_Mapping/ | STAR logs, Qualimap reports |
| 03_Expression/ | Gene count matrices (TPM/FPKM/Counts) |
| 05_DEG/ | DEG lists, volcano plots, heatmaps |
| 06_Enrichments/ | GO/KEGG enrichment results |
| 07_AS/ | rMATS alternative splicing results |
| Analysis_Report/ | Interactive HTML report (main entry) |

### BioReport Features

The interactive HTML report includes:
- Project summary and statistics
- QC visualizations
- Mapping statistics
- Expression distributions
- DEG results with interactive tables
- Enrichment pathway visualizations
- AI-powered biological interpretation (when configured)

## Tips for Success

1. **Replicates**: Use at least 3 biological replicates per condition
2. **Sequencing Depth**: 20-30M reads per sample for standard DEG
3. **Library Type**: Verify Library_Types matches your library prep
4. **Genome Version**: Double-check Genome_Version matches your species
5. **Storage**: Ensure sufficient space for BAM files (can be large)
6. **Cluster**: For large projects, use cluster execution mode
7. **Monitoring**: Enable Loki + Grafana for real-time monitoring

## Common Issues & Solutions

### Issue: Samples not found
**Solution**: Check that sample names in samples.csv match the FASTQ filenames (without _R1/_R2 and extensions)

### Issue: STAR index missing
**Solution**: Verify reference_path in config/reference.yaml points to the correct location

### Issue: Low mapping rate
**Solution**: Check that you're using the correct Genome_Version for your species

### Issue: Conda environment errors
**Solution**: Use --conda-frontend mamba for faster, more reliable environment solving

### Issue: DEG not running
**Solution**: Make sure contrasts.csv exists with Control and Treat columns

### Issue: Out of memory
**Solution**: Adjust cluster_config.yaml or use fewer cores locally
