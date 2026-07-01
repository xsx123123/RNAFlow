---
name: rnaflow-build-reference
description: Build RNA-seq reference indexes (STAR/RSEM, BED12, ref_all, GO) for the RNAFlow pipeline. Use whenever the user needs to prepare a custom reference genome, build STAR/RSEM indexes, or add a new genome version to RNAFlow's config/reference.yaml.
tool_type: workflow
primary_tool: Snakemake
workflow: true
depends_on:
  - read-alignment/star-align
  - rna-quantification/rsem-quant
---

## RNAFlow Reference Builder

**Locating RNAFlow:** First, read the `path_config.yaml` file in this skills directory to find:
- `RNAFLOW_ROOT`: The root directory of the RNAFlow installation (contains `snakefile` and `build_reference/`)

**"Build a reference index for RNAFlow"** → Run the `build_reference` Snakemake sub-workflow to create STAR/RSEM indexes, BED12, `ref_all` gene tables, and a ready-to-paste `reference.yaml` snippet.

## When to Use

Use this skill when the user wants to:
- Add a new genome version to RNAFlow
- Build STAR + RSEM indexes from a custom FASTA/GTF/GFF
- Generate the `reference.yaml` snippet required by `config/reference.yaml`
- Prepare reference files (genome FASTA, GTF, GFF, GO annotation) for the main RNAFlow pipeline

## Workflow Overview

```
FASTA + GTF + GFF + GO annotation
    |
    v
[Copy References] ----> Copy inputs to reference directory
    |
    v
[Build Index] --------> RSEM prepare-reference (also builds STAR index)
    |
    v
[Build Annotation] ---> BED12 + ref_all gene table
    |
    v
[Generate YAML] ------> reference.yaml snippet for config/reference.yaml
```

## Prerequisites

- Snakemake 8.0+ with conda support
- Input files:
  - Genome FASTA (`.fa` or `.fasta`)
  - Gene annotation GTF
  - Gene annotation GFF3
  - GO annotation TSV (gene ID → GO terms)
- Sufficient disk space and memory (STAR index can be large)

## Configuration (`build_reference/config.yaml`)

```yaml
# Genome version for validation (must be in can_use_genome_version)
Genome_Version: GRCm39

# Supported genome versions list
can_use_genome_version:
  - GRCm39

# DEG enrichment gene identifier column
gene_col: 'ENSEMBL'

# Genome ploidy for variant calling
ploidy: 2

Reference:
  info:
    name: GRCm39
    prefix: GRCm39_RNAFlow_Index          # Index directory name
    description: Mouse reference genome (GRCm39)
    # Base directory for reference outputs. Must match the main pipeline's
    # reference_path (config/reference.yaml). The workflow creates a
    # subdirectory named after 'name' (e.g. GRCm39) under this path.
    workflow: /path/to/reference
  data_dir:
    fa: /path/to/GRCm39.genome.fa
    gff: /path/to/gencode.vM38.annotation.gff3
    gtf: /path/to/gencode.vM38.annotation.gtf
    go: /path/to/mgigene_go_annotation.tsv
```

### Important Path Semantics

- `workflow` is the **parent reference directory** (e.g. `/home/zj/reference/RNAFlow_reference`).
- The workflow will create `workflow/name/` (e.g. `/home/zj/reference/RNAFlow_reference/GRCm39`) and place all outputs there.
- This design ensures the generated `reference.yaml` snippet uses paths relative to the main pipeline's `reference_path`, so it works immediately after building.

## Running the Builder

```bash
cd build_reference

# Dry run check
snakemake --use-conda --cores 40 --dry-run

# Execute build
snakemake --use-conda --cores 40
```

## Outputs

After successful completion, outputs are under `workflow/name/`:

```
/path/to/reference/GRCm39/
├── GRCm39.genome.fa
├── gencode.vM38.annotation.gtf
├── gencode.vM38.annotation.gff3
├── mgigene_go_annotation.tsv
├── GRCm39_RNAFlow_Index/                 # STAR + RSEM index
│   ├── Genome
│   ├── GRCm39_RNAFlow_Index.transcripts.fa
│   ├── GRCm39_RNAFlow_Index.idx.fa
│   └── ...
├── GRCm39_RNAFlow_Index.bed12            # BED12 for gene coverage
├── GRCm39_RNAFlow_Index_ref_all.txt      # Gene info table
└── GRCm39_RNAFlow_Index_reference.yaml   # Snippet for config/reference.yaml
```

## Integrating with Main RNAFlow

1. Open `GRCm39_RNAFlow_Index_reference.yaml`.
2. Copy the five commented sections.
3. Paste them into the corresponding sections of `config/reference.yaml`.
4. Ensure `reference_path` in `config/reference.yaml` matches the `workflow` path used in `build_reference/config.yaml`.
5. Use the new `Genome_Version` in your project `config.yaml`.

## Troubleshooting

| Issue | Likely Cause | Solution |
|-------|--------------|----------|
| YAML paths don't match file locations | `workflow` and `reference_path` differ | Make them point to the same parent directory |
| STAR index build fails | Insufficient memory or duplicate sequence IDs | Check FASTA headers and provide ~32GB+ RAM |
| GTF/GFF parsing errors | Format issues | Validate with `gtfToGenePred` manually |
| Missing GO annotation | File path incorrect | Check `data_dir.go` path |
