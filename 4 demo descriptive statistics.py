import pandas as pd

# 定义文件路径
file_path = r'D:\Users\senta\NHIS\NHIS2019\adult19csv\SAMPLE-7021.csv'
output_file_path = r'D:\Users\senta\NHIS\NHIS2019\adult19csv\descriptive_statistics.xlsx'

# 读取CSV文件
df = pd.read_csv(file_path)

# 计算AGEP_A列的Mean ± SD
age_mean = df['AGEP_A'].mean()
age_std = df['AGEP_A'].std()
age_stats = pd.DataFrame({'Statistic': ['Mean', 'Standard Deviation'], 'Value': [age_mean, age_std]})
age_stats.insert(0, 'Variable', 'Age')

# 统计gender（SEX_A）列的频数和占比
sex_counts = df['SEX_A'].value_counts().reset_index()
sex_counts.columns = ['Category', 'Count']
sex_percentages = (sex_counts['Count'] / len(df) * 100).round(2)
sex_stats = pd.concat([sex_counts, sex_percentages], axis=1)
sex_stats.columns = ['Category', 'Count', 'Percentage']
sex_stats.insert(0, 'Variable', 'Sex')

# 统计race（HISPALLP_A）列的频数和占比
hispallp_counts = df['HISPALLP_A'].value_counts().reset_index()
hispallp_counts.columns = ['Category', 'Count']
hispallp_percentages = (hispallp_counts['Count'] / len(df) * 100).round(2)
hispallp_stats = pd.concat([hispallp_counts, hispallp_percentages], axis=1)
hispallp_stats.columns = ['Category', 'Count', 'Percentage']
hispallp_stats.insert(0, 'Variable', 'Race')

# 统计educational level（EDUC_A）列的频数和占比
educ_counts = df['EDUC_A'].value_counts().reset_index()
educ_counts.columns = ['Category', 'Count']
educ_percentages = (educ_counts['Count'] / len(df) * 100).round(2)
educ_stats = pd.concat([educ_counts, educ_percentages], axis=1)
educ_stats.columns = ['Category', 'Count', 'Percentage']
educ_stats.insert(0, 'Variable', 'Education Level')

# 统计marital status（MARITAL_A）列的频数和占比
marital_counts = df['MARITAL_A'].value_counts().reset_index()
marital_counts.columns = ['Category', 'Count']
marital_percentages = (marital_counts['Count'] / len(df) * 100).round(2)
marital_stats = pd.concat([marital_counts, marital_percentages], axis=1)
marital_stats.columns = ['Category', 'Count', 'Percentage']
marital_stats.insert(0, 'Variable', 'Marital Status')

# 统计health insurance（NOTCOV_A）列的频数和占比
notcov_counts = df['NOTCOV_A'].value_counts().reset_index()
notcov_counts.columns = ['Category', 'Count']
notcov_percentages = (notcov_counts['Count'] / len(df) * 100).round(2)
notcov_stats = pd.concat([notcov_counts, notcov_percentages], axis=1)
notcov_stats.columns = ['Category', 'Count', 'Percentage']
notcov_stats.insert(0, 'Variable', 'Health Insurance')

# 统计region（REGION）列的频数和占比
region_counts = df['REGION'].value_counts().sort_index().reset_index()
region_counts.columns = ['Category', 'Count']
region_percentages = (region_counts['Count'] / len(df) * 100).round(2)
region_stats = pd.concat([region_counts, region_percentages], axis=1)
region_stats.columns = ['Category', 'Count', 'Percentage']
region_stats.insert(0, 'Variable', 'Region')

# 统计income level（INCGRP_A）列的频数和占比
incgrp_counts = df['INCGRP_A'].value_counts().reset_index()
incgrp_counts.columns = ['Category', 'Count']
incgrp_percentages = (incgrp_counts['Count'] / len(df) * 100).round(2)
incgrp_stats = pd.concat([incgrp_counts, incgrp_percentages], axis=1)
incgrp_stats.columns = ['Category', 'Count', 'Percentage']
incgrp_stats.insert(0, 'Variable', 'Income Level')

# 计算FAMINCTC_A列的Mean ± SD
faminctc_mean = df['FAMINCTC_A'].mean()
faminctc_std = df['FAMINCTC_A'].std()
faminctc_stats = pd.DataFrame({'Statistic': ['Mean', 'Standard Deviation'], 'Value': [faminctc_mean, faminctc_std]})
faminctc_stats.insert(0, 'Variable', 'Family Income')

# 创建一个DataFrame来存储所有统计数据
all_stats = pd.DataFrame()

# 添加年龄统计
all_stats = pd.concat([all_stats, age_stats], ignore_index=True)

# 添加性别统计
all_stats = pd.concat([all_stats, sex_stats], ignore_index=True)

# 添加种族统计
all_stats = pd.concat([all_stats, hispallp_stats], ignore_index=True)

# 添加教育水平统计
all_stats = pd.concat([all_stats, educ_stats], ignore_index=True)

# 添加婚姻状况统计
all_stats = pd.concat([all_stats, marital_stats], ignore_index=True)

# 添加健康保险统计
all_stats = pd.concat([all_stats, notcov_stats], ignore_index=True)

# 添加地区统计
all_stats = pd.concat([all_stats, region_stats], ignore_index=True)

# 添加收入水平统计
all_stats = pd.concat([all_stats, incgrp_stats], ignore_index=True)

# 添加家庭收入统计
all_stats = pd.concat([all_stats, faminctc_stats], ignore_index=True)

# 创建一个Excel writer对象
with pd.ExcelWriter(output_file_path, engine='xlsxwriter') as writer:
    all_stats.to_excel(writer, sheet_name='Descriptive Statistics', index=False)

print(f"Descriptive statistics saved to {output_file_path}")