# RNAFlow - RNA-seq Analysis Pipeline

RNAFlow is a comprehensive Snakemake-based pipeline for RNA-seq data analysis. It provides a complete workflow from raw data quality control to expression quantification, variant calling, and transcript assembly.

## Table of Contents
- [Overview](#overview)
- [Pipeline Workflow](#pipeline-workflow)
- [Directory Structure](#directory-structure)
- [Installation](#installation)
- [Configuration](#configuration)
- [Usage](#usage)
- [Dependencies](#dependencies)
- [Output](#output)

## Overview

RNAFlow is designed for analyzing RNA-seq data using STAR for alignment, RSEM for quantification, and additional tools for quality control, variant calling, and transcript assembly. The pipeline separates code from analysis data, keeping the workflow definition in the pipeline directory while processing data in a separate analysis directory.

**Version:** RNAFlow_v0.1  
**Author:** JZHANG

## Pipeline Workflow

The RNAFlow pipeline includes the following steps:

1. **Log Setup**: Initialize logging and workflow management
2. **Common Setup**: Set up sample information and common parameters
3. **ID Conversion**: Convert sample IDs as needed
4. **File Conversion & MD5 Check**: Verify file integrity and create symbolic links
5. **Quality Control**: 
   - Raw data quality assessment using FastQC
   - MultiQC report generation
6. **Contamination Check**: Check for sample contamination
7. **Data Cleaning**: 
   - Adapter trimming using fastp
   - Quality filtering
8. **Read Mapping**:
   - Build STAR reference index
   - Perform alignment with STAR
   - Sort and index BAM files
   - Quality assessment with Qualimap, Samtools
9. **Expression Quantification**: 
   - Build RSEM reference index
   - Quantify gene and isoform expression with RSEM
10. **Variant Calling**: Detect variants from RNA-seq data (optional)
11. **Transcript Assembly**: Assemble novel transcripts using StringTie (optional)

## Directory Structure

```
RNAFlow/
├── snakefile                    # Main Snakemake workflow file
├── config.yaml                  # Main configuration file
├── README.md                    # This file
├── config/                      # Configuration directory
│   └── config.yaml              # Detailed parameter configuration
├── envs/                        # Conda environment definitions
│   ├── bcftools.yaml
│   ├── bwa2.yaml
│   ├── deeptools.yaml
│   ├── fastp.yaml
│   ├── fastqc.yaml
│   ├── gatk.yaml
│   ├── multiqc.yaml
│   ├── picard.yaml
│   ├── qualimap.yaml
│   ├── rsem.yaml
│   ├── star.yml
│   └── stringtie.yaml
└── rules/                       # Rule definitions
    ├── 00.log.smk              # Logging setup
    ├── 01.common.smk           # Common functions and sample setup
    ├── 02.id_convert.smk       # Sample ID conversion
    ├── 03.file_convert_md5.smk # File integrity check and linking
    ├── 04.short_read_qc.smk    # Quality control with FastQC/MultiQC
    ├── 05.Contamination_check.smk # Contamination detection
    ├── 06.short_read_clean.smk # Data cleaning with fastp
    ├── 07.mapping.smk          # Alignment with STAR
    ├── 08.rsem.smk             # Expression quantification with RSEM
    ├── 09.call_variant.smk     # Variant calling
    └── 10.Assembly.smk         # Transcript assembly
```

## Installation

1. Clone the repository:
```bash
git clone <repository-url>
cd RNAFlow
```

2. Ensure you have Snakemake installed with conda support:
```bash
# Install snakemake via conda
conda install -c conda-forge -c bioconda snakemake
# Or install via pip
pip install snakemake
```

3. The pipeline uses conda environments for dependencies, which will be automatically created during execution.

## Configuration

The pipeline uses two configuration files:

### Main Configuration (`config.yaml`)
Located in the root directory, this file specifies:
- Project name
- Reference genome version (Lsat_Salinas_v8 or Lsat_Salinas_v11)
- Input data paths
- Sample information file
- Workflow and output directories

### Detailed Configuration (`config/config.yaml`)
Located in the config/ directory, this file contains:
- Software paths and parameters
- Reference genome locations
- Thread counts for different tools
- Tool-specific parameters (STAR, RSEM, GATK, etc.)
- Quality control thresholds

### Required Input Files
- Sample CSV file with sample information
- Raw sequencing data in FASTQ format
- Reference genome files (FASTA, GTF/GFF)

## Usage

### Running the Pipeline

To run the pipeline with 60 cores:

```bash
snakemake --cores=60 -p --conda-frontend mamba --use-conda --rerun-triggers mtime
```

### Command Options Explained:
- `--cores=60`: Use up to 60 CPU cores
- `-p`: Print shell commands as they're executed
- `--conda-frontend mamba`: Use mamba for faster environment management
- `--use-conda`: Automatically manage conda environments
- `--rerun-triggers mtime`: Rerun rules when input file modification times change

### Running Specific Parts of the Pipeline

You can run individual steps by specifying specific output files:

```bash
# Run only quality control steps
snakemake --cores 10 01.qc/short_read_qc_r1/sample_R1_fastqc.html

# Run mapping step
snakemake --cores 16 02.mapping/STAR/sample/Aligned.sortedByCoord.out.bam
```

## Dependencies

RNAFlow uses several bioinformatics tools managed through conda environments:

- **FastQC**: Quality control of raw sequencing data
- **MultiQC**: Aggregation of quality control results
- **fastp**: Adapter trimming and quality filtering
- **STAR**: Spliced alignment of RNA-seq data
- **RSEM**: Quantification of gene and isoform expression
- **Samtools**: Manipulation of SAM/BAM files
- **Qualimap**: Quality control of BAM alignment files
- **deepTools**: Analysis of deep-sequencing data (bigWig generation)
- **GATK**: Variant calling (optional)
- **StringTie**: Transcript assembly (optional)

All dependencies are defined in the `envs/` directory as conda environment YAML files.

## Output

The pipeline generates output in the specified data delivery directory:

### Quality Control
- `01.qc/`: FastQC reports, MultiQC reports, trimmed data
- `01.qc/short_read_qc_r1/`: R1 read quality reports
- `01.qc/short_read_qc_r2/`: R2 read quality reports
- `01.qc/short_read_trim/`: Trimmed FASTQ files

### Alignment
- `02.mapping/`: STAR alignment results, BAM files, alignment statistics
- `02.mapping/STAR/`: Sorted BAM files and alignment logs
- `02.mapping/qualimap_report/`: Qualimap quality reports
- `02.mapping/samtools_flagstat/`: Samtools flag statistics
- `02.mapping/bamCoverage/`: BigWig coverage files

### Expression Quantification
- `03.count/rsem/`: RSEM gene and isoform expression results

### Variant Calling (if enabled)
- `04.variant_calling/`: Variant calling results (VCF files)

### Transcript Assembly (if enabled)
- `05.assembly/`: StringTie assembly results

## Reference Genomes

The pipeline supports multiple reference genome versions:
- Lactuca_sativa V11 (Lsat_Salinas_v11)
- Lactuca_sativa V8 (Lsat_Salinas_v8)

The reference genome files (FASTA, GTF, GFF) must be available at the paths specified in the configuration file.

## Troubleshooting

### Common Issues
1. **Missing dependencies**: Ensure conda/mamba is available and properly configured
2. **Insufficient disk space**: The pipeline generates large intermediate files
3. **Memory issues**: Some steps (STAR alignment, RSEM) require significant memory
4. **File permissions**: Ensure the pipeline has read/write access to input/output directories

### Log Files
Check log files in the `logs/` directory for detailed error information:
- `logs/01.qc/`: Quality control logs
- `logs/02.mapping/`: Alignment logs
- `logs/03.count/`: Quantification logs

## Customization

The pipeline can be customized by modifying:
- Configuration files to change parameters
- Individual rule files in the `rules/` directory
- Adding or removing steps in the main `snakefile`

## Citation

If you use RNAFlow in your research, please cite this pipeline.

## Support

For questions or issues, please contact the author or submit an issue to the repository.