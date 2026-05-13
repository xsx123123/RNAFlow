#!/usr/bin/env python3
# -*- coding: utf-8 -*-

rule build_index:
    input:
        gtf = config["Reference"]["data_dir"]["gtf"],
        fa = config["Reference"]["data_dir"]["fa"],
    output:
        STAR_index = f"{config['Reference']['info']['prefix']}/Genome",
        rsem_index_transcripts = f"{config['Reference']['info']['prefix']}/{config['Reference']['info']['prefix']}.transcripts.fa",
        rsem_index_idx = f"{config['Reference']['info']['prefix']}/{config['Reference']['info']['prefix']}.idx.fa",
    conda:
        workflow.source_path("../envs/rsem.yaml")
    log:
        "logs/01.build_index/build_index.log",
    message:
        "Building RSEM and STAR index with rsem-prepare-reference",
    benchmark:
        "benchmarks/01.build_index_benchmark.txt",
    params:
        prefix = f"{config['Reference']['info']['prefix']}/{config['Reference']['info']['prefix']}",
    threads:
        config["parameter"]["threads"]["build_index"]
    shell:
        """
        rsem-prepare-reference --gtf {input.gtf} \
                               -p {threads} \
                               {input.fa} \
                               {params.prefix} \
                               --star > {log} 2>&1
        """
