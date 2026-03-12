import pandas as pd
import numpy as np
from scipy.stats import shapiro
import warnings

# 定义文件路径
file_path = r'D:\Users\senta\NHIS\NHIS2019\adult19csv\SAMPLE-7021.csv'
output_file_path = r'D:\Users\senta\NHIS\NHIS2019\adult19csv\core_variables_descriptive_statistics.xlsx'

# 读取CSV文件
df = pd.read_csv(file_path)

# 忽略 Shapiro-Wilk 测试的警告
warnings.filterwarnings("ignore", category=UserWarning, module="scipy.stats")


# 函数用于检查是否近似正态分布并返回相应的统计量
def describe_variable(df, column_name):
    data = df[column_name].dropna()
    stat, p_value = shapiro(data)

    if p_value > 0.05:
        # 近似正态分布
        mean = data.mean()
        std = data.std()
        return f"{mean:.2f} ± {std:.2f}", "Normal"
    else:
        # 偏态分布
        median = data.median()
        q1 = data.quantile(0.25)
        q3 = data.quantile(0.75)
        iqr = q3 - q1
        cvq = iqr / (q3 + q1)

        skewness = 'Positive Skew' if cvq > 0.5 else 'Negative Skew'
        return {
            'Median': f"{median:.2f}",
            'Q1': f"{q1:.2f}",
            'Q3': f"{q3:.2f}",
            'IQR': f"{iqr:.2f}",
            'CVQ': f"{cvq:.2f}",
            'Skewness': skewness
        }, "Skewed"


# 描述anxiety severity (GADCAT_A)
gadcat_result, gadcat_dist_type = describe_variable(df, 'GADCAT_A')
if gadcat_dist_type == "Normal":
    gadcat_df = pd.DataFrame({
        'Variable': ['Anxiety Severity (GADCAT_A)'],
        'Statistic Type': [gadcat_dist_type],
        'Value': [gadcat_result]
    })
else:
    gadcat_df = pd.DataFrame({
        'Variable': ['Anxiety Severity (GADCAT_A)'],
        'Statistic Type': [gadcat_dist_type],
        'Median': [gadcat_result['Median']],
        'Q1': [gadcat_result['Q1']],
        'Q3': [gadcat_result['Q3']],
        'IQR': [gadcat_result['IQR']],
        'CVQ': [gadcat_result['CVQ']],
        'Skewness': [gadcat_result['Skewness']]
    })

# 描述depression severity (PHQCAT_A)
phqcat_result, phqcat_dist_type = describe_variable(df, 'PHQCAT_A')
if phqcat_dist_type == "Normal":
    phqcat_df = pd.DataFrame({
        'Variable': ['Depression Severity (PHQCAT_A)'],
        'Statistic Type': [phqcat_dist_type],
        'Value': [phqcat_result]
    })
else:
    phqcat_df = pd.DataFrame({
        'Variable': ['Depression Severity (PHQCAT_A)'],
        'Statistic Type': [phqcat_dist_type],
        'Median': [phqcat_result['Median']],
        'Q1': [phqcat_result['Q1']],
        'Q3': [phqcat_result['Q3']],
        'IQR': [phqcat_result['IQR']],
        'CVQ': [phqcat_result['CVQ']],
        'Skewness': [phqcat_result['Skewness']]
    })

# 计算GAD-7量表各条目的Mean ± SD
gad7_columns = [f'GAD7{i}_A' for i in range(1, 8)]
gad7_stats = []
for col in gad7_columns:
    mean = df[col].mean()
    std = df[col].std()
    gad7_stats.append({'Variable': col, 'Statistic Type': 'Mean ± SD', 'Value': f"{mean:.2f} ± {std:.2f}"})
gad7_df = pd.DataFrame(gad7_stats)

# 计算PHQ-8量表各条目的Mean ± SD
phq8_columns = [f'PHQ8{i}_A' for i in range(1, 9)]
phq8_stats = []
for col in phq8_columns:
    mean = df[col].mean()
    std = df[col].std()
    phq8_stats.append({'Variable': col, 'Statistic Type': 'Mean ± SD', 'Value': f"{mean:.2f} ± {std:.2f}"})
phq8_df = pd.DataFrame(phq8_stats)

# 合并所有统计数据
all_stats = pd.concat([gadcat_df, phqcat_df, gad7_df, phq8_df], ignore_index=True)

# 创建一个Excel writer对象
with pd.ExcelWriter(output_file_path, engine='xlsxwriter') as writer:
    all_stats.to_excel(writer, sheet_name='Core Var Stats', index=False)

print(f"Descriptive statistics saved to {output_file_path}")