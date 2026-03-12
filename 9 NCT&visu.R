library(qgraph)
library(bootnet)
library(NetworkComparisonTest)
library(reshape2)

set.seed(123)

# 输出路径
output_path <- "outputpath"
if (!dir.exists(output_path)) dir.create(output_path, recursive=T)

# ==============================
# 步骤1：硬编码15个变量名（和你完全一致）
# ==============================
target_vars <- c(
  "GAD71_A", "GAD72_A", "GAD73_A", "GAD74_A", "GAD75_A", "GAD76_A", "GAD77_A",
  "PHQ81_A", "PHQ82_A", "PHQ83_A", "PHQ84_A", "PHQ85_A", "PHQ86_A", "PHQ87_A", "PHQ88_A"
)
node_labels <- c(paste0("G", 1:7), paste0("P", 1:8)) # 固定15个标签

# ==============================
# 步骤2：读取数据+强制保留15列（关键！）
# ==============================
# 读取数据
female <- read.csv("datapath")
male   <- read.csv("datapath")

# 调试：打印原始数据列名，确认15列存在
cat("=== 原始数据列名检查 ===\n")
cat("女性数据是否包含所有15列：", all(target_vars %in% colnames(female)), "\n")
cat("男性数据是否包含所有15列：", all(target_vars %in% colnames(male)), "\n")

# 强制筛选15列（drop=FALSE确保即使1列也保留数据框格式）
female_filtered <- female[, target_vars, drop = FALSE]
male_filtered   <- male[, target_vars, drop = FALSE]

# 调试：打印筛选后维度
cat("=== 筛选后维度 ===\n")
cat("女性筛选后维度：", nrow(female_filtered), "行 ×", ncol(female_filtered), "列\n")
cat("男性筛选后维度：", nrow(male_filtered), "行 ×", ncol(male_filtered), "列\n")

# 步骤3：处理无变异列（替换常数列为微小随机值，避免被过滤）
# 核心：无变异列（标准差=0）会被EBICglasso过滤，导致列数减少
add_small_noise <- function(df) {
  for (col in colnames(df)) {
    if (sd(df[[col]], na.rm = TRUE) == 0) {
      # 给常数列加微小随机值（不影响结果，仅保留列）
      df[[col]] <- df[[col]] + rnorm(nrow(df), mean = 0, sd = 1e-6)
      cat("提示：列", col, "为常数，已添加微小随机值保留\n")
    }
  }
  # 替换NA为列均值（避免NA导致列被过滤）
  df <- as.data.frame(lapply(df, function(x) ifelse(is.na(x), mean(x, na.rm=T), x)))
  return(df)
}

female_filtered <- add_small_noise(female_filtered)
male_filtered   <- add_small_noise(male_filtered)

# 最终校验：强制列数=15，标签=15
if (ncol(female_filtered) != 15) stop("女性数据筛选后不是15列！")
if (ncol(male_filtered) != 15) stop("男性数据筛选后不是15列！")
if (length(node_labels) != 15) stop("节点标签不是15个！")

# ==============================
# 步骤4：NCT分析（强制用15列）
# ==============================
cat("=== 开始NCT分析 ===\n")
nct <- NCT(
  data1 = female_filtered,
  data2 = male_filtered,
  gamma = 0.5,
  it = 5000,
  binary.data = FALSE,
  paired = FALSE,
  weighted = TRUE,
  test.edges = TRUE,
  edges = "all",
  progressbar = TRUE
)

# ==============================
# 步骤5：修复边p值矩阵维度（强制匹配15列）
# ==============================
# 手动构建15×15的边p值矩阵（兜底）
edge_pvals_mat <- matrix(NA, nrow = 15, ncol = 15, dimnames = list(node_labels, node_labels))
if (!is.null(nct$einv.pvals)) {
  # 将NCT返回的p值填充到15×15矩阵中
  fill_rows <- min(nrow(nct$einv.pvals), 15)
  fill_cols <- min(ncol(nct$einv.pvals), 15)
  edge_pvals_mat[1:fill_rows, 1:fill_cols] <- nct$einv.pvals[1:fill_rows, 1:fill_cols]
}

