# =====================================================================
# NHIS 2019 慢性疼痛人群 焦虑-抑郁症状网络分析
# Final analysis code
# ---------------------------------------------------------------------
# 本文档整合本研究的全部 R 分析脚本，供专家复核，与稿件口径一致。
# 共四部分：
#   PART 0  数据清洗            (adult19.csv -> cleaned_data.csv；编码缺失(7/8/9、97/98/99)->NA；
#                               并按性别输出 male/female_network_data.csv；)
#   PART 1  加权描述性统计      (survey 包；分母=各变量"有效应答"加权人数)
#   PART 2  主网络分析          (Polychoric + EBICglasso γ=0.5；单一网络对象
#                               —— 主网络/中心性(EI/BEI)/图2/图3/Bootstrap 统一口径)
#   PART 3  性别差异网络比较    (Network Comparison Test, NCT)
#
# 运行方式：可整文件从上到下顺序运行；也可按 PART 分块选中运行。
# 前置条件：
#   - 将 NHIS 2019 公用数据文件 adult19.csv 放入工作目录（getwd()）；
#   - PART 0 生成 cleaned_data.csv / male_network_data.csv / female_network_data.csv（均存于工作目录）；
#   - PART 1、2 读取 PART 0 的 cleaned_data.csv（GAD-7/PHQ-8 保持原始 1-4 编码）；
#   - PART 3 读取 PART 0 的 male/female_network_data.csv。
#   所有输入/输出文件均使用相对路径，位于当前工作目录下。
# =====================================================================

# -------------------- 0. 统一加载所需包 --------------------
suppressPackageStartupMessages({
  library(survey)               # 复杂抽样加权（PART 1）
  library(writexl)              # 输出 Excel（PART 1/2）
  library(dplyr)                # 数据处理
  library(bootnet)              # 网络估计与 Bootstrap（PART 2/3）
  library(qgraph)               # 网络可视化
  library(psych)                # cor_auto 多项相关（PART 2）
  library(glasso)               # EBICglasso 底层（PART 2）
  library(Matrix)               # 矩阵（PART 2）
  library(igraph)               # 社区/布局（PART 2）
  library(ggplot2)              # 绘图（PART 2）
  library(NetworkComparisonTest)# 网络比较（PART 3）
})



# =====================================================================
# PART 0  数据清洗（adult19.csv -> cleaned_data.csv）
# ---------------------------------------------------------------------
# 清洗逻辑（经核定，最终 N=7014）：
#   1) 年龄 >= 18
#   2) 慢性疼痛：PAIFRQ3M_A in {3,4}（3=most days, 4=almost every day）=> 7184
#   3) 删除 年龄缺失(97/98/99或NA) 或 性别缺失(7/8/9或NA)
#   4) 保留 GAD-7/PHQ-8 共 15 个条目取值【全部为 1~4】的样本
#      （GAD71_A~GAD77_A、PHQ81_A~PHQ88_A，任一条目取值 7/8/9 或 NA 即弃去该样本）

raw_file <- "adult19.csv"       # NHIS 2019 public-use data (adult19.csv)，置于工作目录
out_dir  <- getwd()             # 所有输出文件保存到当前工作目录
out_file <- file.path(out_dir, "cleaned_data.csv")

gad_items <- paste0("GAD7", 1:7, "_A")
phq_items <- paste0("PHQ8", 1:8, "_A")
items     <- c(gad_items, phq_items)

cat("==============================================\n")
cat("PART 0  NHIS 2019 数据清洗（按核定逻辑）\n")
cat("==============================================\n")

# ---------- [第1步] 读取 + 年龄 >= 18 ----------
cat("\n[第1步] 读取数据，筛选年龄 >= 18...\n")
df <- read.csv(raw_file, stringsAsFactors = FALSE)
cat("  原始样本:", nrow(df), "例\n")
df <- df[!is.na(df$AGEP_A) & df$AGEP_A >= 18, ]
cat("  年龄>=18:", nrow(df), "例\n")

# ---------- [第2步] 筛选慢性疼痛患者 ----------
cat("\n[第2步] 筛选慢性疼痛 PAIFRQ3M_A in {3,4}...\n")
df <- df[df$PAIFRQ3M_A %in% c(3, 4), ]
cat("  慢性疼痛患者:", nrow(df), "例\n")
cat("    3=most days:", sum(df$PAIFRQ3M_A == 3), "；4=almost every day:", sum(df$PAIFRQ3M_A == 4), "\n")

# ---------- [第3步] 删除 年龄缺失 或 性别缺失 ----------
cat("\n[第3步] 删除年龄或性别缺失...\n")
age_miss <- is.na(df$AGEP_A) | df$AGEP_A %in% c(97, 98, 99)
sex_miss <- is.na(df$SEX_A)  | df$SEX_A  %in% c(7, 8, 9)
cat("  年龄缺失:", sum(age_miss), "例；性别缺失:", sum(sex_miss), "例\n")
cat("  删除(年龄或性别缺失):", sum(age_miss | sex_miss), "例\n")
df <- df[!(age_miss | sex_miss), ]
cat("  余:", nrow(df), "例\n")

# ---------- [第4步] 保留 GAD/PHQ 15 个条目取值全部为 1~4 的样本 ----------
cat("\n[第4步] 保留 GAD/PHQ 条目取值全部为 1~4 的样本...\n")
cat("  规则：GAD71~77、PHQ81~88 共15个条目，任一取值非1~4（含7/8/9、NA）即弃去该样本。\n")
df[items] <- lapply(df[items], as.numeric)
# 每个样本：GAD 7 条目是否全部有效、PHQ 8 条目是否全部有效
gad_ok <- apply(df[gad_items], 1, function(r) all(!is.na(r) & r %in% c(1, 2, 3, 4)))
phq_ok <- apply(df[phq_items], 1, function(r) all(!is.na(r) & r %in% c(1, 2, 3, 4)))
cat("  GAD条目非全1~4:", sum(!gad_ok), "例；PHQ条目非全1~4:", sum(!phq_ok), "例\n")
cat("  删除(任一条目非1~4):", sum(!(gad_ok & phq_ok)), "例\n")
df <- df[gad_ok & phq_ok, ]
cat("  余:", nrow(df), "例\n")
cat("\n>>> 最终样本 N =", nrow(df), "例\n")

