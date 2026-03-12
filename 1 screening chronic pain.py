import pandas as pd

# 定义文件路径和列名
file_path = r'data.csv'
output_file_path = r'output.csv'
column_name = 'PAIFRQ3M_A'

# 读取CSV文件
df = pd.read_csv(file_path)

# 筛选出PAIFRQ3M_A 列里取值为3或4的样本
filtered_df = df[df[column_name].isin([3, 4])]

# 检查筛选后的行数是否符合预期
if len(filtered_df) == 7184:
    # 将新的DataFrame保存为CSV文件
    filtered_df.to_csv(output_file_path, index=False)
    print(f"筛选完成，共 {len(filtered_df)} 行数据已保存到 {output_file_path}")
else:
    print(f"筛选结果不符合预期，共 {len(filtered_df)} 行数据")



