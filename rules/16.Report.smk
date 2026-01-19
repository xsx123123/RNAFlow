rule generate_docker_json:
    input:
        manifest_json = os.path.join(config['data_deliver'],'report_data','delivery_manifest.json'),
        manifest_md5 = os.path.join(config['data_deliver'],'report_data','delivery_manifest.md5'),
        manifest_log = os.path.join(config['data_deliver'],'report_data','delivery_details.log'),
        sample_sheet = config['sample_csv'],
    output:
        json_file = os.path.join(config['data_deliver'], "report_data/project_summary.json")
    resources:
        **rule_resource(config, 'low_resource',  skip_queue_on_local=True,logger = logger),
    conda:
        workflow.source_path("../envs/py3.12.yaml"),
    params:
        client = config["client"],
        species = config["species"],
        Genome_Version = config["Genome_Version"], 
        pipeline_version = config["pipeline_version"],
        docker_prefix = "/data"
    run:
        import pandas as pd
        import datetime  
        import json      
        import os        

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

rule Report:
    input:
        DataDeliver(config),
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
    log:
        "logs/Report.log",
    benchmark:
        "benchmark/Report.txt",
    threads:
        config['parameter']['threads']['Report'],
    shell:
        """
        ( 
        # 1. 创建输出目录
        mkdir -p {params.Report_dir} && \\
        
        # 2. 运行 Apptainer 容器
        # 使用 docker:// 协议直接加载 Docker 镜像，Apptainer 会自动处理转换和缓存
        # --cleanenv: 防止主机环境变量污染容器
        # --bind: 挂载目录 (Apptainer 默认读写挂载)
        
        apptainer run --cleanenv \\
               --bind {params.data_dir}:/data \\
               --bind {input.json_file}:/app/project_summary.json \\
               --bind {params.Report_dir}:/workspace/ \\
               docker://{params.docker_version}
        ) &>{log}
        """