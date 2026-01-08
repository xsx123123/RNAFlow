
### install packages & plugin

snakemake version > 9.0

```bash
# install snakemake-executor-plugin-cluster-generic
pip install snakemake-executor-plugin-cluster-generic
```

### test snakefile file
```snakefile
# Snakefile

# 定义最终目标文件
rule all:
    input:
        "results/final_summary.txt"

# 步骤1：模拟一个耗时任务（测试并行投递）
# 我们设置了 memory 和 threads，看是否能传递给集群
rule step1_process:
    output:
        "results/part_{i}.txt"
    resources:
        mem_mb=1024,   # 申请 1GB 内存
        runtime=10     # 预计运行 10 分钟 (部分集群需要时间限制)
    threads: 1         # 申请 1 个 CPU
    shell:
        """
        echo "Running job {wildcards.i} on host: $(hostname)" > {output}
        sleep 5  # 模拟计算时间
        """

# 步骤2：汇总结果（测试依赖关系）
rule step2_summarize:
    input:
        expand("results/part_{i}.txt", i=[1, 2, 3])
    output:
        "results/final_summary.txt"
    resources:
        mem_mb=512
    threads: 1
    shell:
        """
        cat {input} > {output}
        echo "All done at $(date)" >> {output}
        """
```
### submit snakemake task
```bash
snakemake \
    --snakefile snakefile \
    --executor cluster-generic \
    --cluster-generic-submit-cmd \
      "dsub -n {rule}.{jobid} \
            -o logs_cluster/%J.out \
            -e logs_cluster/%J.err \
            -R 'cpu={threads},mem={resources.mem_mb}MB'" \
    --jobs 10 \
    --latency-wait 60
```