# ---------- [第5步] 描述统计缺失码 -> NA（不改变样本行数）----------
cat("\n[第5步] 描述统计缺失码 -> NA（codebook：7/8/9、97/98/99）...\n")
na_codes <- list(
  SEX_A      = c(7, 8, 9),
  AGEP_A     = c(97, 98, 99),
  EDUC_A     = c(97, 98, 99),
  MARITAL_A  = c(7, 8, 9),
  NOTCOV_A   = c(7, 8, 9),
  HISPALLP_A = c(97, 98, 99),
  INCGRP_A   = c(7, 8, 9)
)
for (v in names(na_codes)) if (v %in% names(df)) df[[v]][df[[v]] %in% na_codes[[v]]] <- NA
if ("FAMINCTC_A" %in% names(df))
  df$FAMINCTC_A[df$FAMINCTC_A %in% c(999, 9999, 99999, 999999, 9999999)] <- NA
cat("  编码缺失已转 NA（样本行数不变）\n")

# ---------- [第6步] 保存 cleaned_data.csv ----------
write.csv(df, out_file, row.names = FALSE)
cat("\n已保存:", out_file, "\n")

# ---------- [第7步] 按性别分亚组（严格分层校验）----------
cat("\n[第7步] 按性别分亚组...\n")
male   <- df[df$SEX_A == 1, ]
female <- df[df$SEX_A == 2, ]
cat("  男性:", nrow(male), "例；女性:", nrow(female), "例\n")
cat("  校验 男+女 =", nrow(male) + nrow(female), "= 最终 N:", nrow(df),
    ifelse(nrow(male) + nrow(female) == nrow(df), "（一致 ✓）", "（不一致 ✗，请检查）"), "\n")
write.csv(male,   file.path(out_dir, "male_network_data.csv"),   row.names = FALSE)
write.csv(female, file.path(out_dir, "female_network_data.csv"), row.names = FALSE)
cat("  已保存: male_network_data.csv / female_network_data.csv\n")

# ---------- [第8步] Table 2 未加权条目 Mean ± SD（1-4 尺度）----------
item_labels <- c(G1="Nervousness", G2="Uncontrollable worry", G3="Excessive worry",
                 G4="Trouble relaxing", G5="Restlessness", G6="Irritability", G7="Fearfulness",
                 P1="Anhedonia", P2="Sadness", P3="Sleep disturbance", P4="Fatigue",
                 P5="Appetite changes", P6="Worthlessness", P7="Concentration problems",
                 P8="Psychomotor symptoms")
node <- gsub("GAD7([0-9])_A", "G\\1", items)
node <- gsub("PHQ8([0-9])_A", "P\\1", node)
tab2 <- data.frame(
  Node    = node,
  Symptom = unname(item_labels[node]),
  Mean    = round(sapply(df[items], mean, na.rm = TRUE), 2),
  SD      = round(sapply(df[items], sd,   na.rm = TRUE), 2))
tab2$Value <- paste0(tab2$Mean, " ± ", tab2$SD)
tab2_out <- file.path(out_dir, "table2_item_descriptives_unweighted.csv")
write.csv(tab2, tab2_out, row.names = FALSE)
cat("\nTable 2 未加权条目均值已保存:", tab2_out, "\n")
print(tab2[, c("Node", "Symptom", "Value")])

cat("\n============== PART 0 数据清洗完成 ==============\n")



# =====================================================================
# PART 1  加权描述性统计（Table 1）
# =====================================================================
# 说明：百分比分母 = 各变量"有效应答"的加权总人数 sum(weights(sub))。
#       编码缺失(7/8/9、97/98/99)已在 PART 0 转为 NA，
#       故"有效应答"分母仅统计真实应答（不含编码缺失）。
#       另输出未加权 n（table1_unweighted_n.csv），含 HISPALLP_A 种族标签映射。
# =====================================================================

# 本板块独立运行所需的包（若已整文件运行过顶部"0. 统一加载所需包"可跳过）
suppressPackageStartupMessages({
  library(survey); library(dplyr); library(writexl)
})

# 1. 读取数据
file_path <- "cleaned_data.csv"   # PART 0 生成，位于工作目录
df <- read.csv(file_path, stringsAsFactors = FALSE)

# 检查变量是否存在
required_vars <- c("WTFA_A", "PSTRAT", "PPSU", "AGEP_A", "SEX_A", "HISPALLP_A",
                   "EDUC_A", "MARITAL_A", "NOTCOV_A", "REGION", "INCGRP_A", "FAMINCTC_A")
missing_vars <- required_vars[!required_vars %in% names(df)]
if (length(missing_vars) > 0) {
  stop("数据中缺少以下变量: ", paste(missing_vars, collapse = ", "))
}

# 2. 定义调查设计
nhis_design <- svydesign(
  id = ~PPSU,          # 初级抽样单元 (PSU)
  strata = ~PSTRAT,    # 分层变量
  weights = ~WTFA_A,   # 最终抽样权重
  data = df,
  nest = TRUE          # 允许 PSU 在不同层内编号重复
)

# 3. 计算加权统计量
# 3.1 年龄 (连续变量): 加权均值 ± 标准差
age_mean <- svymean(~AGEP_A, nhis_design, na.rm = TRUE)
age_var <- svyvar(~AGEP_A, nhis_design, na.rm = TRUE)   # 加权方差
age_sd <- sqrt(coef(age_var))                           # 开方得标准差

# 3.2 家庭收入 (FAMINCTC_A) 连续变量: 加权均值 ± 标准差
income_mean <- svymean(~FAMINCTC_A, nhis_design, na.rm = TRUE)
income_var <- svyvar(~FAMINCTC_A, nhis_design, na.rm = TRUE)
income_sd <- sqrt(coef(income_var))

# 3.3 分类变量: 加权频数和加权百分比（分母=有效应答加权人数）
calc_weighted_cat <- function(var_name, design) {
  sub <- subset(design, !is.na(design$variables[[var_name]]))
  total_valid <- sum(weights(sub))
  tab <- svytable(as.formula(paste0("~", var_name)), sub)
  df_tab <- as.data.frame(tab)
  colnames(df_tab) <- c("Category", "Count")
  df_tab$Percentage <- round((df_tab$Count / total_valid) * 100, 2)
  df_tab$Count <- round(df_tab$Count, 0)
  df_tab <- cbind(Variable = var_name, df_tab)
  return(df_tab)
}

cat_vars <- c("SEX_A", "HISPALLP_A", "EDUC_A", "MARITAL_A",
              "NOTCOV_A", "REGION", "INCGRP_A")
cat_stats_list <- lapply(cat_vars, function(v) calc_weighted_cat(v, nhis_design))
cat_stats <- bind_rows(cat_stats_list)

