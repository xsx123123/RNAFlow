#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os

rule copy_reference_files:
    input:
        fa = config["Reference"]["data_dir"]["fa"],
        gtf = config["Reference"]["data_dir"]["gtf"],
        gff = config["Reference"]["data_dir"]["gff"],
        go = config["Reference"]["data_dir"]["go"],
    output:
        fa = os.path.basename(config["Reference"]["data_dir"]["fa"]),
        gtf = os.path.basename(config["Reference"]["data_dir"]["gtf"]),
        gff = os.path.basename(config["Reference"]["data_dir"]["gff"]),
        go = os.path.basename(config["Reference"]["data_dir"]["go"]),
    log:
        "logs/00.copy_reference/copy_reference_files.log",
    message:
        "Copying original reference files (fa, gtf, gff, go) to workflow directory",
    benchmark:
        "benchmarks/00.copy_reference_benchmark.txt",
    params:
        reference_dir = config["Reference"]["info"]["workflow"],
    shell:
        """
        cp -r {input.fa} {params.reference_dir} && \
        cp -r {input.gtf} {params.reference_dir} && \
        cp -r {input.gff} {params.reference_dir} && \
        cp -r {input.go} {params.reference_dir} > {log} 2>&1
        """
