rule delivery:
    input:
        DataDeliver(config)
    output:
        report = "full_delivery/delivery_manifest.json",
        dir = directory("full_delivery")
    params:
        tool_path = "src/src/data-deliver/RNAFlow_Deliver_Tool/python/RNAFlow_Deliver/cli.py",
        config_path = "src/src/data-deliver/RNAFlow_Deliver_Tool/config/full_delivery_config.yaml"
    log:
        "logs/delivery.log"
    shell:
        ""
        export PYTHONPATH=$PYTHONPATH:src/src/data-deliver/RNAFlow_Deliver_Tool/python
        python3 {params.tool_path} deliver \
            -d . \
            -o {output.dir} \
            -c {params.config_path} > {log} 2>&1
        ""