# 4. 合并所有统计结果
cont_stats <- data.frame(
  Variable = c("Age", "Age", "Family Income", "Family Income"),
  Category = NA,
  Count = NA,
  Percentage = NA,
  Statistic = c("Mean", "Standard Deviation", "Mean", "Standard Deviation"),
  Value = c(coef(age_mean), age_sd, coef(income_mean), income_sd),
  stringsAsFactors = FALSE
)

cat_stats_final <- cat_stats %>%
  mutate(Statistic = NA, Value = NA) %>%
  select(Variable, Category, Count, Percentage, Statistic, Value)

all_stats_final <- bind_rows(cont_stats, cat_stats_final)

# 数值取整/保留两位小数
all_stats_final$Count <- ifelse(!is.na(all_stats_final$Count), round(all_stats_final$Count, 0), NA)
all_stats_final$Percentage <- ifelse(!is.na(all_stats_final$Percentage), round(all_stats_final$Percentage, 2), NA)
all_stats_final$Value <- ifelse(!is.na(all_stats_final$Value), round(as.numeric(all_stats_final$Value), 2), NA)

# 5. 输出 Excel 文件
output_dir <- getwd()
output_file <- file.path(output_dir, "weighted_descriptive_statistics.xlsx")
write_xlsx(all_stats_final, path = output_file)

cat("加权描述性统计已保存至:", output_file, "\n")
cat("总计行数:", nrow(all_stats_final), "\n")

# 6. 未加权频数（Table 1 未加权 n）—— 补充专家意见#3：报告各水平未加权 n 与未加权%
#    缺失码已在 PART 0 转为 NA；此处百分比分母=该变量未加权有效应答人数。
#    HISPALLP_A 族群映射（1-7，按 codebook）：
race_labels <- c("1"="Hispanic", "2"="NH White only",
                 "3"="NH Black/African American only", "4"="NH Asian only",
                 "5"="NH AIAN only", "6"="NH AIAN and any other group",
                 "7"="Other single and multiple races")
cat_lab <- list(
  SEX_A      = c("1"="Male", "2"="Female"),
  HISPALLP_A = race_labels,
  REGION     = c("1"="Northeast", "2"="Midwest", "3"="South", "4"="West"),
  NOTCOV_A   = c("1"="Uncovered", "2"="Covered"),
  MARITAL_A  = c("1"="Married", "2"="Cohabiting partner", "3"="Other")
)
cat_vars2 <- c("SEX_A", "HISPALLP_A", "EDUC_A", "MARITAL_A",
               "NOTCOV_A", "REGION", "INCGRP_A")
unweighted_list <- lapply(cat_vars2, function(v) {
  x <- df[[v]]
  tb <- table(x, useNA = "no")
  out <- data.frame(Variable = v, Category = names(tb),
                    N = as.integer(tb), stringsAsFactors = FALSE)
  if (v %in% names(cat_lab)) out$Category <- unname(cat_lab[[v]][as.character(names(tb))])
  out$Percentage <- round(out$N / sum(out$N) * 100, 2)
  out
})
unweighted_stats <- bind_rows(unweighted_list)
head_rows <- data.frame(
  Variable   = c("Total sample", "Age (valid n)", "Family Income (valid n)"),
  Category   = c("Overall", NA, NA),
  N          = c(nrow(df), sum(!is.na(df$AGEP_A)), sum(!is.na(df$FAMINCTC_A))),
  Percentage = c(100, NA, NA),
  stringsAsFactors = FALSE)
unweighted_stats <- bind_rows(head_rows, unweighted_stats)
table1_n_out <- file.path(output_dir, "table1_unweighted_n.csv")
write.csv(unweighted_stats, table1_n_out, row.names = FALSE, fileEncoding = "UTF-8")
cat("Table 1 未加权 n 已保存至:", table1_n_out, "\n")
print(unweighted_stats)



# =====================================================================
# PART 2  主网络分析
# 对应 Methods 2.4.2 Network Analysis / Results 3.1-3.6
# 输出：权重矩阵、中心性(Strength/EI/Bridge Strength/BEI)、
#       Bootstrap 稳定性(CS 系数 + 边权重 CI)、节点可预测性、
#       图 2 网络 / 图 3 中心性折线图 / 图 4 稳定性 / 图 5 边CI森林图
# 单一网络对象：主网络/中心性/图2/图3/Bootstrap 统一分析口径
# =====================================================================

# 本板块独立运行所需的包（若已整文件运行过顶部"0. 统一加载所需包"可跳过）
suppressPackageStartupMessages({
  library(bootnet); library(qgraph); library(psych); library(glasso)
  library(Matrix); library(igraph); library(ggplot2); library(dplyr)
})

# 2.1 路径配置与读取数据
output_dir <- getwd()
file_path <- file.path(output_dir, "cleaned_data.csv")
df <- read.csv(file_path, stringsAsFactors = FALSE)

gad_items <- paste0("GAD7", 1:7, "_A")
phq_items <- paste0("PHQ8", 1:8, "_A")
all_items <- c(gad_items, phq_items)

symptom_data <- df[, all_items]
symptom_data_complete <- symptom_data[complete.cases(symptom_data), ]
cat("完整样本量:", nrow(symptom_data_complete), "\n")

# 2.2 节点标签 + 供 estimateNetwork 用的数据
simplify_node_names <- function(x) {
  x <- gsub("GAD7([0-9])_A", "G\\1", x); x <- gsub("PHQ8([0-9])_A", "P\\1", x); x
}
node_labels <- simplify_node_names(all_items)
symptom_data_simple <- symptom_data_complete
colnames(symptom_data_simple) <- node_labels
comm_vec <- ifelse(grepl("^G", node_labels), "GAD", "PHQ"); names(comm_vec) <- node_labels

# 2.3 Polychoric 相关矩阵（供无阈值补充表与可预测性用）
cor_mat <- cor_auto(symptom_data_complete)
rownames(cor_mat) <- colnames(cor_mat) <- all_items
is_pd <- tryCatch({ chol(cor_mat); TRUE }, error = function(e) FALSE)
if (!is_pd) { cor_mat <- as.matrix(nearPD(cor_mat, keepDiag = TRUE)$mat)
rownames(cor_mat) <- colnames(cor_mat) <- all_items }

# 2.4 单一网络对象（唯一来源）
network_ebic <- estimateNetwork(symptom_data_simple, default = "EBICglasso",
                                tuning = 0.5, corMethod = "cor_auto", verbose = FALSE)
