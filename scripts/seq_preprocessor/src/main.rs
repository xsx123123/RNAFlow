use anyhow::{Context, Result};
// --- 新增：用于 CLI 参数枚举 ---
use clap::{Parser, ValueEnum};
use regex::Regex;
// --- 引入用于 JSON 序列化 ---
use serde::Serialize;
use std::collections::HashMap;
use std::fs;
// --- 修复 E0425 错误：引入 read_link ---
use std::fs::read_link;
use std::io::{BufRead, BufReader};
use std::path::PathBuf;
use walkdir::WalkDir;
// --- 引入 Unix 平台的 symlink ---
#[cfg(unix)]
use std::os::unix::fs::symlink;


/// (PE) 用于解析双端文件名的结构体
#[derive(Debug)]
struct SampleFileInfo {
    sample_name: String,
    read_pair: String, // "R1" 或 "R2"
    original_path: PathBuf,
    is_sra: bool, // 标记是否为 SRA 数据
}

// --- 新增：(SE) 用于解析单端文件名的结构体 ---
#[derive(Debug)]
struct SingleEndFileInfo {
    sample_name: String,
    original_path: PathBuf,
    is_sra: bool, // 标记是否为 SRA 数据
}

/// 用于生成 JSON 报告的结构体
// --- 修改：使报告结构更灵活，以同时支持 PE 和 SE ---
#[derive(Serialize, Debug)]
struct RenamingReportEntry {
    sample_name: String,
    library_type: String, // "PE" 或 "SE"

    // --- PE Fields (Optional) ---
    #[serde(skip_serializing_if = "Option::is_none")]
    new_r1_path_relative: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    new_r2_path_relative: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    original_r1_path_absolute: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    original_r2_path_absolute: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    md5_r1: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    md5_r2: Option<String>,

    // --- SE Fields (Optional) ---
    #[serde(skip_serializing_if = "Option::is_none")]
    new_se_path_relative: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    original_se_path_absolute: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    md5_se: Option<String>,
}

// --- 新增：定义 --library-type 的可选值 ---
#[derive(Copy, Clone, PartialEq, Eq, PartialOrd, Ord, ValueEnum, Debug)]
enum LibraryType {
    /// 仅处理双端 (PE) short-read 数据 (e.g., _R1/_R2)
    ShortRead,
    /// 仅处理单端 (SE) long-read 数据 (e.g., sample.fq.gz)
    LongRead,
    /// 自动检测并处理两种类型 (默认)
    Auto,
}


/// CLI 参数定义
#[derive(Parser, Debug)]
#[command(author, version, about, long_about = None)]
#[command(name = "seq_preprocessor")]
#[command(about = "自动整理不同来源的测序数据（支持Short-read和Long-read），统一命名和目录结构。")]
struct Cli {
    /// 原始数据所在的根目录路径 (可指定一个或多个)
    #[arg(short, long, num_args = 1..)] // 允许 1 个或多个参数
    input: Vec<PathBuf>, // 类型从 PathBuf 变为 Vec<PathBuf>

    /// 整理后数据的输出目录路径
    #[arg(short, long)]
    output: PathBuf,

    /// 指定在每个样本文件夹中生成的 MD5 文件的名称
    #[arg(long, default_value = "md5.txt")]
    md5_name: String,

    /// 在输出目录顶层生成一个包含所有文件信息的总 MD5 文件。
    /// 例如: --summary-md5 checksums.txt
    #[arg(long)]
    summary_md5: Option<PathBuf>,

    /// 一个开关，用于禁止在每个样本子目录中创建独立的 MD5 文件。
    #[arg(long)]
    no_per_sample_md5: bool,
    
    /// 生成一个 JSON 格式的重命名报告文件。
    #[arg(long)]
    json_report: Option<PathBuf>,

    // --- 新增：指定文库类型参数 ---
    /// 指定要处理的文库类型
    #[arg(long, value_enum, default_value_t = LibraryType::Auto)]
    library_type: LibraryType,
}

