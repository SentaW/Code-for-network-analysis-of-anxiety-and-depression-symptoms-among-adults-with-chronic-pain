import pandas as pd
import numpy as np
import networkx as nx
import matplotlib.pyplot as plt
from scipy.stats import norm
import os
from sklearn.covariance import GraphicalLassoCV

# -------------------------- 1. 路径配置与创建 --------------------------
input_file_path = r"data.csv"
output_dir = r"output"

if not os.path.exists(output_dir):
    os.makedirs(output_dir)
    print(f"已创建输出文件夹：{output_dir}")
else:
    print(f"输出文件夹已存在：{output_dir}")

# -------------------------- 2. 读取CSV数据 --------------------------
try:
    df = pd.read_csv(input_file_path, encoding='utf-8')
    print(f"成功读取数据，数据形状：{df.shape}")
except Exception as e:
    print(f"utf-8编码读取失败，错误：{e}")
    try:
        df = pd.read_csv(input_file_path, encoding='gbk')
        print(f"gbk编码成功读取数据，数据形状：{df.shape}")
    except Exception as e2:
        print(f"gbk编码读取失败，错误：{e2}")
        raise SystemExit("数据读取失败，请检查路径或编码")

# -------------------------- 3. 定义原始条目与新标签映射 --------------------------
# 原始条目
gad7_items_original = ['GAD71_A', 'GAD72_A', 'GAD73_A', 'GAD74_A', 'GAD75_A', 'GAD76_A', 'GAD77_A']
phq8_items_original = ['PHQ81_A', 'PHQ82_A', 'PHQ83_A', 'PHQ84_A', 'PHQ85_A', 'PHQ86_A', 'PHQ87_A', 'PHQ88_A']
network_nodes_original = gad7_items_original + phq8_items_original

# 新标签映射（GAD71_A→GAD1，PHQ81_A→PHQ1，以此类推）
node_label_mapping = {}
# GAD-7 标签映射
for i, original in enumerate(gad7_items_original, 1):
    node_label_mapping[original] = f'G{i}'
# PHQ-8 标签映射
for i, original in enumerate(phq8_items_original, 1):
    node_label_mapping[original] = f'P{i}'
new_network_nodes = [node_label_mapping[node] for node in network_nodes_original]

# 检查原始条目是否存在
missing_items = [item for item in network_nodes_original if item not in df.columns]
if missing_items:
    raise ValueError(f"缺失条目：{missing_items}")
else:
    print("所有原始条目均存在，继续分析")

# 提取数据
network_data = df[network_nodes_original].copy()
print(f"网络分析数据形状：{network_data.shape}")

# -------------------------- 4. 缺失值检测 --------------------------
print("\n========== 缺失值检测结果 ==========")
missing_count = network_data.isnull().sum()
missing_ratio = (missing_count / len(network_data)) * 100
missing_result = pd.DataFrame({
    '原始条目名称': network_nodes_original,
    '新标签': new_network_nodes,
    '缺失值数量': missing_count.values,
    '缺失值比例(%)': missing_ratio.values.round(4)
})
print(missing_result)

total_missing = network_data.isnull().sum().sum()
total_missing_ratio = (total_missing / (network_data.shape[0] * network_data.shape[1])) * 100
print(f"\n整体缺失值数量：{total_missing}")
print(f"整体缺失值比例：{round(total_missing_ratio, 4)}%")

if total_missing > 0:
    raise ValueError("检测到缺失值，请先处理后再运行")
else:
    print("✅ 无缺失值，继续分析")


# -------------------------- 5. 非参数正态转换 --------------------------
def non_parametric_normalization(data):
    """
    使用经验累积分布函数（ECDF）进行非参数正态转换
    参数：
        data: 输入的数据集（DataFrame）
    返回：
        transformed_转换后的数据集（DataFrame）
    """
    transformed_data = pd.DataFrame(index=data.index, columns=data.columns)
    for column in data.columns:
        sorted_values = np.sort(data[column])
        ecdf_values = np.arange(1, len(sorted_values) + 1) / len(sorted_values)
        rank_indices = np.searchsorted(sorted_values, data[column], side='left')
        transformed_data[column] = norm.ppf(ecdf_values[rank_indices])
    return transformed_data


network_data_npn = non_parametric_normalization(network_data)
print(f"\n非参数正态转换完成")

# 计算转换后的协方差矩阵
cov_matrix_npn = np.cov(network_data_npn.T)
print("\n非参数正态转换后的协方差矩阵：")
print(cov_matrix_npn)