net_ebic <- network_ebic$graph
colnames(net_ebic) <- rownames(net_ebic) <- node_labels
diag(net_ebic) <- 0
write.csv(net_ebic, file.path(output_dir, "ebicglasso_primary_weights.csv"), row.names = TRUE)

# 2.5 无阈值化偏相关矩阵（补充材料专用，非最终网络）
n_obs <- nrow(symptom_data_complete)
net_no_thr <- EBICglasso(S = cor_mat, n = n_obs, gamma = 0.5,
                         penalize.diagonal = FALSE, threshold = FALSE)
colnames(net_no_thr) <- rownames(net_no_thr) <- all_items; diag(net_no_thr) <- 0
triu_idx <- which(upper.tri(net_no_thr), arr.ind = TRUE)
edge_no_threshold <- data.frame(Node1 = all_items[triu_idx[,1]],
                                Node2 = all_items[triu_idx[,2]],
                                Weight = net_no_thr[triu_idx])
edge_no_threshold$Sign <- ifelse(edge_no_threshold$Weight < 0, "Negative",
                                 ifelse(edge_no_threshold$Weight > 0, "Positive", "Zero"))
write.csv(edge_no_threshold, file.path(output_dir, "edges_no_threshold_all_105.csv"), row.names = FALSE)

# 2.6 网络结构信息
n_nodes <- ncol(net_ebic); total_edges <- n_nodes*(n_nodes-1)/2
nonzero_edges <- sum(net_ebic[lower.tri(net_ebic)] != 0)
edge_density  <- nonzero_edges / total_edges
neg_edges     <- sum(net_ebic[lower.tri(net_ebic)] < 0)
max_pos <- which(abs(net_ebic) == max(abs(net_ebic)), arr.ind = TRUE)
if (is.matrix(max_pos) && nrow(max_pos) > 1) max_pos <- max_pos[1, ]
max_edge_pair <- paste0(node_labels[max_pos[1]], " - ", node_labels[max_pos[2]])
max_edge_weight <- net_ebic[max_pos[1], max_pos[2]]
non_zero_w <- net_ebic[lower.tri(net_ebic)][net_ebic[lower.tri(net_ebic)] != 0]
weight_range <- paste0(round(min(non_zero_w),4), " to ", round(max(non_zero_w),4))

g_ig <- graph_from_adjacency_matrix(net_ebic, mode="undirected", weighted=TRUE, diag=FALSE)
# 网络含负边；walktrap / modularity 要求非负权重，故用 |weight| 判社区结构
# （符号信息仍保留在网络与边色中，社区划分只依据关联强度）
w_abs <- abs(E(g_ig)$weight)
set.seed(123)
communities <- cluster_walktrap(g_ig, weights = w_abs)
detected_comm_count <- length(unique(membership(communities)))
preset_comm <- ifelse(grepl("^G", node_labels), 1, 2); names(preset_comm) <- node_labels
modularity_preset <- modularity(g_ig, membership = preset_comm, weights = w_abs)

community_labels <- ifelse(grepl("^G", node_labels), "GAD", "PHQ"); names(community_labels) <- node_labels
triu_all <- which(upper.tri(net_ebic), arr.ind = TRUE)
cross_edges <- data.frame()
for (i in seq_len(nrow(triu_all))) {
  r <- triu_all[i,1]; c <- triu_all[i,2]; n1 <- node_labels[r]; n2 <- node_labels[c]; w <- net_ebic[r,c]
  if (w != 0 && community_labels[n1] != community_labels[n2])
    cross_edges <- rbind(cross_edges, data.frame(Node1=n1, Node2=n2, Weight=w, Weight_abs=abs(w)))
}
if (nrow(cross_edges) > 0) {
  cross_edges <- cross_edges[order(-cross_edges$Weight_abs), ]
  strongest_bridge <- paste0(cross_edges$Node1[1], " - ", cross_edges$Node2[1])
  strongest_bridge_w <- round(cross_edges$Weight[1], 4)
} else { strongest_bridge <- "None"; strongest_bridge_w <- NA }
n_cross <- nrow(cross_edges)

# 一致性自检：S2 与 bootstrap original 必须逐边一致
net_check <- network_ebic$graph; diag(net_check) <- 0
colnames(net_check) <- rownames(net_check) <- node_labels
cat("一致性检查: S2 与 network_ebic$graph 最大差异 =",
    max(abs(net_ebic - net_check), na.rm = TRUE), "\n")
cat("最终网络非零边:", nonzero_edges, "  负边:", neg_edges, "\n")

struct_df <- data.frame(
  Parameter = c("Number of nodes","Non-zero edges","Total possible edges","Network density",
                "Negative edges (final network)","Edge weight range (min to max)",
                "Strongest edge (overall)","Strongest edge weight (overall)",
                "Strongest bridge edge (GAD-PHQ)","Strongest bridge edge weight",
                "Number of bridge edges","Detected communities (walktrap)",
                "Modularity (preset GAD/PHQ)","Negative edges (no threshold)"),
  Value = c(n_nodes, nonzero_edges, total_edges, round(edge_density,4), neg_edges,
            weight_range, max_edge_pair, round(max_edge_weight,4), strongest_bridge,
            strongest_bridge_w, n_cross, detected_comm_count,
            round(modularity_preset,4), sum(edge_no_threshold$Sign=="Negative")))
write.csv(struct_df, file.path(output_dir, "ebicglasso_primary_network_structure.csv"), row.names=FALSE)
if (nrow(cross_edges) > 0)
  write.csv(cross_edges, file.path(output_dir, "bridge_edges_details.csv"), row.names=FALSE)

# 2.7 中心性（Strength / EI / Bridge Strength / BEI）
calc_strength <- function(m){ diag(m)<-0; rowSums(abs(m), na.rm=TRUE) }
calc_ei       <- function(m){ diag(m)<-0; rowSums(m, na.rm=TRUE) }
calc_bridge_strength <- function(m,comm){ diag(m)<-0; n<-rownames(m); v<-numeric(length(n)); names(v)<-n
for(i in seq_along(n)){ o<-n[comm!=comm[n[i]]]; v[i]<- if(length(o)==0) 0 else sum(abs(m[n[i],o]),na.rm=TRUE) }; v }
calc_bei <- function(m,comm){ diag(m)<-0; n<-rownames(m); v<-numeric(length(n)); names(v)<-n
for(i in seq_along(n)){ o<-n[comm!=comm[n[i]]]; v[i]<- if(length(o)==0) 0 else sum(m[n[i],o],na.rm=TRUE) }; v }

