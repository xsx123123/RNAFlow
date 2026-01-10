#!/usr/bin/env python3
"""
Resource Manager for RNAFlow Pipeline

This module provides utilities to manage resource configurations for different
rules in the Snakemake workflow. It allows defining named resource profiles
in the config and referencing them in rules using a simple function call.
"""

def rule_resource(config, profile_name, queue_name=None, skip_queue_on_local=False, logger=None):
    """
    根据 Config 获取规则的资源配置。
    能够智能处理 "Local模式" 与 "用户指定Queue" 之间的配置冲突。
    """
    # 2. 获取并校验 Profile
    cluster_config = config.get('cluster_config', {})
    resource_profiles = cluster_config.get('resource_profiles', {})

    if profile_name not in resource_profiles:
        # 找不到 Profile 就报错，防止后续逻辑混乱
        available = list(resource_profiles.keys())
        error_msg = f"Resource profile '{profile_name}' not found in config. Available: {available}"
        logger.error(error_msg)
        raise ValueError(error_msg)

    profile = resource_profiles[profile_name].copy()

    # 3. 判断运行环境 (核心逻辑)
    execution_mode = config.get('execution_mode', {})
    current_cluster_name = cluster_config.get('current_cluster', {})
    
    # 只要 mode 是 local，或者集群配置是指向 default (通常指本地)，就视为本地执行
    is_local_execution = (execution_mode == 'local') or (current_cluster_name == 'default')

    # 4. 【关键更新】本地模式下的智能清洗逻辑
    if is_local_execution and skip_queue_on_local:
        # 场景：用户在 config 里填了 queue_id="fat_x86"，但 mode="local"
        if queue_name:
            logger.warning(
                f"[Config Conflict] Execution mode is 'local', but a queue override ('{queue_name}') was provided. "
                f"Ignored queue parameter to ensure local execution success."
            )
        else:
            logger.debug(f"Running locally. Stripping queue params for '{profile_name}'.")

        # 彻底移除队列参数，保证本地运行不报错
        profile.pop('queue', None)
        profile.pop('queue_type', None)
        return profile

    # 5. 集群模式处理
    # 如果代码走到这里，说明是 Cluster 模式，必须处理队列

    # A. 优先使用传入的 queue_name (对应 config 里的 queue_id)
    if queue_name:
        # logger.info(f"Using explicit queue override: '{queue_name}' for rule profile '{profile_name}'")
        profile['queue'] = queue_name
    
    # B. 否则使用 profile 里的 queue_type 进行映射
    elif 'queue_type' in profile:
        clusters = cluster_config.get('clusters', {})
        current_cluster = clusters.get(current_cluster_name, clusters.get('default', {}))
        queues = current_cluster.get('queues', {})
        
        queue_key = profile['queue_type']
        if queue_key in queues:
            profile['queue'] = queues[queue_key]
            logger.debug(f"Mapped queue_type '{queue_key}' -> '{profile['queue']}'")
        else:
            # 这是一个值得注意的警告，可能是配置写漏了
            logger.warning(f"Queue type '{queue_key}' not defined in cluster '{current_cluster_name}'. Job submits without explicit queue.")

    return profile