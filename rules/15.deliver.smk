# Rule for RNAFlow Data Delivery
# This rule executes the Rust-accelerated delivery tool to organize and transfer
# the analysis results to a final delivery directory.
import os

rule delivery:
    input:
        DataDeliver(config)
    output:
        manifest = os.path.join(config['data_deliver'],'delivery_manifest.json'),
        manifest = os.path.join(config['data_deliver'],'delivery_manifest.md5'),
        manifest = os.path.join(config['data_deliver'],'delivery_details.log'),
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