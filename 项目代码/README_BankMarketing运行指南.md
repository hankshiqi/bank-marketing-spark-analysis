# Bank Marketing 运行指南

当前分析流程使用 UCI Bank Marketing 完整数据集 `bank-full.csv`（45,211 行、17 列）。命令默认从仓库根目录执行，完整数据文件位于 `data/bank_marketing_20261101/bank/bank-full.csv`。

## 1. 上传原始数据

```bash
hdfs dfs -mkdir -p /bigdata/raw/bank_marketing
hdfs dfs -put -f data/bank_marketing_20261101/bank/bank-full.csv \
  /bigdata/raw/bank_marketing/
hdfs dfs -ls -h /bigdata/raw/bank_marketing
```

程序默认从 `hdfs://master:9000/bigdata/raw/bank_marketing/bank-full.csv` 读取。自建集群若使用不同的 NameNode URI，可设置 `BIGDATA_BASE` 或直接设置 `BANK_RAW`。

## 2. 运行 Spark 作业

```bash
mkdir -p output/web
export BIGDATA_OUT="$PWD/output/web"
spark-submit --master yarn --deploy-mode client 项目代码/bank/01_profile.py
spark-submit --master yarn --deploy-mode client 项目代码/bank/02_to_parquet.py
spark-submit --master yarn --deploy-mode client 项目代码/bank/03_analysis.py
```

| 脚本 | 处理内容 | 主要结果 |
|---|---|---|
| `01_profile.py` | 统计行列数、空值、重复值和标签分布 | `bank_profile.json` |
| `02_to_parquet.py` | 清理字段、增加年龄段与标签列，按月份分区写入 Parquet 并回读校验 | HDFS ODS 数据、`bank_etl_summary.json` |
| `03_analysis.py` | 使用 Spark SQL 统计业务指标，并用不含 `y` 的数值特征训练 KMeans | KPI CSV、分群汇总和模型摘要 |

写入位置可通过 `BANK_RAW`、`BANK_ODS` 与 `BIGDATA_OUT` 调整。YARN 集群需要配置好 Hadoop 客户端、Spark 和 Python 依赖；本地验证时可将提交参数改为 `--master 'local[2]'`。

## 3. 启动仪表盘

Spark 作业完成后，保持 `BIGDATA_OUT` 指向结果目录并启动 Flask：

```bash
python3 项目代码/web/app.py
```

默认监听端口为 8000，可通过 `WEB_PORT` 调整。页面从 Spark 导出的 JSON/CSV 加载图表数据。公开仪表盘前，请限制网络来源并避免将管理端口暴露到公网。