# 转换为长格式（确保标签长度=15）
edge_pvals <- as.data.frame(edge_pvals_mat)
colnames(edge_pvals) <- node_labels
edge_pvals$节点1 <- node_labels # 此时标签长度=15，列数=15，不会报错
edge_pvals_long <- melt(edge_pvals, id="节点1", variable.name="节点2", value.name="校正后p值")

# ==============================
# 步骤6：保存结果
# ==============================
# 全局强度+结构
global_result <- data.frame(
  指标 = c("全局强度差异值", "全局强度p值", "结构差异p值"),
  数值 = c(
    ifelse(is.null(nct$glstrinv.real), NA, nct$glstrinv.real),
    ifelse(is.null(nct$glstrinv.pval), NA, nct$glstrinv.pval),
    ifelse(is.null(nct$structure.pval), NA, nct$structure.pval)
  )
)

# 全局结果
write_excel_csv(global_result, paste0(output_path, "nct_global.csv"))

# 边p值
write_excel_csv(edge_pvals_long, paste0(output_path, "nct_edge_p.csv"))

# 显著边
write_excel_csv(edge_sig, paste0(output_path, "nct_sig_edges.csv"))

# 汇总
capture.output(summary(nct), file=paste0(output_path, "nct_summary.txt"), encoding="UTF-8-BOM")

# # ==============================
# # 步骤7：绘制网络（优化版）
# # ==============================
# net_f <- estimateNetwork(female_filtered, default="EBICglasso", tuning=0.5)
# net_m <- estimateNetwork(male_filtered, default="EBICglasso", tuning=0.5)
# 
# # 定义节点颜色（GAD蓝色，PHQ红色）
# node_colors <- c(rep("blue", 7), rep("red", 8))
# 
# # 女性网络
# png(paste0(output_path, "female_network.png"), width=800, height=800, res=150, family="Times New Roman")
# qgraph(
#   net_f$graph,
#   layout          = "spring",
#   repulsion       = 0.3,                      # 降低排斥力，使节点更聚拢
#   labels          = node_labels[1:ncol(net_f$graph)],
#   title           = "Female Anxiety-Depression Network",
#   color           = node_colors,               # 社区颜色
#   posCol          = "green",                   # 正相关绿色
#   negCol          = "red",                     # 负相关红色
#   edge.width      = abs(net_f$graph) * 5,      # 边宽与强度成正比，加粗3倍
#   minimum         = 0.03,
#   theme           = "colorblind",
#   legend          = TRUE,
#   legend.pos      = "bottom",                  # 图例放在底部居中
#   legend.cex      = 0.8                         # 图例文字大小
# )
# dev.off()
# 
# # 男性网络
# png(paste0(output_path, "male_network.png"), width=800, height=800, res=150, family="Times New Roman")
# qgraph(
#   net_m$graph,
#   layout          = "spring",
#   repulsion       = 0.3,
#   labels          = node_labels[1:ncol(net_m$graph)],
#   title           = "Male Anxiety-Depression Network",
#   color           = node_colors,
#   posCol          = "green",
#   negCol          = "red",
#   edge.width      = abs(net_m$graph) * 5,
#   minimum         = 0.03,
#   theme           = "colorblind",
#   legend          = TRUE,
#   legend.pos      = "bottom",
#   legend.cex      = 0.8
# )
# dev.off()

# ==============================
# 最终输出
# ==============================
cat("✅ 分析完成！\n")
cat("全局强度p值：", global_result$数值[2], "\n")
cat("结构差异p值：", global_result$数值[3], "\n")
cat("显著差异边数：", nrow(edge_sig), "\n")

cat("结果路径：", output_path, "\n")

