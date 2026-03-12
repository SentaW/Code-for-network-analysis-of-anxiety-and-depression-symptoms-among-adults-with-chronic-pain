import pandas as pd

# 定义文件路径和列名
file_path = r'data.csv'
output_file_path = r'output.csv'
column_name_paifrq3m_a = 'PAIFRQ3M_A'
column_name_sex_a = 'SEX_A'
column_name_agep_a = 'AGEP_A'

# 读取CSV文件
df = pd.read_csv(file_path)

# 筛选出PAIFRQ3M_A 列里取值为3或4的样本
filtered_df = df[df[column_name_paifrq3m_a].isin([3, 4])]

# 删除SEX_A 列里取值为7或8或9的样本
filtered_df = filtered_df[~filtered_df[column_name_sex_a].isin([7, 8, 9])]

# 删除AGEP_A 列里取值为97或98或99的样本
filtered_df = filtered_df[~filtered_df[column_name_agep_a].isin([97, 98, 99])]

# 检查筛选后的行数是否符合预期
print(f"筛选完成后，共 {len(filtered_df)} 行数据")

# 将新的DataFrame保存为CSV文件
filtered_df.to_csv(output_file_path, index=False)

print(f"新的数据已保存到 {output_file_path}")