# -------------------------- 6. 网络估计（保留原始相关性符号，用于区分正负边） --------------------------
print("\n========== 网络估计 ==========")
glasso_cv = GraphicalLassoCV(
    cv=10,
    alphas=100,
    n_jobs=-1,
    verbose=1
)
glasso_cv.fit(network_data_npn.values)

print(f"最佳正则化参数(alpha)：{glasso_cv.alpha_}")
precision_matrix = glasso_cv.precision_  # 保留符号的精度矩阵（用于判断正负相关）


# -------------------------- 7. 精度矩阵转偏相关矩阵 --------------------------
def precision_to_partial_correlation(precision_matrix):
    """
    将精度矩阵转换为偏相关矩阵
    参数：
        precision_matrix: 精度矩阵（numpy array）
    返回：
        partial_corr_matrix: 偏相关矩阵（numpy array）
    """
    diag_sqrt_inv = np.diag(1 / np.sqrt(np.diag(precision_matrix)))
    partial_corr_matrix = -diag_sqrt_inv @ precision_matrix @ diag_sqrt_inv
    np.fill_diagonal(partial_corr_matrix, 1)
    return partial_corr_matrix


partial_corr_matrix = precision_to_partial_correlation(precision_matrix)
adjacency_matrix_abs = np.abs(partial_corr_matrix)  # 绝对值邻接矩阵（用于构建网络拓扑）
np.fill_diagonal(partial_corr_matrix, 0)
np.fill_diagonal(adjacency_matrix_abs, 0)

# 保存矩阵
np.save(os.path.join(output_dir, "precision_matrix_with_sign.npy"), precision_matrix)
np.save(os.path.join(output_dir, "partial_corr_matrix.npy"), partial_corr_matrix)
np.save(os.path.join(output_dir, "adjacency_matrix_abs.npy"), adjacency_matrix_abs)
print("精度矩阵（带符号）、偏相关矩阵和邻接矩阵（绝对值）已保存")

# -------------------------- 8. 构建网络对象（带边符号属性+新标签） --------------------------
# 基于绝对值邻接矩阵构建网络
G = nx.from_numpy_array(adjacency_matrix_abs)
# 原始节点名称映射
original_node_names = {i: network_nodes_original[i] for i in range(len(network_nodes_original))}
G = nx.relabel_nodes(G, original_node_names)
# 重命名为新标签
G = nx.relabel_nodes(G, node_label_mapping)

# 添加节点属性
for node in G.nodes:
    if node.startswith('G'):
        G.nodes[node]['type'] = 'GAD-7'
        G.nodes[node]['color'] = '#3498db'
    else:
        G.nodes[node]['type'] = 'PHQ-8'
        G.nodes[node]['color'] = '#e74c3c'

# 添加边属性（权重+符号+颜色）
for (u, v) in G.edges:
    # 获取原始节点名称
    u_original = [k for k, v_map in node_label_mapping.items() if v_map == u][0]
    v_original = [k for k, v_map in node_label_mapping.items() if v_map == v][0]
    # 获取原始索引
    u_idx = network_nodes_original.index(u_original)
    v_idx = network_nodes_original.index(v_original)
    # 原始权重（带符号）
    original_weight = partial_corr_matrix[u_idx, v_idx]
    # 绝对值权重
    abs_weight = adjacency_matrix_abs[u_idx, v_idx]
    # 设置边属性
    G.edges[(u, v)]['weight_abs'] = abs_weight
    G.edges[(u, v)]['weight_sign'] = original_weight
    G.edges[(u, v)]['correlation_type'] = 'positive' if original_weight > 0 else 'negative'
    G.edges[(u, v)]['color'] = 'green' if original_weight > 0 else 'red'

print(f"\n网络对象信息：")
print(f"节点数量：{G.number_of_nodes()}")
print(f"边数量：{G.number_of_edges()}")
print(f"网络密度：{round(nx.density(G), 4)}")

# -------------------------- 9. 网络可视化（正边绿，负边红，新标签） --------------------------
print("\n========== 网络可视化 ==========")
plt.rcParams['font.sans-serif'] = ['Times New Roman']
plt.rcParams['axes.unicode_minus'] = False
fig, ax = plt.subplots(1, 1, figsize=(14, 10))

# 节点颜色
node_colors = [G.nodes[node]['color'] for node in G.nodes]
# 边颜色
edge_colors = [G.edges[(u, v)]['color'] for (u, v) in G.edges]
# 边权重（用于线宽）
edge_weights = [G.edges[(u, v)]['weight_abs'] * 48 for (u, v) in G.edges]

