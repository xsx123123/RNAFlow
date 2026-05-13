#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os

rule generate_reference_yaml:
    input:
        genome_fa = os.path.basename(config["Reference"]["data_dir"]["fa"]),
        genome_gtf = os.path.basename(config["Reference"]["data_dir"]["gtf"]),
        genome_gff = os.path.basename(config["Reference"]["data_dir"]["gff"]),
        go = os.path.basename(config["Reference"]["data_dir"]["go"]),
        bed12 = f"{config['Reference']['info']['prefix']}.bed12",
        ref_all = f"{config['Reference']['info']['prefix']}_ref_all.txt",
        star_index = f"{config['Reference']['info']['prefix']}/Genome",
    output:
        ref_yaml = f"{config['Reference']['info']['prefix']}_reference.yaml",
    params:
        name = config["Reference"]["info"]["name"],
        prefix = config["Reference"]["info"]["prefix"],
        description = config["Reference"]["info"]["description"],
        go = config["Reference"]["data_dir"]["go"],
        gene_col = config.get("gene_col", "Entrez ID"),
        ploidy = config.get("ploidy", 2),
    message:
        "Generating reference.yaml configuration snippet for {params.name}",
    run:
        import os

        name = params.name
        prefix = params.prefix
        workflow_base = os.path.basename(config["Reference"]["info"]["workflow"])

        def rel(path):
            return os.path.join(workflow_base, os.path.basename(path))

        lines = [
            "# ------------------------------------------------------------------------",
            "# Paste the following sections into config/reference.yaml",
            "# ------------------------------------------------------------------------",
            "",
            "# 1. Append to 'can_use_genome_version:' list",
            "can_use_genome_version:",
            f"  - {name}",
            "# 2. Append to 'mcp_genome_version:' section",
            "mcp_genome_version:",
            f"  {name}:",
            f"    name: {name}",
            f"    description: '{params.description}'",
            "# 3. Append to 'STAR_index:' section",
            "STAR_index:",
            f"    {name}:",
            f"      index: {workflow_base}/{prefix}",
            f"      genome_fa: {rel(input.genome_fa)}",
            f"      genome_gtf: {rel(input.genome_gtf)}",
            f"      genome_gff: {rel(input.genome_gff)}",
            f"      rsem_index: {workflow_base}/{prefix}/{prefix}",
            f"      rsem_index_dir: {workflow_base}/{prefix}/",
            f"      bed12: {workflow_base}/{prefix}.bed12",
            f"      go_annotation: {rel(input.go)}",
            f"      ref_all: {workflow_base}/{prefix}_ref_all.txt",
            "",
            "# 4. Append to 'deg_enrich_wrapper:' section",
            "deg_enrich_wrapper:",
            f"  {name}:",
            f"    gene_col: '{params.gene_col}'",
            "",
            "# 5. Append to 'ploidy_setting:' section",
            "ploidy_setting:",
            f"  {name}:",
            f"    ploidy: {params.ploidy}  # genome ploidy",
        ]

        with open(output.ref_yaml, "w") as f:
            f.write("\n".join(lines) + "\n")
