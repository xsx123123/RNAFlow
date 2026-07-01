# RNAFlow Reference Builder

This is an independent Snakemake sub-workflow for building RNA-seq reference indexes used by the main RNAFlow pipeline.

## What It Builds

Given a genome FASTA, gene annotation GTF/GFF, and a GO annotation table, this workflow produces:

- **STAR + RSEM index** (`rsem-prepare-reference --star`)
- **BED12** gene ranges for gene coverage analysis
- **`ref_all`** gene information table
- A ready-to-paste **`reference.yaml` snippet** for `config/reference.yaml`

## Quick Start

```bash
cd build_reference

# 1. Edit config.yaml with your genome and input file paths
vim config.yaml

# 2. Dry run
snakemake --use-conda --cores 40 --dry-run

# 3. Build
snakemake --use-conda --cores 40
```

## Configuration

Edit `config.yaml`:

```yaml
Genome_Version: GRCm39

can_use_genome_version:
  - GRCm39

gene_col: 'ENSEMBL'
ploidy: 2

Reference:
  info:
    name: GRCm39
    prefix: GRCm39_RNAFlow_Index
    description: Mouse reference genome (GRCm39)
    # Parent reference directory. MUST match the main pipeline's reference_path.
    # The workflow creates a subdirectory named after 'name' under this path.
    workflow: /home/zj/reference/RNAFlow_reference
  data_dir:
    fa: /home/zj/temp/GRCm39/GRCm39.genome.fa
    gtf: /home/zj/temp/GRCm39/gencode.vM38.annotation.gtf
    gff: /home/zj/temp/GRCm39/gencode.vM38.annotation.gff3
    go: /home/zj/temp/GRCm39/mgigene_go_annotation.tsv
```

### Important: `workflow` Path Semantics

- `workflow` is the **parent reference directory**.
- Actual build outputs go into `workflow/name/` (e.g. `/home/zj/reference/RNAFlow_reference/GRCm39`).
- This ensures the generated YAML snippet is immediately usable with the main RNAFlow pipeline.

## Outputs

After a successful build, the directory structure looks like:

```
/home/zj/reference/RNAFlow_reference/GRCm39/
├── GRCm39.genome.fa
├── gencode.vM38.annotation.gtf
├── gencode.vM38.annotation.gff3
├── mgigene_go_annotation.tsv
├── GRCm39_RNAFlow_Index/                      # STAR + RSEM index
│   ├── Genome
│   ├── GRCm39_RNAFlow_Index.transcripts.fa
│   ├── GRCm39_RNAFlow_Index.idx.fa
│   └── ...
├── GRCm39_RNAFlow_Index.bed12                 # BED12 annotation
├── GRCm39_RNAFlow_Index_ref_all.txt           # Gene info table
└── GRCm39_RNAFlow_Index_reference.yaml        # Config snippet
```

## Integration with Main RNAFlow

1. Open `GRCm39_RNAFlow_Index_reference.yaml`.
2. Copy the commented sections.
3. Paste them into the corresponding sections of `config/reference.yaml`.
4. Verify that `reference_path` in `config/reference.yaml` matches the `workflow` path in `build_reference/config.yaml`.
5. Set `Genome_Version: GRCm39` in your project config and run the main pipeline.

## Workflow Steps

| Rule | File | Description |
|------|------|-------------|
| `copy_reference_files` | `rules/00.copy_reference.smk` | Copy FASTA, GTF, GFF, GO into workdir |
| `build_index` | `rules/01.index.smk` | Build STAR + RSEM index with `rsem-prepare-reference` |
| `build_bed12` | `rules/02.annotation.smk` | Convert GTF to BED12 |
| `build_ref_all` | `rules/02.annotation.smk` | Build gene info table |
| `generate_reference_yaml` | `rules/03.build_yaml.smk` | Generate `reference.yaml` snippet |

## Notes

- Conda environments are defined in `../envs/` and activated automatically with `--use-conda`.
- STAR index building is memory-intensive; plan for ~32GB+ RAM for mammalian genomes.
