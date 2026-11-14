import pandas as pd
df = pd.read_csv('experiments/00-baseline/results.csv')
stats = df.drop(columns='run').agg(['mean', 'std']).round(2).T
stats['cv_%'] = (stats['std'] / stats['mean'] * 100).round(1)
print(stats)
stats.to_csv('experiments/00-baseline/summary_stats.csv')