community_assignment <- ifelse(grepl("^G", node_labels), "GAD", "PHQ")
names(community_assignment) <- node_labels
strength_primary        <- calc_strength(net_ebic)
ei_primary              <- calc_ei(net_ebic)
bridge_strength_primary <- calc_bridge_strength(net_ebic, community_assignment)
bei_primary             <- calc_bei(net_ebic, community_assignment)

centrality_all <- data.frame(
  Node = node_labels,
  Strength = round(strength_primary,4), Rank_Strength = as.integer(rank(-strength_primary)),
  Expected_Influence = round(ei_primary,4), Rank_EI = as.integer(rank(-ei_primary)),
  Bridge_Strength = round(bridge_strength_primary,4), Rank_Bridge_Strength = as.integer(rank(-bridge_strength_primary)),
  Bridge_Expected_Influence = round(bei_primary,4), Rank_BEI = as.integer(rank(-bei_primary)))
centrality_all <- centrality_all[order(centrality_all$Rank_Strength), ]
write.csv(centrality_all, file.path(output_dir, "ebicglasso_primary_centrality_all.csv"), row.names=FALSE)

# 2.8 网络可视化 Figure 2
node_colors_base <- ifelse(grepl("^G", node_labels), "#e74c3c", "#3498db")
node_colors <- adjustcolor(node_colors_base, alpha.f=0.85); names(node_colors) <- node_labels
g_ig <- graph_from_adjacency_matrix(net_ebic, mode="undirected", weighted=TRUE, diag=FALSE)
ew <- E(g_ig)$weight
ec <- adjustcolor(ifelse(ew>0,"darkgreen", ifelse(ew<0,"red","gray90")), alpha.f=0.55)
aw <- abs(ew); mw <- max(aw, na.rm=TRUE)
ewidth <- pmax(1.0 + if(mw>0) aw/mw*29 else 0, 0.5)
E(g_ig)$color <- ec; E(g_ig)$width <- ewidth
V(g_ig)$color <- node_colors; V(g_ig)$label <- node_labels
V(g_ig)$label.cex <- 1.8; V(g_ig)$label.font <- 2; V(g_ig)$label.color <- "white"
V(g_ig)$frame.color <- adjustcolor("black", alpha.f=0.6); V(g_ig)$frame.width <- 1.5; V(g_ig)$size <- 24
set.seed(123); layout_ig <- layout_with_fr(g_ig, weights = w_abs, niter = 5000)

png(file.path(output_dir, "Figure_2_primary_network_EBICglasso.png"), width=1600, height=1100, res=130)
par(mar=c(2,2,2,14))
plot(g_ig, layout=layout_ig, vertex.color=V(g_ig)$color, vertex.size=V(g_ig)$size,
     vertex.label=V(g_ig)$label, vertex.label.cex=V(g_ig)$label.cex,
     vertex.label.font=V(g_ig)$label.font, vertex.label.color=V(g_ig)$label.color,
     vertex.frame.color=V(g_ig)$frame.color, vertex.frame.width=V(g_ig)$frame.width,
     edge.color=E(g_ig)$color, edge.width=E(g_ig)$width, main="", asp=0, rescale=TRUE)
usr <- par("usr"); xr <- usr[2]-usr[1]
legend(usr[2]+xr*0.03, (usr[3]+usr[4])/2+0.5, legend=c("GAD","PHQ"), pch=21,
       pt.bg=c("#e74c3c","#3498db"), pt.cex=3.5, col="black", bty="n", cex=1.6,
       text.col="black", y.intersp=1.5, xpd=TRUE)
text(usr[2]+xr*0.03, (usr[3]+usr[4])/2+0.5-3.0, labels="Edge colors:", cex=1.4, adj=0, font=2, xpd=TRUE)
text(usr[2]+xr*0.03, (usr[3]+usr[4])/2+0.5-4.5, labels="  ●  Positive (Green)", cex=1.4, adj=0, col="darkgreen", xpd=TRUE)
if (sum(ew<0)>0)
  text(usr[2]+xr*0.03, (usr[3]+usr[4])/2+0.5-5.7, labels="  ●  Negative (Red)", cex=1.4, adj=0, col="darkred", xpd=TRUE)
dev.off()


# =====================================================================
# PART 2（续）  Bootstrap 稳定性检验（修复版）
# 主网络/中心性/图2/图3/bootstrap 均取自同一 network_ebic 对象
# =====================================================================

# 本板块独立运行所需的包（若已整文件运行过顶部"0. 统一加载所需包"可跳过）
suppressPackageStartupMessages({
  library(bootnet); library(dplyr); library(ggplot2); library(psych)
})

symptom_data_simple <- symptom_data_complete
colnames(symptom_data_simple) <- node_labels
comm_vec <- ifelse(grepl("^G", node_labels), "GAD", "PHQ"); names(comm_vec) <- node_labels

# --- 9.1 唯一网络对象（此后主网络/中心性/图/bootstrap 全部用它） ---
network_ebic <- estimateNetwork(
  symptom_data_simple, default = "EBICglasso", tuning = 0.5,
  corMethod = "cor_auto", verbose = FALSE)
saveRDS(network_ebic, file.path(output_dir, "network_ebic_object.rds"))

# --- 9.2 非参数 Bootstrap：边权重 95% CI ---
set.seed(123)
boot_edges <- bootnet(
  network_ebic, nBoots = 1000, type = "nonparametric",
  statistics = c("edge","strength","expectedInfluence",
                 "bridgeStrength","bridgeExpectedInfluence"),
  communities = comm_vec, nCores = 4, verbose = FALSE)
saveRDS(boot_edges, file.path(output_dir, "boot_edges_EBICglasso.rds"))

# --- 9.3 Case-dropping：CS 系数与稳定性 ---
set.seed(123)
boot_cases <- bootnet(
  network_ebic, nBoots = 1000, type = "case",
  statistics = c("strength","expectedInfluence",
                 "bridgeStrength","bridgeExpectedInfluence"),
  communities = comm_vec, caseMin = 0.1, caseMax = 1.0, caseN = 15,
  nCores = 4, verbose = FALSE)
saveRDS(boot_cases, file.path(output_dir, "boot_cases_EBICglasso.rds"))

