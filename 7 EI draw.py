import pandas as pd
import matplotlib.pyplot as plt
import numpy as np

# -------------------------- 基础设置 --------------------------
# 文件路径（原始字符串避免转义问题）
file_path = r'D:\Users\senta\NHIS\NHIS2019\analysis on adult\python screening\network analysis\final\EI\node_expected_influence.csv'
save_path = r'D:\Users\senta\NHIS\NHIS2019\analysis on adult\python screening\network analysis\final\EI\EI.png'

# 设置字体：中文用黑体，英文用Times New Roman
plt.rcParams['font.sans-serif'] = ['Times New Roman', 'SimHei']  # 优先Times New Roman，中文 fallback 到黑体
plt.rcParams['axes.unicode_minus'] = False    # 解决负号显示问题
plt.rcParams['font.family'] = 'serif'         # 全局字体族设为衬线体，适配Times New Roman

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

# 定义列名（请根据你的CSV实际列名修改！）
x_col = 'Expected Influence'  # X轴列名
y_col = 'Node'                # Y轴列名

# 检查必要列是否存在
if x_col not in df.columns or y_col not in df.columns:
    print(f"错误：CSV文件中缺少指定列！")
    print(f"请确认列名，当前文件列名：{df.columns.tolist()}")
    exit()

# 保留CSV中原始的节点标签顺序，不做任何排序
df_sorted = df.copy()  # 显式复制，避免原数据被修改

# -------------------------- 绘图 --------------------------
# 创建画布：调整figsize，拉长Y轴（height从7改为10，width适度增大）
fig, ax = plt.subplots(figsize=(14, 15))

# 绘制折线图（全部数据+按节点标签顺序+线条磅数3）
ax.plot(
    df_sorted[x_col],  # X轴：全部EI数据
    df_sorted[y_col],  # Y轴：按原始/标签顺序的节点标签
    linewidth=4,       # 线条磅数3
    color='black',     # 线条颜色为黑色
    marker='.',        # 小型数据点标记
    markersize=18,
    markerfacecolor='black',
    markeredgecolor='black'
)

# -------------------------- 轴标签与标题设置（核心优化：标签位置） --------------------------
# 设置图表标题（英文用Times New Roman，加粗，字号24）
ax.set_title(
    'Expected Influence',
    fontsize=24,
    fontfamily='Times New Roman',
    pad=20,  # 标题与图表的间距
    fontweight='bold'
)

# ===== 核心修改1：Y轴标签（node）放在Y轴最上端，水平显示 =====
# 移除默认Y轴标签，改用text手动定位
ax.text(
    x=-0.04,  # X坐标：Y轴左侧（负值），可微调
    y=1.0,   # Y坐标：Y轴最上端（1.0是轴顶端，1.02是略超出）
    s='node', # 标签文本
    fontsize=22,
    fontfamily='Times New Roman',
    fontweight='bold',
    ha='center',  # 水平居中
    va='bottom',  # 垂直靠下（贴紧轴顶端）
    rotation=0,   # 0度=水平显示（关键）
    transform=ax.transAxes  # 使用轴坐标系（0-1），不随数据缩放
)

# ===== 核心修改2：X轴标签（EI value）放在X轴最右端 =====
# 移除默认X轴标签，改用text手动定位
ax.text(
    x=1.0,   # X坐标：X轴最右端（1.0是轴右端，1.02是略超出）
    y=-0.02,  # Y坐标：X轴下方（负值），可微调
    s='EI value',  # 标签文本
    fontsize=22,
    fontfamily='Times New Roman',
    fontweight='bold',
    ha='left',   # 水平靠左（贴紧轴右端）
    va='center', # 垂直居中
    rotation=0,  # 水平显示
    transform=ax.transAxes  # 使用轴坐标系（0-1）
)

# -------------------------- 刻度优化 --------------------------
# 设置X轴刻度（0.01到0.04，等差0.05）
ax.set_xticks(np.arange(0.6, 1.15, 0.05))
ax.set_xlim(0.6, 1.15)  # 固定X轴范围

# 设置刻度字号（英文刻度用Times New Roman）
ax.tick_params(axis='x', labelsize=22, pad=8)  # X轴刻度字号+间距
ax.tick_params(axis='y', labelsize=22, pad=8)  # Y轴刻度字号+间距

# 强制X/Y轴刻度标签使用Times New Roman
for label in ax.get_xticklabels() + ax.get_yticklabels():
    label.set_fontfamily('Times New Roman')
    label.set_fontsize(22)

# -------------------------- 优化图表样式 --------------------------
# 修复关键问题：Y轴是字符串，无法计算数值padding，改为调整Y轴边距
ax.margins(y=0.1)  # Y轴上下各留10%的空白（适用于字符串标签）

# 优化网格线：仅X轴，虚线，半透明
ax.grid(axis='x', linestyle='--', alpha=0.6, color='gray', linewidth=1.5)

# 移除顶部/右侧边框，简化样式
ax.spines['top'].set_visible(False)
ax.spines['right'].set_visible(False)

# 加粗左侧/底部边框
ax.spines['left'].set_linewidth(2)
ax.spines['bottom'].set_linewidth(2)

plt.tight_layout()  # 自动调整布局，防止标签被截断

# -------------------------- 保存与显示 --------------------------
# 保存图片（高清，避免边框截断）
plt.savefig(
    save_path,
    dpi=300,
    bbox_inches='tight',
    facecolor='white'  # 背景白色
)
print(f"图表已保存到：{save_path}")

# 显示图片（运行时弹出窗口，可注释掉）
plt.show()