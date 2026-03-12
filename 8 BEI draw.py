import pandas as pd
import matplotlib.pyplot as plt
import numpy as np

# -------------------------- 基础设置 --------------------------
# 文件路径（原始字符串避免转义问题）
file_path = r'D:\Users\senta\NHIS\NHIS2019\analysis on adult\python screening\network analysis\final\BEI\node_bridge_expected_influence.csv'
save_path = r'D:\Users\senta\NHIS\NHIS2019\analysis on adult\python screening\network analysis\final\BEI\BEI.png'

# 设置字体：中文用黑体，英文用Times New Roman（统一EI图样式）
plt.rcParams['font.sans-serif'] = ['Times New Roman', 'SimHei']  # 优先Times New Roman，中文 fallback 到黑体
plt.rcParams['axes.unicode_minus'] = False    # 解决负号显示问题
plt.rcParams['font.family'] = 'serif'         # 全局字体族设为衬线体
plt.rcParams['axes.titleweight'] = 'bold'     # 标题加粗
plt.rcParams['axes.labelweight'] = 'bold'     # 轴标签加粗

# -------------------------- 数据读取 --------------------------
# 读取CSV文件并做异常处理
try:
    df = pd.read_csv(file_path)
    print("文件读取成功！")
    print(f"数据总行数：{len(df)}")
    print(f"数据列名：{df.columns.tolist()}")
except FileNotFoundError:
    print(f"错误：未找到文件 {file_path}")
    exit()
except Exception as e:
    print(f"读取文件时出错：{e}")
    exit()

# 定义列名（适配BEI数据）
x_col = 'Bridge Expected Influence'  # X轴列名（BEI值列）
y_col = '节点标签'                    # Y轴列名（节点标签列）

# 检查必要列是否存在
if x_col not in df.columns or y_col not in df.columns:
    print(f"错误：CSV文件中缺少指定列！")
    print(f"请确认列名，当前文件列名：{df.columns.tolist()}")
    exit()

# 保留CSV中原始的节点标签顺序，显式复制避免原数据修改
df_sorted = df.copy()

# -------------------------- 绘图 --------------------------
# 创建画布：拉长Y轴，匹配EI图的尺寸比例
fig, ax = plt.subplots(figsize=(14, 15))

# 绘制折线图（保持原有BEI绘图逻辑，优化样式）
ax.plot(
    df_sorted[x_col],  # X轴：BEI数据
    df_sorted[y_col],  # Y轴：原始节点标签顺序
    linewidth=4,       # 线条宽度匹配EI图
    color='black',     # 线条颜色为黑色
    marker='.',        # 小型数据点标记
    markersize=18,
    markerfacecolor='black',  # 标记填充色
    markeredgecolor='black'   # 标记边框色
)

# -------------------------- 轴标签与标题设置（匹配EI图要求） --------------------------
# 设置图表标题（BEI专属，保持字体样式一致）
ax.set_title(
    'Bridge Expected Influence',
    fontsize=24,
    fontfamily='Times New Roman',
    pad=20,  # 标题与图表的间距
    fontweight='bold'
)

# ===== Y轴标签：node（顶端水平显示，贴近Y轴） =====
ax.text(
    x=-0.03,  # 靠右，贴近Y轴（与EI图一致）
    y=1.02,   # Y轴最上端（略超出避免贴边）
    s='node', # 标签文本
    fontsize=24,
    fontfamily='Times New Roman',
    fontweight='bold',
    ha='center',  # 水平居中
    va='bottom',  # 垂直靠下
    rotation=0,   # 水平显示（关键）
    transform=ax.transAxes  # 轴坐标系，不随数据缩放
)

# ===== X轴标签：BEI value（右端显示，贴近X轴） =====
ax.text(
    x=1.04,   # X轴最右端（略超出避免贴边）
    y=-0.02,  # 上移，贴近X轴（与EI图一致）
    s='BEI value',  # 标签文本
    fontsize=24,
    fontfamily='Times New Roman',
    fontweight='bold',
    ha='left',   # 水平靠左（贴紧轴右端）
    va='center', # 垂直居中
    rotation=0,  # 水平显示
    transform=ax.transAxes  # 轴坐标系
)

# -------------------------- 刻度优化 --------------------------
# 设置X轴刻度（适配BEI数据范围：0.15到0.45，等差0.05）
ax.set_xticks(np.arange(0.15, 0.45, 0.05))
ax.set_xlim(0.15, 0.45)  # 固定X轴范围，避免自动缩放

# 设置刻度字号（匹配EI图，强制Times New Roman）
ax.tick_params(axis='x', labelsize=18, pad=8)  # X轴刻度字号+间距
ax.tick_params(axis='y', labelsize=18, pad=8)  # Y轴刻度字号+间距

# 强制所有刻度标签使用Times New Roman
for label in ax.get_xticklabels() + ax.get_yticklabels():
    label.set_fontfamily('Times New Roman')
    label.set_fontsize(24)

# -------------------------- 样式优化（匹配EI图） --------------------------
# Y轴上下各留10%空白，避免节点标签贴边
ax.margins(y=0.1)

# 添加X轴网格线（虚线，半透明，优化视觉）
ax.grid(axis='x', linestyle='--', alpha=0.6, color='gray', linewidth=1.5)

# 移除顶部和右侧边框，简化样式
ax.spines['top'].set_visible(False)
ax.spines['right'].set_visible(False)

# 加粗左侧/底部边框，增强视觉效果
ax.spines['left'].set_linewidth(2)
ax.spines['bottom'].set_linewidth(2)

# 自动调整布局，防止标签/标题被截断
plt.tight_layout()

# -------------------------- 保存与显示 --------------------------
# 保存图片（高清300DPI，紧凑布局，白色背景）
plt.savefig(
    save_path,
    dpi=300,
    bbox_inches='tight',  # 裁剪空白，避免边框截断
    facecolor='white'     # 背景色为白色，匹配EI图
)
print(f"图表已保存到：{save_path}")

# 显示图片（运行时弹出窗口，可注释掉）
plt.show()