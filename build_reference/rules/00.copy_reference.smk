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
    shell:
        """
        {{
            cp -r {input.fa} . && \
            cp -r {input.gtf} . && \
            cp -r {input.gff} . && \
            cp -r {input.go} .
        }} > {log} 2>&1
        """