# --- 9.4 CS 系数表（corStability 标准函数） ---
stats_to_check <- c("strength","expectedInfluence","bridgeStrength","bridgeExpectedInfluence")
thresholds     <- c(0.25, 0.5, 0.7, 0.75)
cs_results <- data.frame()
for (s in stats_to_check) for (t in thresholds) {
  cs_results <- rbind(cs_results, data.frame(
    statistic = s, threshold = t,
    CS_coefficient = tryCatch(corStability(boot_cases, statistics = s, cor = t, verbose = FALSE),
                              error = function(e) NA_real_)))
}
write.csv(cs_results, file.path(output_dir, "CS_coefficient_EBICglasso.csv"), row.names = FALSE)

# --- 9.5 稳定性曲线（Strength/Bridge 主文；EI/BEI 补充） ---
for (s in c("strength","bridgeStrength","expectedInfluence","bridgeExpectedInfluence")) {
  png(file.path(output_dir, paste0("Figure_4_stability_", s, ".png")),
      width = 2400, height = 2000, res = 300)
  p <- plot(boot_cases, statistics = s, order = "sample")   # bootnet 返回 ggplot
  print(p)
  dev.off()
}

# --- 9.6 边权重 Bootstrap CI（修正 contains_zero：端点=0 视为触及 0） ---
edge_boot <- boot_edges$bootTable
edge_data <- edge_boot[edge_boot$type == "edge" & grepl("^boot", edge_boot$name), ]
edge_ci <- edge_data %>%
  group_by(id, node1, node2) %>%
  summarise(mean = mean(value, na.rm = TRUE),
            lower = quantile(value, 0.025, na.rm = TRUE),
            upper = quantile(value, 0.975, na.rm = TRUE), .groups = "drop") %>%
  as.data.frame()
edge_ci$contains_zero <- edge_ci$lower <= 0 & edge_ci$upper >= 0
edge_ci$stable <- !edge_ci$contains_zero
graph_ref <- network_ebic$graph; diag(graph_ref) <- 0
edge_ci$original <- mapply(function(n1, n2) graph_ref[n1, n2], edge_ci$node1, edge_ci$node2)
write.csv(edge_ci, file.path(output_dir, "edge_CI_bootstrap.csv"), row.names = FALSE)

# --- 9.7 森林图（top40 + 说明，caption 需指向 S5） ---
plot_edge <- edge_ci[order(edge_ci$mean, decreasing = TRUE), ]
plot_edge$edge_label <- paste0(plot_edge$node1, "\u2013", plot_edge$node2)
plot_edge_top <- if (nrow(plot_edge) > 40) head(plot_edge, 40) else plot_edge
p_edge <- ggplot(plot_edge_top, aes(y = reorder(edge_label, mean))) +
  geom_errorbarh(aes(xmin = lower, xmax = upper), height = 0.3, color = "gray40", linewidth = 0.8) +
  geom_point(aes(x = mean, color = "Bootstrap mean"), size = 3.5) +
  geom_point(aes(x = original, color = "Original sample"), size = 2.5, alpha = 0.7) +
  geom_vline(xintercept = 0, linetype = "dashed", color = "gray50", linewidth = 0.8) +
  labs(title = "Bootstrap 95% CI for Edge Weights (top 40 by bootstrap mean)",
       subtitle = "Complete results in Supplementary Table S5",
       x = "Edge Weight (Partial Correlation)", y = NULL) +
  scale_color_manual(values = c("Bootstrap mean" = "black", "Original sample" = "red")) +
  theme_minimal(base_family = "serif", base_size = 14) +
  theme(plot.title = element_text(size = 18, face = "bold", hjust = 0.5),
        legend.position = "bottom")
ggsave(file.path(output_dir, "Figure_5_edge_CI_bootstrap.png"), p_edge,
       width = 12, height = 10, dpi = 300, bg = "white")

# --- 9.8 节点可预测性 R² ---
# 说明：bootnet 没有名为"predictability"的函数；GGM 节点 R² 由网络(精度阵)计算，
# 反映潜在连续层面(polychoric 相关)的解释比例，非原始有序观测的 R² 。
R_poly <- cor_auto(symptom_data_simple)     # 与 network_ebic 同一相关阵
K_prec <- solve(R_poly)                     # 精度阵
R2 <- 1 - 1 / diag(K_prec)
names(R2) <- node_labels
predict_df <- data.frame(Node = node_labels, Predictability_R2 = round(R2, 4))
predict_df <- predict_df[order(-predict_df$Predictability_R2), ]
write.csv(predict_df, file.path(output_dir, "node_predictability_R2.csv"), row.names = FALSE)
cat("节点可预测性 R²（潜在连续层面）:\n"); print(predict_df)


# =====================================================================
# PART 2（续）  中心性折线图 Figure 3
# 两张 2 面板折线图：图 3a = Strength + Bridge Strength；图 3b = EI + BEI
# =====================================================================
# 本板块依赖 PART 2 已生成的 centrality_all；独立运行前需先跑 PART 2。

cat("\n========== 绘制中心性折线图 Figure 3 ==========\n")

node_order <- c("G1","G2","G3","G4","G5","G6","G7",
                "P1","P2","P3","P4","P5","P6","P7","P8")
cent_plot <- centrality_all[match(node_order, centrality_all$Node), ]

plot_central <- function(xvar, xlim, xticks, title, tag) {
  plot(x = cent_plot[[xvar]], y = 1:nrow(cent_plot),
       type = "n", xlim = xlim, ylim = c(0.5, nrow(cent_plot) + 0.5),
       axes = FALSE, xlab = "", ylab = "", main = "")
  for (t in xticks) abline(v = t, lty = 2, col = "gray", lwd = 1.2)
  lines(x = cent_plot[[xvar]], y = 1:nrow(cent_plot),
        type = "o", pch = 19, col = "black", lwd = 3.2, cex = 1.8)
  axis(1, at = xticks, labels = xticks, cex.axis = 1.5, font = 2,
       family = "serif", lwd = 2, tck = -0.02)
  axis(2, at = 1:nrow(cent_plot), labels = cent_plot$Node,
       cex.axis = 1.5, font = 2, family = "serif", las = 2, lwd = 2, tck = -0.02)
  box(bty = "l", lwd = 2)
  mtext(title, side = 3, line = 2.5, cex = 2.0, font = 2, family = "serif")
  mtext(tag,   side = 1, line = 4.5, cex = 1.6, font = 2, family = "serif")
}

# ---- 图 3a: Strength + Bridge Strength ----
png(file.path(output_dir, "Figure_3a_centrality_Strength_BridgeStrength.png"),
    width = 1600, height = 1200, res = 130)
