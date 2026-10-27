#!/usr/bin/snakemake
# -*- coding: utf-8 -*-
"""
RNAFlow Pipeline - Project Result Export and Deprecated HTML Renderer

generate_docker_json exports the versioned result document for external consumers.
Report retains the legacy containerized HTML renderer, disabled by default and not
adapted to the v2 result contract.
"""

rule generate_docker_json:
    """
    Export the versioned project result JSON independently of HTML rendering.

    Emits the BioReport 2.1.0 delivery contract: project metadata with platform
    user/task binding, a semantic file index, and GO/KEGG tables indexed by
    contrast and direction. Paths are relative to this JSON file; complete
    result rows remain in CSV/TSV files. The historical rule name is retained
    for explicit Snakemake target compatibility.
    """
    input:
        manifest_json = os.path.join(config['data_deliver'],'report_data','delivery_manifest.json'),
        manifest_md5 = os.path.join(config['data_deliver'],'report_data','delivery_manifest.md5'),
        manifest_log = os.path.join(config['data_deliver'],'report_data','delivery_details.log'),
        sample_sheet = config['sample_csv'],
        summary_builder = workflow.source_path('utils/project_summary.py'),
        summary_schema = workflow.source_path('../schema/project_summary.schema.json'),
    output:
        json_file = os.path.join(config['data_deliver'], "report_data/project_summary.json")
    resources:
        **rule_resource(config, 'low_resource',  skip_queue_on_local=True,logger = logger),
    conda:
        workflow.source_path("../envs/py3.12.yaml"),
    params:
        summary_config = {
            key: config[key] for key in (
                'project_id', 'project_name', 'client', 'species', 'Genome_Version',
                'pipeline_version', 'parameter', 'deg_enrich_wrapper', 'deg', 'only_qc',
                'analysis_date', 'report_date', 'software_versions', 'analysis', 'platform',
            ) if key in config
        },
        contrasts = ALL_CONTRASTS,
        data_dir = os.path.join(config['data_deliver'], 'report_data', 'data'),
    run:
        import json
        import os
        from jsonschema import Draft202012Validator, FormatChecker
        from rules.utils.project_summary import build_project_summary

        final_data = build_project_summary(
            params.summary_config, input.sample_sheet, params.data_dir, params.contrasts,
        )
        with open(input.summary_schema, encoding='utf-8') as schema_file:
            summary_schema = json.load(schema_file)
        Draft202012Validator(summary_schema, format_checker=FormatChecker()).validate(final_data)
        os.makedirs(os.path.dirname(output.json_file), exist_ok=True)
        with open(output.json_file, 'w', encoding='utf-8') as f:
            json.dump(final_data, f, indent=2, ensure_ascii=False, allow_nan=False)
rule Report:
    """
    Generate the final interactive HTML report using a containerized Quarto application.

    This rule executes the final report generation by running a Docker container
    directly. The containerized approach ensures consistent report generation
    across different computing environments and eliminates dependency conflicts.

    Key features of the reporting system:
    - Interactive HTML interface with dynamic data visualization
    - Comprehensive integration of all analysis modules (QC, DEG, enrichment, AS, variants)
    - Responsive design suitable for both desktop and mobile viewing
    - Export capabilities for figures and tables
    - Reproducible report generation using container technology

    Container execution details:
    - Uses docker run with --rm flag to automatically clean up the container after execution
    - Mounts the report data directory to /data inside the container using -v
    - Mounts the project summary JSON configuration to /app/project_summary.json
    - Mounts the output report directory to /workspace/ for result storage
    - Uses the specified local Docker image directly

    The final output is a self-contained HTML report with embedded JavaScript
    visualizations that can be easily shared with collaborators or uploaded to
    web servers for remote access.
    """
    input:
        ANALYSIS_TARGETS,
        json_file = os.path.join(config['data_deliver'], "report_data/project_summary.json"),
        manifest_json = os.path.join(config['data_deliver'],'report_data','delivery_manifest.json'),
        manifest_md5 = os.path.join(config['data_deliver'],'report_data','delivery_manifest.md5'),
        manifest_log = os.path.join(config['data_deliver'],'report_data','delivery_details.log'),
    output:
        Report_html =  os.path.join(config['data_deliver'], "Analysis_Report/index.html")
    resources:
        **rule_resource(config, 'high_resource',  skip_queue_on_local=True,logger = logger),
    conda:
        workflow.source_path("../envs/py3.12.yaml"),
    params:
        data_dir = os.path.join(config['data_deliver'],'report_data','data'),
        Report_dir = os.path.join(config['data_deliver'], "Analysis_Report"),
        docker_version = config['parameter']['Report']['docker_version'],
        report_engine = config.get('report_engine', 'auto'),
    log:
        "logs/Report.log",
    benchmark:
        "benchmark/Report.txt",
    threads:
        config['parameter']['threads']['Report'],
    shell:
        """
        (
        IMAGE_NAME={params.docker_version}
        ENGINE={params.report_engine}
        mkdir -p {params.Report_dir}

        if [ "$ENGINE" = "auto" ]; then
            if command -v docker >/dev/null 2>&1; then
                ENGINE=docker
            elif command -v apptainer >/dev/null 2>&1; then
                ENGINE=apptainer
            elif command -v singularity >/dev/null 2>&1; then
                ENGINE=singularity
            else
                echo "No supported report container engine found (docker/apptainer/singularity)."
                exit 1
            fi
        fi

        case "$ENGINE" in
            docker)
                if ! docker image inspect "$IMAGE_NAME" >/dev/null 2>&1; then
                    echo "Report image not found: $IMAGE_NAME"
                    exit 1
                fi
                docker run --rm --user $(id -u):$(id -g) \
                    -e ARK_API_KEY -e DASHSCOPE_API_KEY -e OPENAI_API_KEY \
                    -v {params.data_dir}:/data:rw \
                    -v {params.Report_dir}:/workspace:rw \
                    -v {input.json_file}:/app/project_summary.json:ro \
                    "$IMAGE_NAME"
                ;;
            apptainer|singularity)
                "$ENGINE" run --containall \
                    --bind {params.data_dir}:/data \
                    --bind {params.Report_dir}:/workspace \
                    --bind {input.json_file}:/app/project_summary.json:ro \
                    "docker://$IMAGE_NAME"
                ;;
            *)
                echo "Unsupported report_engine: $ENGINE"
                exit 1
                ;;
        esac
        ) &> {log}
        """