# 尝试 k=0.5 或 k=1.0，让节点自然聚集
pos = nx.spring_layout(G, k=0.25, iterations=300, seed=123)
# 手动压缩所有坐标（0.5 = 缩小一半，边变短）
pos = {node: (x * 0.2, y * 0.2) for node, (x, y) in pos.items()}
# 绘制节点
nx.draw_networkx_nodes(
    G, pos, ax=ax,
    node_color=node_colors, node_size=3200,
    alpha=0.9, edgecolors='black', linewidths=1.3
)

# 绘制边（正绿负红）
nx.draw_networkx_edges(
    G, pos, ax=ax,
    width=edge_weights, alpha=0.9,
    edge_color=edge_colors
)

# 绘制新节点标签
nx.draw_networkx_labels(
    G, pos, ax=ax,
    font_size=32, font_weight='bold'
)

# 保存图片
viz_save_path = os.path.join(output_dir, "network_visualization_with_sign.png")
plt.tight_layout()
plt.savefig(viz_save_path, dpi=300, bbox_inches='tight')
plt.close()
print(f"可视化图片已保存至：{viz_save_path}")

# -------------------------- 10. 计算节点中心性指标 --------------------------
print("\n========== 计算节点中心性指标 ==========")
# 常见中心性指标
centrality_metrics = {}
# 1. 度中心性
centrality_metrics['度中心性 (Degree Centrality)'] = nx.degree_centrality(G)
# 2. 介数中心性
centrality_metrics['介数中心性 (Betweenness Centrality)'] = nx.betweenness_centrality(G)  # 移除了 n_jobs 参数
# 3. 接近性中心性
centrality_metrics['接近性中心性 (Closeness Centrality)'] = nx.closeness_centrality(G)
# 4. 特征向量中心性
centrality_metrics['特征向量中心性 (Eigenvector Centrality)'] = nx.eigenvector_centrality(G, max_iter=1000)

# 构建中心性结果DataFrame
centrality_df = pd.DataFrame(centrality_metrics)
centrality_df.reset_index(inplace=True)
centrality_df.rename(columns={'index': '节点标签'}, inplace=True)
# 添加节点类型
centrality_df['节点类型'] = ['GAD-7' if node.startswith('GAD') else 'PHQ-8' for node in centrality_df['节点标签']]

# 保存中心性结果
centrality_save_path = os.path.join(output_dir, "node_centrality_metrics.csv")
centrality_df.to_csv(centrality_save_path, index=False, encoding='utf-8-sig')
print(f"节点中心性指标已保存至：{centrality_save_path}")
print("中心性指标预览：")
print(centrality_df.head(10))

# -------------------------- 11. 计算Bridge Expected Influence（桥接预期影响） --------------------------
print("\n========== 计算Bridge Expected Influence ==========")


def calculate_bridge_expected_influence(G):
    """
    计算Bridge Expected Influence（桥接预期影响）
    参数：
        G: NetworkX网络对象，边具有'weight_sign'属性（带符号的权重）
    返回：
        bridge_ei: 各节点的桥接预期影响字典
    """
    bridge_ei = {}

    for node in G.nodes:
        # 获取节点类型
        node_type = G.nodes[node]['type']

        # 初始化桥接预期影响值
        node_bridge_ei = 0.0

        # 遍历所有邻居节点
        for neighbor in G.neighbors(node):
            # 检查邻居节点类型是否与当前节点不同（跨类型连接）
            if G.nodes[neighbor]['type'] != node_type:
                # 累加跨类型边的带符号权重
                weight = G.edges[(node, neighbor)]['weight_sign']
                node_bridge_ei += weight

        bridge_ei[node] = node_bridge_ei

    return bridge_ei


# 计算桥接预期影响
bridge_ei = calculate_bridge_expected_influence(G)

# 构建桥接预期影响结果DataFrame
bridge_ei_df = pd.DataFrame({
    '节点标签': list(bridge_ei.keys()),
    'Bridge Expected Influence': list(bridge_ei.values()),
    '节点类型': ['GAD-7' if node.startswith('GAD') else 'PHQ-8' for node in bridge_ei.keys()]
})

# 保存桥接预期影响结果
bridge_ei_save_path = os.path.join(output_dir, "node_bridge_expected_influence.csv")
bridge_ei_df.to_csv(bridge_ei_save_path, index=False, encoding='utf-8-sig')
print(f"Bridge Expected Influence已保存至：{bridge_ei_save_path}")
print("Bridge Expected Influence预览：")
print(bridge_ei_df.head(10))

# -------------------------- 12. 计算Expected Influence（预期影响） --------------------------
print("\n========== 计算Expected Influence ==========")


