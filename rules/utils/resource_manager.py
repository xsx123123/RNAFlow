#!/usr/bin/env python3
"""
Resource Manager for RNAFlow Pipeline

This module provides utilities to manage resource configurations for different
rules in the Snakemake workflow. It allows defining named resource profiles
in the config and referencing them in rules using a simple function call.
"""

def rule_resource(config, profile_name, skip_queue_on_local=False, logger=None):
    """
    根据 Config 获取规则的资源配置。
    能够智能处理 "Local模式" 与 "用户指定Queue" 之间的配置冲突。
    """
    # 1. 获取 Queue Name (修复了 try-except 和 dafult 问题)
    # 如果 config 里没有 queue_id，这就返回 None。
    # None 在布尔判断中是 False，不会干扰后续逻辑。
    queue_name = config.get('queue_id') 

    # 2. 获取并校验 Profile
    cluster_config = config.get('cluster_config')
    if not cluster_config:
        error_msg = "Critical Config Error: 'cluster_config' section is missing. Please check your configuration file."
        if logger:
            logger.error(error_msg)
        raise ValueError(error_msg)

    resource_profiles = cluster_config.get('resource_profiles')
    if not resource_profiles:
        error_msg = "Critical Config Error: 'resource_profiles' is missing within 'cluster_config'. Please define resource profiles."
        if logger:
            logger.error(error_msg)
        raise ValueError(error_msg)

    if profile_name not in resource_profiles:
        available = list(resource_profiles.keys())
        error_msg = f"Resource profile '{profile_name}' not found in config. Available: {available}"
        if logger:
            logger.error(error_msg)
        raise ValueError(error_msg)

    profile = resource_profiles[profile_name].copy()

<<<<<<< HEAD
    execution_mode = config.get('execution_mode', {})
    current_cluster_name = cluster_config.get('current_cluster', {})
=======
    # 3. 判断运行环境
    # 使用 get 获取，若不存在则默认为 None
    execution_mode = config.get('execution_mode')
    current_cluster_name = cluster_config.get('queue_id')
>>>>>>> a377c2d87d6077037484e43892ebf81c823ea160
    
    is_local_execution = (execution_mode == 'local') or (current_cluster_name == 'default')

    if is_local_execution and skip_queue_on_local:
        if queue_name:
            if logger:
                logger.warning(
                    f"[Config Conflict] Execution mode is 'local', but a queue override ('{queue_name}') was provided. "
                    f"Ignored queue parameter to ensure local execution success."
                )
        else:
            if logger:
                logger.debug(f"Running locally. Stripping queue params for '{profile_name}'.")

        # 彻底移除队列参数
        profile.pop('queue', None)
        profile.pop('queue_type', None)
        return profile

    # 5. 集群模式处理
    # A. 优先使用用户在 Config 里显式指定的 queue_id
    if queue_name:
        # 只有当 queue_name 不为 None 时才进来，避免了把队列设为 "default" 字符串
        profile['queue'] = queue_name
    
    # B. 否则使用 profile 里的 queue_type 进行自动映射
    elif 'queue_type' in profile:
        clusters = cluster_config.get('clusters', {})
        current_cluster = clusters.get(current_cluster_name, clusters.get('default', {}))
        queues = current_cluster.get('queues', {})
        
        queue_key = profile['queue_type']
        if queue_key in queues:
            profile['queue'] = queues[queue_key]
            if logger:
                logger.debug(f"Mapped queue_type '{queue_key}' -> '{profile['queue']}'")
        else:
            if logger:
                logger.warning(f"Queue type '{queue_key}' not defined in cluster '{current_cluster_name}'. Job submits without explicit queue.")

    return profile