par(mfrow = c(1, 2), mar = c(6, 8, 6, 4), oma = c(0, 0, 0, 0))
plot_central("Strength", c(0.50, 1.30), seq(0.50, 1.30, 0.1), "Strength", "(a)")
plot_central("Bridge_Strength", c(0, 0.45), seq(0, 0.40, 0.1), "Bridge Strength", "(b)")
dev.off()

# ---- 图 3b: EI + BEI ----
png(file.path(output_dir, "Figure_3b_centrality_EI_BEI.png"),
    width = 1600, height = 1200, res = 130)
par(mfrow = c(1, 2), mar = c(6, 8, 6, 4), oma = c(0, 0, 0, 0))
plot_central("Expected_Influence", c(0.50, 1.30), seq(0.50, 1.30, 0.1), "Expected Influence(EI)", "(a)")
plot_central("Bridge_Expected_Influence", c(0, 0.45), seq(0, 0.40, 0.1), "Bridge Expected Influence(BEI)", "(b)")
dev.off()
cat("✅ 中心性折线图已保存: Figure_3a / Figure_3b\n")

cat("\n========== Bootstrap 分析完成 ==========\n")
cat("输出文件：network_ebic_object.rds / boot_edges_EBICglasso.rds / boot_cases_EBICglasso.rds /",
    "CS_coefficient_EBICglasso.csv / edge_CI_bootstrap.csv / Figure_4a-4d / Figure_5 / node_predictability_R2.csv\n")



# =====================================================================
# PART 3  性别差异网络比较（NCT）
# 对应 Results 3.7 性别差异段
# 注意：本部分读取工作目录下的
#       male_network_data.csv / female_network_data.csv（由 PART 0 生成）
# =====================================================================

# 本板块独立运行所需的包（若已整文件运行过顶部"0. 统一加载所需包"可跳过）
suppressPackageStartupMessages({
  library(NetworkComparisonTest); library(bootnet); library(qgraph); library(dplyr)
})

# 3.1 工作目录（所有输入/输出文件均位于当前工作目录，与 PART 0 输出同目录）
work_dir <- getwd()
cat("当前工作目录：", getwd(), "\n")

# 3.2 数据读取与预处理（增强健壮性）
tryCatch({
  male_data <- read.csv("male_network_data.csv", stringsAsFactors = FALSE)
  female_data <- read.csv("female_network_data.csv", stringsAsFactors = FALSE)
  cat("数据读取成功！\n")
  cat("男性样本量：", nrow(male_data), " 变量数：", ncol(male_data), "\n")
  cat("女性样本量：", nrow(female_data), " 变量数：", ncol(female_data), "\n")
}, error = function(e) {
  stop("数据读取失败！请先运行 PART 0 生成 male/female_network_data.csv：", e$message)
})

# 1. 检查变量名是否一致
if (!identical(colnames(male_data), colnames(female_data))) {
  stop("男女数据变量名不一致！请检查数据列顺序/名称")
}

# 2. 剔除缺失值（也可替换为多重插补，根据需求调整）
male_data_clean <- na.omit(male_data)
female_data_clean <- na.omit(female_data)
cat("剔除缺失后：男性样本量 =", nrow(male_data_clean), " 女性样本量 =", nrow(female_data_clean), "\n")

# 3. 检查数据类型（确保为数值型）
if (!all(sapply(male_data_clean, is.numeric)) | !all(sapply(female_data_clean, is.numeric))) {
  warning("数据包含非数值列！自动剔除非数值列")
  male_data_clean <- select_if(male_data_clean, is.numeric)
  female_data_clean <- select_if(female_data_clean, is.numeric)
}

# 3.3 估计男女网络（与主分析一致）
cat("开始估计男性网络...\n")
network_male <- estimateNetwork(
  male_data_clean,
  default = "EBICglasso",
  tuning = 0.5,
  corMethod = "cor_auto",
  verbose = FALSE
)

cat("开始估计女性网络...\n")
network_female <- estimateNetwork(
  female_data_clean,
  default = "EBICglasso",
  tuning = 0.5,
  corMethod = "cor_auto",
  verbose = FALSE
)

# 3.4 运行 Network Comparison Test（NCT）
cat("开始运行NCT检验（预计耗时数分钟，请耐心等待）...\n")
nct_result <- NCT(
  male_data_clean,
  female_data_clean,
  gamma = 0.5,               # 与网络估计的tuning参数一致
  it = 5000,                 # 置换检验迭代次数（与稿件 2.4.3 所述 5,000 一致）
  binary.data = FALSE,       # 非二分类数据
  paired = FALSE,            # 独立样本（男女）
  test.edges = TRUE,         # 检验单个边的差异
  edges = "all",             # 检验所有边
  progressbar = TRUE,        # 显示进度条
  verbose = FALSE            # 关闭冗余输出
)
cat("NCT检验完成！\n")

# 3.5 结果导出（CSV格式）
# 5.1 提取核心结果
structural_real <- NA
structural_pval <- NA
if ("structural" %in% names(nct_result) && !is.null(nct_result$structural$real)) {
  structural_real <- round(nct_result$structural$real, 4)
}
if ("structural" %in% names(nct_result) && !is.null(nct_result$structural$pval)) {
  structural_pval <- round(nct_result$structural$pval, 4)
}

strength_real <- NA
strength_pval <- NA
if ("strength" %in% names(nct_result) && !is.null(nct_result$strength$real)) {
  strength_real <- round(nct_result$strength$real, 4)
}
if ("strength" %in% names(nct_result) && !is.null(nct_result$strength$pval)) {
  strength_pval <- round(nct_result$strength$pval, 4)
}

edge_pvals <- NULL
if ("edges" %in% names(nct_result) && !is.null(nct_result$edges$pvals)) {
  edge_pvals <- nct_result$edges$pvals
  rownames(edge_pvals) <- colnames(male_data_clean)
  colnames(edge_pvals) <- colnames(male_data_clean)
  edge_pvals <- round(edge_pvals, 4)
}

# 5.2 导出全局结果
global_results <- data.frame(
  检验指标 = c("结构不变性统计量", "结构不变性p值", "全局强度差异值", "全局强度p值"),
  数值 = c(structural_real, structural_pval, strength_real, strength_pval),
  显著性 = c(
    "",
    ifelse(!is.na(structural_pval) & structural_pval < 0.05, "显著", ifelse(is.na(structural_pval), "无结果", "不显著")),
    "",
    ifelse(!is.na(strength_pval) & strength_pval < 0.05, "显著", ifelse(is.na(strength_pval), "无结果", "不显著"))
  )
)
write.csv(global_results, "NCT_global_results.csv", row.names = FALSE, fileEncoding = "UTF-8")
cat("全局结果已保存为：NCT_global_results.csv\n")

