# UCI Bank Marketing 分布式分析

这是一个面向课程实践的 Hadoop、Spark 与 Flask 项目。项目使用 UCI Bank Marketing 完整数据集，演示原始 CSV 入 HDFS、Spark 数据体检与清洗、按月写入 Parquet、Spark SQL 指标统计、MLlib KMeans 客户分群，以及结果页面展示。

数据包含 45,211 条记录和 17 个字段。分析目标是观察葡萄牙银行电话营销活动中客户是否订购定期存款。KMeans 使用年龄、账户余额、本轮联系次数和此前联系次数作为特征；目标字段 `y` 不参与聚类训练，仅用于描述各群体的订购比例。

## 项目结构

- `项目代码/bank/`：数据校验、Parquet 清洗和 Spark SQL / KMeans 分析脚本。
- `项目代码/web/`：Flask 与 ECharts 结果页面。
- `项目代码/requirements.txt`：Python 依赖。
- `集群部署/`：Hadoop 与 Spark 双节点部署配置及脚本。节点 IP 需由使用者自行填写。
- `data/bank_marketing_20261101/bank/bank-full.csv`：UCI 完整数据集。
- `docs/evidence/`：不含服务器日志或现场截图的汇总指标样例，可用于预览仪表盘。
- `docs/illustrations/`：项目流程和 KMeans 原理图。

课程答辩文件、原始现场截图、控制台日志和本机集群连接信息不在这个公开仓库中。

## 数据来源与许可

数据来自 [UCI Machine Learning Repository: Bank Marketing](https://archive.ics.uci.edu/dataset/222/bank+marketing)，数据集编号 222，许可为 [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/)。使用或再分发数据时请保留来源说明：Moro, S., Rita, P., & Cortez, P. (2014). *Bank Marketing*. UCI Machine Learning Repository. https://doi.org/10.24432/C5K306

本地附带的是 `bank-full.csv` 完整样本，不是 4,521 行的 `bank.csv` 子集。数据描述和字段含义见 [数据集说明](数据集说明.md)。

## 运行环境

完整集群运行需要 Linux、Java 8、Hadoop 3.3.6、Spark 3.5.1、Python 3.8 或以上版本，以及可用的 HDFS/YARN 集群。也可先在安装了兼容 Java 与 PySpark 的机器上用 `--master local[2]` 做小规模验证。

## 执行分析

从仓库根目录执行。先安装 Python 依赖，并把完整 CSV 上传到 HDFS：

```bash
python3 -m pip install -r 项目代码/requirements.txt
hdfs dfs -mkdir -p /bigdata/raw/bank_marketing
hdfs dfs -put -f data/bank_marketing_20261101/bank/bank-full.csv /bigdata/raw/bank_marketing/
mkdir -p output/web
export BIGDATA_OUT="$PWD/output/web"
```

随后依次运行数据体检、清洗入湖和分析：

```bash
spark-submit --master yarn --deploy-mode client 项目代码/bank/01_profile.py
spark-submit --master yarn --deploy-mode client 项目代码/bank/02_to_parquet.py
spark-submit --master yarn --deploy-mode client 项目代码/bank/03_analysis.py
```

默认 HDFS 路径为 `hdfs://master:9000/bigdata`。可按自己的集群覆盖 `BIGDATA_BASE`，并用 `BANK_RAW`、`BANK_ODS` 覆盖原始层与 ODS 路径。分析结果写入 `BIGDATA_OUT`，默认目录为 `/opt/bigdata-course/output/web`。

## 查看仪表盘

运行 Spark 作业后，从仓库根目录启动页面：

```bash
export BIGDATA_OUT="$PWD/output/web"
python3 项目代码/web/app.py
```

默认端口为 8000，可通过 `WEB_PORT` 修改。仅在可信网络中访问；配置云安全组时，应限制管理端口和 Web 端口的来源地址，不要向整个互联网开放 Hadoop、YARN 或 Spark 管理界面。若只想预览页面，可把 `BIGDATA_OUT` 指向 `docs/evidence` 中随仓库提供的汇总样例。

更具体的 Spark 操作步骤见 [Bank Marketing 运行指南](项目代码/README_BankMarketing运行指南.md)，集群配置见 [集群部署说明](集群部署/README.md)。

## 分析边界

这是用于教学的约 4.5 万条样本，不代表生产规模。统计结果描述数据中的关联，不构成营销因果结论；样本来自 2008 至 2010 年的葡萄牙银行活动，不应直接外推为当前客户行为。
