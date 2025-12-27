
```bash
# Run RNAFlow Analysis
snakemake --cores=60 -p --conda-frontend mamba --use-conda --rerun-triggers mtime
```