# 5.3 导出边差异p值矩阵（有结果才保存）
if (!is.null(edge_pvals)) {
  edge_pvals_sig <- edge_pvals
  edge_pvals_sig[!is.na(edge_pvals_sig) & edge_pvals_sig < 0.05] <- paste0(edge_pvals_sig[!is.na(edge_pvals_sig) & edge_pvals_sig < 0.05], "*")
  write.csv(edge_pvals_sig, "NCT_edge_pvals.csv", row.names = TRUE, fileEncoding = "UTF-8")
  cat("边差异p值矩阵已保存为：NCT_edge_pvals.csv（*表示p<0.05）\n")
} else {
  cat("提示：未找到边差异p值结果，跳过保存\n")
}

# 5.4 保存完整NCT结果
saveRDS(nct_result, "NCT_result_gender.rds")
cat("完整NCT结果已保存为：NCT_result_gender.rds\n")

# 5.5 计算显著边的效应方向（男性 vs 女性）
cat("\n========== 计算显著边的效应方向 ==========\n")
male_w   <- network_male$graph
female_w <- network_female$graph

if (!is.null(edge_pvals)) {
  sig_idx <- which(edge_pvals < 0.05 & upper.tri(edge_pvals), arr.ind = TRUE)
  if (nrow(sig_idx) > 0) {
    edge_dir <- data.frame(
      Node1         = character(nrow(sig_idx)),
      Node2         = character(nrow(sig_idx)),
      Male_weight   = numeric(nrow(sig_idx)),
      Female_weight = numeric(nrow(sig_idx)),
      Diff_M_minus_F = numeric(nrow(sig_idx)),
      Stronger_in   = character(nrow(sig_idx)),
      p_value       = numeric(nrow(sig_idx)),
      stringsAsFactors = FALSE
    )
    for (i in seq_len(nrow(sig_idx))) {
      n1 <- rownames(edge_pvals)[sig_idx[i, 1]]
      n2 <- colnames(edge_pvals)[sig_idx[i, 2]]
      edge_dir$Node1[i]           <- n1
      edge_dir$Node2[i]           <- n2
      edge_dir$Male_weight[i]     <- male_w[n1, n2]
      edge_dir$Female_weight[i]   <- female_w[n1, n2]
      edge_dir$Diff_M_minus_F[i]  <- male_w[n1, n2] - female_w[n1, n2]
      edge_dir$Stronger_in[i]     <- ifelse(male_w[n1, n2] > female_w[n1, n2], "Male", "Female")
      edge_dir$p_value[i]         <- edge_pvals[n1, n2]
    }
    edge_dir <- edge_dir[order(edge_dir$p_value), ]
    rownames(edge_dir) <- NULL
    write.csv(edge_dir, file = "NCT_significant_edges_direction.csv",
              row.names = FALSE, fileEncoding = "UTF-8")
    cat("显著边效应方向已保存：NCT_significant_edges_direction.csv\n\n")
    print(edge_dir, row.names = FALSE)
  } else {
    cat("无 p < 0.05 的显著边。\n")
  }
}

# 3.6 网络可视化与图片保存
male_weights <- network_male$graph
female_weights <- network_female$graph

label_cex <- 1
node_width <- 1
edge_width <- 0.8
title_cex <- 1.2
legend_cex <- 0.8
layout_type <- "spring"

png("male_network.png", width = 900, height = 800, res = 100)
qgraph(
  male_weights,
  title = "Male Network (EBICglasso, γ=0.5)",
  layout = layout_type,
  label.cex = label_cex,
  node.width = node_width,
  edge.width = edge_width,
  title.cex = title_cex,
  legend.cex = legend_cex,
  color = "lightblue",
  edge.color = "black"
)
dev.off()
cat("男性网络图片已保存为：male_network.png\n")

png("female_network.png", width = 900, height = 800, res = 100)
qgraph(
  female_weights,
  title = "Female Network (EBICglasso, γ=0.5)",
  layout = layout_type,
  label.cex = label_cex,
  node.width = node_width,
  edge.width = edge_width,
  title.cex = title_cex,
  legend.cex = legend_cex,
  color = "lightpink",
  edge.color = "darkred"
)
dev.off()
cat("女性网络图片已保存为：female_network.png\n")

if (!is.null(edge_pvals)) {
  sig_edges <- which(!is.na(edge_pvals) & edge_pvals < 0.05, arr.ind = TRUE)
  png("gender_network_comparison.png", width = 1200, height = 800, res = 100)
  par(mfrow = c(1, 2))
  qgraph(
    male_weights,
    title = "Male Network",
    layout = layout_type,
    label.cex = label_cex,
    node.width = node_width,
    edge.width = edge_width,
    color = "lightblue",
    edge.color = "black"
  )
  edge_colors <- rep("darkred", nrow(female_weights))
  if (nrow(sig_edges) > 0) {
    edge_colors[sig_edges[,1]] <- "red"
  }
  qgraph(
    female_weights,
    title = "Female Network (Red=Sig. Diff. Edges)",
    layout = layout_type,
    label.cex = label_cex,
    node.width = node_width,
    edge.width = edge_width,
    color = "lightpink",
    edge.color = edge_colors
  )
  dev.off()
  cat("性别网络对比图已保存为：gender_network_comparison.png\n")
} else {
  cat("提示：无侧边差异结果，跳过对比图绘制\n")
}

# 3.7 控制台输出核心结果
cat("\n==================== 核心结果汇总 ====================\n")
if (!is.na(structural_pval)) {
  cat("1. 结构不变性检验：p值 =", structural_pval,
      ifelse(structural_pval < 0.05, "（显著）", "（不显著）"), "\n")
} else {
  cat("1. 结构不变性检验：无有效结果\n")
}
if (!is.na(strength_pval)) {
  cat("2. 全局强度差异检验：p值 =", strength_pval,
      ifelse(strength_pval < 0.05, "（显著）", "（不显著）"), "\n")
} else {
  cat("2. 全局强度差异检验：无有效结果\n")
}
if (!is.null(edge_pvals)) {
  sig_edge_num <- sum(!is.na(edge_pvals) & edge_pvals < 0.05, na.rm = TRUE)
  cat("3. 显著差异边数量：", sig_edge_num, "\n")
} else {
  cat("3. 显著差异边数量：无有效结果\n")
}
cat("======================================================\n")

cat("\n所有分析完成！结果文件已保存至工作目录：", getwd(), "\n")