fn main() -> Result<()> {
    let cli = Cli::parse();

    // 准备输出目录
    fs::create_dir_all(&cli.output).context(format!("无法创建输出目录: {}", cli.output.display()))?;

    // 1. 收集所有 FASTQ 和 MD5 文件信息
    // --- 修改：区分 PE 和 SE 文件列表 ---
    let mut pe_fastq_files: Vec<SampleFileInfo> = Vec::new();
    let mut se_fastq_files: Vec<SingleEndFileInfo> = Vec::new();
    let mut md5_files: Vec<PathBuf> = Vec::new();
    let mut unmatched_fastq_files: Vec<PathBuf> = Vec::new();

    // --- (PE) 两个独立的、更简单的正则表达式 ---
    let re_illumina = Regex::new(r"^(.*?)_S\d+_L\d+_([Rr][12])_\d+\.f(ast)?q\.gz$").unwrap();
    let re_generic = Regex::new(r"^(.*)[\._]([Rr][12]|[12])\.f(ast)?q\.gz$").unwrap();
    // --- 新增：(SE) 用于匹配 Long-read 的正则表达式 ---
    let re_long_read = Regex::new(r"^(.*?)(\.f(ast)?q\.gz)$").unwrap();
    // --- 新增：(SRA) 用于匹配 SRA 数据的正则表达式 ---
    let re_sra_pe = Regex::new(r"^([SED]RR\d+)[\._]([12])\.f(ast)?q\.gz$").unwrap();  // SRR######_1.fq.gz, ERR######_1.fq.gz, DRR######_1.fq.gz
    let re_sra_single = Regex::new(r"^([SED]RR\d+)\.f(ast)?q\.gz$").unwrap();  // SRR#######.fq.gz, ERR#######.fq.gz, DRR#######.fq.gz


    // --- 遍历所有传入的 input 路径 ---
    for input_path in &cli.input {
        
        // 检查路径是否存在 (移到循环内部)
        if !input_path.exists() {
            anyhow::bail!("输入路径不存在: {}", input_path.display());
        }
        println!("- 开始扫描输入目录: {}", input_path.display());

        // WalkDir 现在使用 input_path
        for entry in WalkDir::new(input_path).into_iter().filter_map(|e| e.ok()) {
            let path = entry.path();
            if path.is_file() {
                let file_name = match path.file_name().and_then(|s| s.to_str()) {
                    Some(name) => name,
                    None => continue,
                };

                let mut matched = false;

                // --- 修改：分层匹配逻辑，基于 library_type ---

                // 1. 尝试匹配 PE (SRA format) - Check SRA first to avoid conflicts with generic pattern
                if !matched && (cli.library_type == LibraryType::Auto || cli.library_type == LibraryType::ShortRead) {
                    if let Some(caps) = re_sra_pe.captures(file_name) {
                        if let (Some(accession), Some(pair_cap)) = (caps.get(1), caps.get(2)) {
                            let read_pair = match pair_cap.as_str() {
                                "1" => "R1".to_string(),
                                "2" => "R2".to_string(),
                                _ => unreachable!(),
                            };
                            pe_fastq_files.push(SampleFileInfo {
                                sample_name: accession.as_str().to_string(),
                                read_pair,
                                original_path: path.to_path_buf(),
                                is_sra: true, // SRA data
                            });
                            matched = true;
                        }
                    }
                }

                // 2. 尝试匹配 PE (Illumina)
                if !matched && (cli.library_type == LibraryType::Auto || cli.library_type == LibraryType::ShortRead) {
                    if let Some(caps) = re_illumina.captures(file_name) {
                        if let (Some(sample), Some(pair_cap)) = (caps.get(1), caps.get(2)) {
                            let read_pair = if pair_cap.as_str().to_lowercase() == "r1" { "R1" } else { "R2" }.to_string();
                            pe_fastq_files.push(SampleFileInfo {
                                sample_name: sample.as_str().to_string(),
                                read_pair,
                                original_path: path.to_path_buf(),
                                is_sra: false, // Not SRA data
                            });
                            matched = true;
                        }
                    }
                }

                // 3. 尝试匹配 PE (Generic) - Check this last to avoid conflicts with more specific patterns
                if !matched && (cli.library_type == LibraryType::Auto || cli.library_type == LibraryType::ShortRead) {
                     if let Some(caps) = re_generic.captures(file_name) {
                        if let (Some(sample), Some(pair_cap)) = (caps.get(1), caps.get(2)) {
                            let read_pair = match pair_cap.as_str().to_lowercase().as_str() {
                                "r1" | "1" => "R1".to_string(),
                                "r2" | "2" => "R2".to_string(),
                                _ => unreachable!(),
                            };
                            pe_fastq_files.push(SampleFileInfo {
                                sample_name: sample.as_str().to_string(),
                                read_pair,
                                original_path: path.to_path_buf(),
                                is_sra: false, // Not SRA data
                            });
                            matched = true;
                        }
                    }
                }

                // 4. 尝试匹配 SE (SRA format) - Check SRA first to avoid conflicts with generic pattern
                if !matched && (cli.library_type == LibraryType::Auto || cli.library_type == LibraryType::LongRead) {
                    if file_name.ends_with(".fq.gz") || file_name.ends_with(".fastq.gz") {
                        if let Some(caps) = re_sra_single.captures(file_name) {
                            if let Some(accession) = caps.get(1) {
                                se_fastq_files.push(SingleEndFileInfo {
                                    sample_name: accession.as_str().to_string(),
                                    original_path: path.to_path_buf(),
                                    is_sra: true, // SRA data
                                });
                                matched = true;
                            }
                        }
                    }
                }

                // 5. 尝试匹配 SE (Long-Read)
                if !matched && (cli.library_type == LibraryType::Auto || cli.library_type == LibraryType::LongRead) {
                    // 使用 re_long_read 匹配 (注意：这会匹配所有 .fq.gz，因此必须在 PE 匹配失败后运行)
                    if file_name.ends_with(".fq.gz") || file_name.ends_with(".fastq.gz") {
                         if let Some(caps) = re_long_read.captures(file_name) {
                            if let Some(sample) = caps.get(1) {
                                se_fastq_files.push(SingleEndFileInfo {
                                    sample_name: sample.as_str().to_string(),
                                    original_path: path.to_path_buf(),
                                    is_sra: false, // Not SRA data
                                });
                                matched = true;
                            }
                         }
                    }
                }
                
                // 4. 处理未匹配或 MD5
                if !matched {
                    if file_name.ends_with(".fq.gz") || file_name.ends_with(".fastq.gz") {
                        unmatched_fastq_files.push(path.to_path_buf());
                    } else if file_name.to_lowercase().contains("md5") && file_name.ends_with(".txt") {
                        md5_files.push(path.to_path_buf());
                    }
                }
            }
        } // --- WalkDir 循环结束 ---
    } // --- 遍历 input 路径的循环结束 ---


    // --- 修改：错误信息根据所选模式动态生成 ---
    if !unmatched_fastq_files.is_empty() {
        let mut error_message =
            "错误：发现以下 FASTQ 文件命名不符合预期的模式，请检查或修正文件名:\n".to_string();
        for path in unmatched_fastq_files {
            error_message.push_str(&format!("  - {}\n", path.display()));
        }
        error_message.push_str("\n根据您选择的 --library-type 模式，预期的模式为: \n");
        if cli.library_type == LibraryType::Auto || cli.library_type == LibraryType::ShortRead {
            error_message.push_str("  1. PE 模式 (Illumina): <样本名>_S..._L..._R[12]_...fq.gz\n");
            error_message.push_str("  2. PE 模式 (Generic): <样本名>[._][R12|12].fq.gz\n");
            error_message.push_str("  3. PE 模式 (SRA): [SED]RR#######[._][12].fq.gz (e.g., SRR######_1.fq.gz)\n");
        }
        if cli.library_type == LibraryType::Auto || cli.library_type == LibraryType::LongRead {
            error_message.push_str("  4. SE 模式: <样本名>.fq.gz (且不符合上述 PE 模式)\n");
            error_message.push_str("  5. SE 模式 (SRA): [SED]RR#######.fq.gz (e.g., SRR#######.fq.gz)\n");
        }
        anyhow::bail!(error_message);
    }

    // --- 修改：更新扫描完成的日志 ---
    println!(
        "- 扫描完成: 找到 {} 个 PE 文件, {} 个 SE 文件, {} 个 MD5 文件。", 
        pe_fastq_files.len(), 
        se_fastq_files.len(), 
        md5_files.len()
    );
    
    // 2. 解析所有 MD5 文件
    let mut checksum_map: HashMap<String, String> = HashMap::new();
    println!("- 开始解析 MD5 文件...");
    for md5_file_path in &md5_files {
        let file = fs::File::open(md5_file_path)?;
        let reader = BufReader::new(file);
        for line in reader.lines().filter_map(|l| l.ok()) {
            let parts: Vec<&str> = line.split_whitespace().collect();
            if parts.len() < 2 { continue; }
            let checksum = parts[0].to_string();
            // 修复：确保从 MD5.txt 中提取的是纯文件名
            let original_filename = PathBuf::from(parts[1])
                .file_name()
                .unwrap_or_default()
                .to_string_lossy()
                .to_string();
            if !original_filename.is_empty() {
                checksum_map.insert(original_filename, checksum);
            }
        }
    }
    println!("- MD5 解析完成，共加载 {} 条记录。", checksum_map.len());


    // 3. 组织 PE (Short-Read) 样本
    // --- 修改：重命名 `samples` -> `pe_samples` ---
    let mut pe_samples: HashMap<String, (Option<PathBuf>, Option<PathBuf>, bool, bool)> = HashMap::new(); // (r1_path, r2_path, is_r1_sra, is_r2_sra)
    for file_info in &pe_fastq_files {
        let entry = pe_samples.entry(file_info.sample_name.clone()).or_insert((None, None, false, false));
        if file_info.read_pair == "R1" {
            entry.0 = Some(file_info.original_path.clone());
            entry.2 = file_info.is_sra; // Mark R1 as SRA if applicable
        } else if file_info.read_pair == "R2" {
            entry.1 = Some(file_info.original_path.clone());
            entry.3 = file_info.is_sra; // Mark R2 as SRA if applicable
        }
    }

    // --- 修改：更新日志 ---
    println!("- 已将 PE 文件整理为 {} 个独立样本。", pe_samples.len());
    println!("- 已找到 {} 个 SE 样本。", se_fastq_files.len());
    
    // 准备报告和总 MD5
    let mut summary_md5_lines: Vec<String> = Vec::new();
    let mut json_report_entries: Vec<RenamingReportEntry> = Vec::new();

    // --- 4. 准备文件处理辅助函数 ---
    // --- 新增：将文件处理逻辑提取为辅助函数，以便 PE 和 SE 都能调用 ---
    
    #[cfg(unix)]
    /// (Unix) 辅助函数：处理单个文件（R1, R2, 或 SE），创建或验证软链接
    fn process_file_link(
        new_path: &PathBuf, 
        original_path: &PathBuf, 
        read_name: &str, // "R1", "R2", "SE"
        sample_name: &str,
    ) -> Result<()> {
        if new_path.exists() {
            match read_link(new_path) { 
                Ok(target) => {
                    if target == *original_path {
                        println!("    - 文件 {} ({}) 已存在且指向正确，跳过。", new_path.file_name().unwrap_or_default().to_string_lossy(), read_name);
                        return Ok(());
                    } else {
                        println!("    - 文件 {} ({}) 存在但指向错误 (当前: {}，应为: {}), 正在删除并重建...",
                            new_path.file_name().unwrap_or_default().to_string_lossy(),
                            read_name,
                            target.display(),
                            original_path.display()
                        );
                        fs::remove_file(new_path).context(format!("无法删除旧文件/链接: {}", new_path.display()))?;
                    }
                },
                Err(_) => {
                    // 不是软链接，或者读取失败（例如是普通文件），先删除
                    println!("    - 文件 {} ({}) 存在但不是有效软链接，正在删除并重建...", 
                        new_path.file_name().unwrap_or_default().to_string_lossy(),
                        read_name,
                    );
                    fs::remove_file(new_path).context(format!("无法删除旧文件: {}", new_path.display()))?;
                }
            }
        }
        
        // 创建新的软链接
        symlink(original_path, new_path)
            .context(format!("无法为样本 {} 创建软链接 {}: {}", sample_name, read_name, new_path.display()))?;
        println!("    - 成功创建软链接 {}: {}", read_name, new_path.file_name().unwrap_or_default().to_string_lossy());
        Ok(())
    }

    #[cfg(not(unix))]
    /// (Non-Unix) 辅助函数：处理单个文件（R1, R2, 或 SE），复制文件
    fn process_file_copy(
        new_path: &PathBuf, 
        original_path: &PathBuf, 
        read_name: &str, // "R1", "R2", "SE"
        _sample_name: &str, // _sample_name 变为未使用，但保持签名一致
    ) -> Result<()> {
         if new_path.exists() {
             println!("    - 文件 {} ({}) 已存在（非Unix，可能是复制），跳过复制。", new_path.file_name().unwrap_or_default().to_string_lossy(), read_name);
         } else {
             fs::copy(original_path, new_path)
                .context(format!("无法复制文件: {}", new_path.display()))?;
             println!("    - 成功复制文件 {}: {}", read_name, new_path.file_name().unwrap_or_default().to_string_lossy());
         }
         Ok(())
    }
    // --- 辅助函数定义结束 ---


    // 5. 处理 PE (Short-Read) 样本
    // --- 修改：循环 `pe_samples` ---
    for (sample_name, (r1_opt, r2_opt, is_r1_sra, is_r2_sra)) in pe_samples {
        println!("  - 正在处理 PE 样本: {}", sample_name);

        let (original_r1, original_r2) = match (r1_opt, r2_opt) {
            (Some(r1), Some(r2)) => (r1, r2),
            _ => {
                eprintln!("  ! 警告: 样本 {} 缺少 R1 或 R2 文件，已跳过。", sample_name);
                continue;
            }
        };

        let sample_output_dir = cli.output.join(&sample_name);
        fs::create_dir_all(&sample_output_dir)
            .context(format!("无法为样本 {} 创建目录", sample_name))?;

        let new_r1_name = format!("{}_R1.fq.gz", sample_name);
        let new_r2_name = format!("{}_R2.fq.gz", sample_name);
        let new_r1_path = sample_output_dir.join(&new_r1_name);
        let new_r2_path = sample_output_dir.join(&new_r2_name);

        // --- 修改：使用辅助函数处理文件 ---
        #[cfg(unix)]
        {
            process_file_link(&new_r1_path, &original_r1, "R1", &sample_name)?;
            process_file_link(&new_r2_path, &original_r2, "R2", &sample_name)?;
        }
        #[cfg(not(unix))]
        {
            process_file_copy(&new_r1_path, &original_r1, "R1", &sample_name)?;
            process_file_copy(&new_r2_path, &original_r2, "R2", &sample_name)?;
        }
        // --- 文件处理逻辑结束 ---


        let original_r1_filename = original_r1.file_name().unwrap().to_str().unwrap();
        let original_r2_filename = original_r2.file_name().unwrap().to_str().unwrap();

        // 如果是 SRA 数据，使用 "SRA" 作为 MD5 值，否则使用从 checksum_map 获取的值
        let checksum_r1 = if is_r1_sra {
            Some("SRA".to_string())
        } else {
            checksum_map.get(original_r1_filename).cloned()
        };
        let checksum_r2 = if is_r2_sra {
            Some("SRA".to_string())
        } else {
            checksum_map.get(original_r2_filename).cloned()
        };

        if !cli.no_per_sample_md5 {
            let mut per_sample_md5_content = String::new();
            if let Some(c) = &checksum_r1 { per_sample_md5_content.push_str(&format!("{}  {}\n", c, new_r1_name)); }
            if let Some(c) = &checksum_r2 { per_sample_md5_content.push_str(&format!("{}  {}\n", c, new_r2_name)); }

            if !per_sample_md5_content.is_empty() {
                let per_sample_md5_path = sample_output_dir.join(&cli.md5_name);
                fs::write(&per_sample_md5_path, per_sample_md5_content)
                    .context(format!("无法写入样本 MD5 文件: {}", per_sample_md5_path.display()))?;
                println!("    - 已生成样本 MD5 文件: {}", cli.md5_name);
            }
        }
        
        let relative_r1_path = PathBuf::from(&sample_name).join(&new_r1_name);
        let relative_r2_path = PathBuf::from(&sample_name).join(&new_r2_name);
        if let Some(c) = &checksum_r1 { summary_md5_lines.push(format!("{}  {}", c, relative_r1_path.display())); }
        if let Some(c) = &checksum_r2 { summary_md5_lines.push(format!("{}  {}", c, relative_r2_path.display())); }
        
        // --- 修改：填充 JSON 报告条目 (PE) ---
        if cli.json_report.is_some() {
            json_report_entries.push(RenamingReportEntry {
                sample_name: sample_name.clone(),
                library_type: "PE".to_string(),

                new_r1_path_relative: Some(relative_r1_path.to_string_lossy().to_string()),
                original_r1_path_absolute: Some(fs::canonicalize(&original_r1)?.to_string_lossy().to_string()),
                new_r2_path_relative: Some(relative_r2_path.to_string_lossy().to_string()),
                original_r2_path_absolute: Some(fs::canonicalize(&original_r2)?.to_string_lossy().to_string()),
                md5_r1: checksum_r1,
                md5_r2: checksum_r2,

                new_se_path_relative: None,
                original_se_path_absolute: None,
                md5_se: None,
            });
        }
    } // --- PE 循环结束 ---
    

    // --- 6. 新增：处理 SE (Long-Read) 样本 ---
    for se_file_info in &se_fastq_files {
        let sample_name = &se_file_info.sample_name;
        let original_path = &se_file_info.original_path;
        let is_se_sra = se_file_info.is_sra; // Store whether this is SRA data
        println!("  - 正在处理 SE 样本: {}", sample_name);

        let sample_output_dir = cli.output.join(sample_name);
        fs::create_dir_all(&sample_output_dir)
            .context(format!("无法为 SE 样本 {} 创建目录", sample_name))?;

        // --- SE 命名：直接使用 <样本名>.fq.gz (例如 DR_CK.fq.gz) ---
        let new_se_name = format!("{}.fq.gz", sample_name);
        let new_se_path = sample_output_dir.join(&new_se_name);

        // --- 使用辅助函数处理文件 ---
        #[cfg(unix)]
        {
            process_file_link(&new_se_path, original_path, "SE", sample_name)?;
        }
        #[cfg(not(unix))]
        {
            process_file_copy(&new_se_path, original_path, "SE", sample_name)?;
        }

        // --- MD5 和报告 ---
        let original_se_filename = original_path.file_name().unwrap().to_str().unwrap();

        // 如果是 SRA 数据，使用 "SRA" 作为 MD5 值，否则使用从 checksum_map 获取的值
        let checksum_se = if is_se_sra {
            Some("SRA".to_string())
        } else {
            checksum_map.get(original_se_filename).cloned()
        };

        if !cli.no_per_sample_md5 {
            let mut per_sample_md5_content = String::new();
            if let Some(c) = &checksum_se { 
                per_sample_md5_content.push_str(&format!("{}  {}\n", c, new_se_name)); 
            }

            if !per_sample_md5_content.is_empty() {
                let per_sample_md5_path = sample_output_dir.join(&cli.md5_name);
                fs::write(&per_sample_md5_path, per_sample_md5_content)
                    .context(format!("无法写入 SE 样本 MD5 文件: {}", per_sample_md5_path.display()))?;
                println!("    - 已生成样本 MD5 文件: {}", cli.md5_name);
            }
        }
        
        let relative_se_path = PathBuf::from(sample_name).join(&new_se_name);
        if let Some(c) = &checksum_se { 
            summary_md5_lines.push(format!("{}  {}", c, relative_se_path.display())); 
        }
        
        // --- 填充 JSON 报告条目 (SE) ---
        if cli.json_report.is_some() {
            json_report_entries.push(RenamingReportEntry {
                sample_name: sample_name.clone(),
                library_type: "SE".to_string(),
                
                new_r1_path_relative: None,
                original_r1_path_absolute: None,
                new_r2_path_relative: None,
                original_r2_path_absolute: None,
                md5_r1: None,
                md5_r2: None,

                new_se_path_relative: Some(relative_se_path.to_string_lossy().to_string()),
                original_se_path_absolute: Some(fs::canonicalize(original_path)?.to_string_lossy().to_string()),
                md5_se: checksum_se,
            });
        }
    } // --- SE 循环结束 ---


    // 7. 生成总纲 MD5 和 JSON 报告 (此部分无需修改)
    if let Some(summary_md5_filename) = &cli.summary_md5 {
        let summary_path = cli.output.join(summary_md5_filename);
        if !summary_md5_lines.is_empty() {
            summary_md5_lines.sort(); // 确保 MD5 文件顺序一致
            let final_content = summary_md5_lines.join("\n") + "\n";
            fs::write(&summary_path, final_content)
                .context(format!("无法写入总纲 MD5 文件: {}", summary_path.display()))?;
            println!("\n- 成功生成总纲 MD5 文件于: {}", summary_path.display());
        } else {
            println!("\n- 未找到任何 MD5 信息，因此未生成总纲 MD5 文件。");
        }
    }
    
    // --- 在所有样本处理完后，写入 JSON 报告文件 ---
    if let Some(report_path) = &cli.json_report {
        if !json_report_entries.is_empty() {
            println!("\n- 正在生成 JSON 报告文件...");
            // 使用 serde_json 将数据结构转换为格式化的 JSON 字符串
            let report_json = serde_json::to_string_pretty(&json_report_entries)?;
            fs::write(report_path, report_json)
                .context(format!("无法写入 JSON 报告文件: {}", report_path.display()))?;
            println!("- 成功生成 JSON 报告文件于: {}", report_path.display());
        } else {
             println!("\n- 未找到任何样本，因此未生成 JSON 报告文件。");
        }
    }

    println!("\n- 所有任务完成！标准化的数据已存放于: {}", cli.output.display());
    println!("- 提示: 脚本默认在 Unix 系统上使用软链接（symlink）来指向原始文件，这不会消耗额外磁盘空间。");
    println!("- 提示: 支持处理来自不同来源的数据，包括 Illumina, Generic, 和 SRA (SRR/ERR/DRR) 格式。");

    Ok(())
}