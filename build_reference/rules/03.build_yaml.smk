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
        import yaml

        name = params.name
        prefix = params.prefix
        # YAML paths are relative to the main pipeline's reference_path.
        # Because outputs live in workflow_dir = reference_base / name,
        # the subdirectory prefix is the genome version name.
        workflow_base = name

        def rel(path):
            return os.path.join(workflow_base, os.path.basename(path))

        header = (
            "# ------------------------------------------------------------------------\n"
            "# Paste the following sections into config/reference.yaml\n"
            "# ------------------------------------------------------------------------\n"
        )

        # Build structured config as a list of (section_comment, dict) pairs,
        # so we can emit section comments between blocks while keeping YAML
        # values safe from quoting/escaping bugs.
        sections = [
            ("1. Append to 'can_use_genome_version:' list",
             {"can_use_genome_version": [name]}),
            ("2. Append to 'mcp_genome_version:' section",
             {"mcp_genome_version": {
                 name: {
                     "name": name,
                     "description": params.description,
                 }}}),
            ("3. Append to 'STAR_index:' section",
             {"STAR_index": {
                 name: {
                     "index": f"{workflow_base}/{prefix}",
                     "genome_fa": rel(input.genome_fa),
                     "genome_gtf": rel(input.genome_gtf),
                     "genome_gff": rel(input.genome_gff),
                     "rsem_index": f"{workflow_base}/{prefix}/{prefix}",
                     "rsem_index_dir": f"{workflow_base}/{prefix}/",
                     "bed12": f"{workflow_base}/{prefix}.bed12",
                     "go_annotation": rel(input.go),
                     "ref_all": f"{workflow_base}/{prefix}_ref_all.txt",
                 }}}),
            ("4. Append to 'deg_enrich_wrapper:' section",
             {"deg_enrich_wrapper": {
                 name: {
                     "gene_col": params.gene_col,
                 }}}),
            ("5. Append to 'ploidy_setting:' section",
             {"ploidy_setting": {
                 name: {
                     "ploidy": params.ploidy,
                 }}}),
        ]

        with open(output.ref_yaml, "w") as f:
            f.write(header)
            for comment, data in sections:
                f.write(f"\n# {comment}\n")
                yaml.safe_dump(
                    data,
                    f,
                    default_flow_style=False,
                    sort_keys=False,
                    allow_unicode=True,
                )
