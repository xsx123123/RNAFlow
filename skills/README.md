# RNAFlow Skills

This directory contains the bioSkills configuration for RNAFlow - a complete Snakemake-based RNA-seq analysis pipeline.

## Directory Structure

```
skills/
├── SKILL.md              # Main skill definition for AI agents
├── usage-guide.md        # Detailed usage guide
├── README.md             # This file
├── install_skills.sh     # Generic installation script
├── install_claude_skills.sh # Dedicated Claude Code installer
├── install_codex_skills.sh  # Dedicated Codex installer
├── start_rnaflow.sh      # Enhanced startup script
├── path_config.yaml      # Path configuration
└── examples/             # Example configuration files
    ├── config_complete.yaml      # Complete analysis (all modules)
    ├── config_qc_only.yaml       # QC-only mode (fast screening)
    ├── config_standard_deg.yaml  # Standard DEG analysis
    ├── samples.csv               # Example sample metadata
    ├── contrasts.csv             # Example contrast table
    └── run_rnaflow.sh            # Helper execution script
```

## What's Included

### SKILL.md
The main skill definition file that teaches AI agents how to use RNAFlow. Includes:
- Complete workflow overview
- Configuration examples
- Module switch documentation
- Troubleshooting guide
- Version compatibility information

### usage-guide.md
A comprehensive guide for users covering:
- Prerequisites and installation
- Quick start instructions
- Example prompts for AI agents
- Input requirements
- Configuration options
- Typical workflow steps

### examples/
Ready-to-use configuration templates:
- **config_complete.yaml**: All modules enabled for deep transcriptome analysis
- **config_qc_only.yaml**: Quick QC and data screening
- **config_standard_deg.yaml**: Standard DEG analysis (faster, skips time-consuming modules)
- **samples.csv**: Example sample metadata table
- **contrasts.csv**: Example contrast table for DEG
- **run_rnaflow.sh**: Helper script to run RNAFlow

## How to Use

### With AI Agents
Load this skill into your AI agent (Claude Code, OpenAI Codex, etc.) and ask questions like:
- "Run a complete RNA-seq analysis with RNAFlow"
- "Set up RNAFlow for my project"
- "Help me configure RNAFlow for differential expression analysis"

### Direct Usage
Copy the example configuration files and customize for your project:

```bash
# 1. Copy example config
cp skills/examples/config_standard_deg.yaml my_config.yaml

# 2. Edit the config with your paths and settings
nano my_config.yaml

# 3. Create sample metadata
cp skills/examples/samples.csv .
# Edit samples.csv with your sample names

# 4. Create contrasts (for DEG)
cp skills/examples/contrasts.csv .
# Edit contrasts.csv with your comparisons

# 5. Run RNAFlow
cd /path/to/RNAFlow
snakemake --cores 60 --use-conda --config analysisyaml=/path/to/my_config.yaml
```

## RNAFlow Features

- **Quality Control**: FastQC + fastp for trimming and adapter removal
- **Contamination Check**: FastQ Screen for species contamination detection
- **Mapping**: STAR 2-pass mode with optimized parameters
- **Quantification**: RSEM for gene/transcript level quantification
- **DEG Analysis**: DESeq2 with GO/KEGG enrichment
- **Variant Calling**: GATK for RNA-seq variant detection
- **Alternative Splicing**: rMATS for differential splicing analysis
- **Gene Fusion**: Arriba for fusion gene detection
- **Novel Transcripts**: StringTie for novel transcript assembly
- **Reporting**: MultiQC + interactive Quarto HTML reports with AI interpretation

## Supported Genomes

RNAFlow comes pre-configured for:
- Lettuce (Lsat_Salinas_v8, Lsat_Salinas_v11)
- Tomato (ITAG4.1)
- Mouse (GRCm39)
- Arabidopsis (TAIR10.1)
- Human (hg38)

Add new genomes in `config/reference.yaml`.

## For More Information

- See the main [README.md](../README.md) for complete RNAFlow documentation
- Check [usage-guide.md](./usage-guide.md) for detailed usage instructions
- Look at [SKILL.md](./SKILL.md) for the AI agent skill definition
