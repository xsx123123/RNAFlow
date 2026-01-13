# Rule for RNAFlow Data Delivery
# This rule executes the Rust-accelerated delivery tool to organize and transfer
# the analysis results to a final delivery directory.
import os

rule delivery:
    input:
        DataDeliver(config)
    output:
        out_dir = config['data_deliver'],
        manifest_json = os.path.join(config['data_deliver'],'delivery_manifest.json'),
        manifest_md5 = os.path.join(config['data_deliver'],'delivery_manifest.md5'),
        manifest_log = os.path.join(config['data_deliver'],'delivery_details.log'),
    resources:
        **rule_resource(config, 'high_resource',  skip_queue_on_local=True,logger = logger),
    conda:
        workflow.source_path("../envs/python3.yaml"),
    params:
        tool_path = config['parameter']['RNAFlow_Deliver_Tool']['path'],
        config_path = config['parameter']['RNAFlow_Deliver_Tool']['config_path'],
        python_lib = config['parameter']['RNAFlow_Deliver_Tool']['python'],
        source_dir = config['workflow'],
    log:
        "logs/delivery.log"
    benchmark:
        "benchmark/delivery.txt"
    shell:
        """
        # Set PYTHONPATH to include the tool's python library
        export PYTHONPATH=$PYTHONPATH:{params.python_lib}
        
        echo "Starting Data Delivery..." > {log}
        
        python3 {params.tool_path} deliver \
            --data-dir {params.source_dir} \
            --output-dir {output.out_dir} \
            --config {params.config_path} \
            >> {log} 2>&1
            
        echo "Delivery Complete. Check {output.manifest}" >> {log}
        """

rule generate_docker_json:
    input:
        manifest_json = os.path.join(config['data_deliver'],'delivery_manifest.json'),
        manifest_md5 = os.path.join(config['data_deliver'],'delivery_manifest.md5'),
        manifest_log = os.path.join(config['data_deliver'],'delivery_details.log'),
        sample_sheet = config['sample_csv']
    output:
        json_file = os.path.join(config['data_deliver'], "report_data/project_summary.json")
    params:
        client = config["client"],
        species = config["species"],
        Genome_Version = config["Genome_Version"], 
        pipeline_version = config["pipeline_version"],
        docker_prefix = "/data"
    run:
        df = pd.read_csv(input.sample_sheet)
        calculated_sample_count = len(df)
        calculated_group_count = df['group'].nunique()
        analysis_date = datetime.date.today().strftime("%Y-%m-%d")
        project_meta = {
            "client": params.client,
            "species": params.species,
            "genome_version": params.Genome_Version,
            "pipeline_version": params.pipeline_version,
            "analysis_date": analysis_date
        }
        stats = {
            "total_samples": int(calculated_sample_count),
            "group_count": int(calculated_group_count)
        }
        input_files = {
            "data_dir": f"{params.docker_prefix}/index/",
            "qc_file": f"{params.docker_prefix}/index/multiqc_qc_general_stats.txt",
            "mapping_file": f"{params.docker_prefix}/index/multiqc_mapping_general_stats.txt",
            "tpm_file": f"{params.docker_prefix}/index/merge_rsem_tpm.tsv",
            "sample_file": f"{params.docker_prefix}/index/sample.csv",
            "fastp_report_dir": f"{params.docker_prefix}/fastp_trim_report/multiqc_short_read_trim_report_data",
            "fastp_stats_file": f"{params.docker_prefix}/fastp_trim_report/multiqc_general_stats.txt",
            "fastq_screen_r1_dir": f"{params.docker_prefix}/fastq_screen_report/fastq_screen_multiqc_r1/multiqc_r1_fastq_screen_report_data",
            "fastq_screen_r2_dir": f"{params.docker_prefix}/fastq_screen_report/fastq_screen_multiqc_r2/multiqc_r2_fastq_screen_report_data",
            "qualimap_dir": f"{params.docker_prefix}/QualiMap/multiqc_data/",
            "contrasts_file": f"{params.docker_prefix}/index/contrasts.csv",
            "deg_dir": f"{params.docker_prefix}/res/DEG",
            "enrichment_dir": f"{params.docker_prefix}/res/Enrichments"
        }
        final_data = {
            "project_meta": project_meta,
            "stats": stats,
            "input_files": input_files
        }
        os.makedirs(os.path.dirname(output.json_file), exist_ok=True)
        with open(output.json_file, 'w', encoding='utf-8') as f:
            json.dump(final_data, f, indent=2, ensure_ascii=False)