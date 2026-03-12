import pandas as pd

# 定义文件路径和列名
file_path = r'D:\Users\senta\NHIS\NHIS2019\adult19csv\adult19.csv'
output_file_path = r'D:\Users\senta\NHIS\NHIS2019\adult19csv\missing_data_management.csv'

# GAD量表相关列名
gad_columns = ['GAD71_A', 'GAD72_A', 'GAD73_A', 'GAD74_A', 'GAD75_A', 'GAD76_A', 'GAD77_A', 'GADCAT_A']

# PHQ量表相关列名
phq_columns = ['PHQ81_A', 'PHQ82_A', 'PHQ83_A', 'PHQ84_A', 'PHQ85_A', 'PHQ86_A', 'PHQ87_A', 'PHQ88_A', 'PHQCAT_A']

# 读取CSV文件
df = pd.read_csv(file_path)

# 筛选出PAIFRQ3M_A 列里取值为3或4的样本
filtered_df = df[df['PAIFRQ3M_A'].isin([3, 4])]

# 删除SEX_A 列里取值为7或8或9的样本
filtered_df = filtered_df[~filtered_df['SEX_A'].isin([7, 8, 9])]

# 删除AGEP_A 列里取值为87或98或99的样本
filtered_df = filtered_df[~filtered_df['AGEP_A'].isin([87, 98, 99])]

# 删除GAD量表中任意一列取值为7或8或9的样本
filtered_df = filtered_df[~filtered_df[gad_columns].isin([7, 8, 9]).any(axis=1)]

# 删除PHQ量表中任意一列取值为7或8或9的样本
filtered_df = filtered_df[~filtered_df[phq_columns].isin([7, 8, 9]).any(axis=1)]

# 检查筛选后的行数是否符合预期
print(f"筛选完成后，共 {len(filtered_df)} 行数据")

# 将新的DataFrame保存为CSV文件
filtered_df.to_csv(output_file_path, index=False)
print(f"新的数据已保存到 {output_file_path}")