def calculate_expected_influence(G):
    """
    计算Expected Influence（预期影响）
    参数：
        G: NetworkX网络对象，边具有'weight_sign'属性（带符号的权重）
    返回：
        expected_influence: 各节点的预期影响字典
    """
    expected_influence = {}

    for node in G.nodes:
        # 初始化预期影响值
        node_ei = 0.0

        # 遍历所有邻居节点，累加带符号权重
        for neighbor in G.neighbors(node):
            weight = G.edges[(node, neighbor)]['weight_sign']
            node_ei += weight

        expected_influence[node] = node_ei

    return expected_influence


# 计算预期影响
expected_influence = calculate_expected_influence(G)

# 构建预期影响结果DataFrame
ei_df = pd.DataFrame({
    '节点标签': list(expected_influence.keys()),
    'Expected Influence': list(expected_influence.values()),
    '节点类型': ['GAD-7' if node.startswith('GAD') else 'PHQ-8' for node in expected_influence.keys()]
})

# 保存预期影响结果
ei_save_path = os.path.join(output_dir, "node_expected_influence.csv")
ei_df.to_csv(ei_save_path, index=False, encoding='utf-8-sig')
print(f"Expected Influence已保存至：{ei_save_path}")
print("Expected Influence预览：")
print(ei_df.head(10))

# -------------------------- 13. 性别分层 --------------------------

# 确保 SEX_A 存在
if 'SEX_A' not in df.columns:
    raise ValueError("缺失 SEX_A 列")

# 分层
male_df = df[df['SEX_A'] == 1].copy()
female_df = df[df['SEX_A'] == 2].copy()

print(f"男性样本量：{male_df.shape[0]}")
print(f"女性样本量：{female_df.shape[0]}")

# 提取网络变量
male_network = male_df[network_nodes_original]
female_network = female_df[network_nodes_original]

# 保存为CSV供R使用
male_path = os.path.join(output_dir, "male_network_data.csv")
female_path = os.path.join(output_dir, "female_network_data.csv")

male_network.to_csv(male_path, index=False)
female_network.to_csv(female_path, index=False)

print("已导出男性与女性网络数据")

# -------------------------- 14. 保存其他结果 --------------------------
# 缺失值结果（带新标签）
missing_result_save_path = os.path.join(output_dir, "missing_value_result_with_new_label.csv")
missing_result.to_csv(missing_result_save_path, index=False, encoding='utf-8-sig')

# 节点信息
node_info_df = pd.DataFrame({
    '节点标签': list(G.nodes),
    '原始条目名称': [k for k, v in node_label_mapping.items() if v in G.nodes],
    '节点类型': [G.nodes[node]['type'] for node in G.nodes],
    '节点颜色': [G.nodes[node]['color'] for node in G.nodes],
    'Bridge Expected Influence': [bridge_ei[node] for node in G.nodes],
    'Expected Influence': [expected_influence[node] for node in G.nodes]
})
node_info_save_path = os.path.join(output_dir, "network_node_info_with_new_label.csv")
node_info_df.to_csv(node_info_save_path, index=False, encoding='utf-8-sig')

# 边信息（带相关类型）
edge_info_list = []
for (u, v) in G.edges:
    edge_info_list.append({
        '节点1': u,
        '节点2': v,
        '节点1类型': G.nodes[u]['type'],
        '节点2类型': G.nodes[v]['type'],
        '权重(绝对值)': G.edges[(u, v)]['weight_abs'],
        '权重(带符号)': G.edges[(u, v)]['weight_sign'],
        '相关类型': G.edges[(u, v)]['correlation_type'],
        '边颜色': G.edges[(u, v)]['color'],
    })
edge_info_df = pd.DataFrame(edge_info_list)
edge_info_save_path = os.path.join(output_dir, "network_edge_info_with_sign_and_edge_bei.csv")
edge_info_df.to_csv(edge_info_save_path, index=False, encoding='utf-8-sig')

print("\n========== 所有分析完成！ ==========")
print(f"所有结果已保存至：{output_dir}")

# 打印汇总信息
print("\n========== 汇总信息 ==========")
print(f"1. 网络分析数据: {network_data.shape[0]} 个样本，{network_data.shape[1]} 个节点")
print(f"2. 网络边数量: {G.number_of_edges()} 条边")
print(f"3. 节点类型: {len(gad7_items_original)} 个GAD-7节点, {len(phq8_items_original)} 个PHQ-8节点")
print(f"4. 计算的中心性指标: {len(centrality_metrics)} 种")
print(f"5. Bridge Expected Influence (BEI) 计算完成: {len(bridge_ei)} 个节点")

print(f"6. Expected Influence (EI) 计算完成: {len(expected_influence)} 个节点")
