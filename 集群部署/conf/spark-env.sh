#!/usr/bin/env bash
# ============================================================================
# 文件名：spark-env.sh
# 路径：$SPARK_HOME/conf/spark-env.sh
# 说明：两台机器共用同一份文件（SPARK_LOCAL_IP 自动取本机第一块网卡 IP）
# ============================================================================

export JAVA_HOME=/usr/lib/jvm/java-1.8.0-openjdk
export SCALA_HOME=/opt/scala
export HADOOP_HOME=/opt/hadoop
export HADOOP_CONF_DIR=/opt/hadoop/etc/hadoop
export YARN_CONF_DIR=/opt/hadoop/etc/hadoop
export SPARK_HOME=/opt/spark

# 关键：不设置会导致 "Initial job has not accepted any resources" 或绑定 127.0.0.1
# 自动取本机第一个非回环 IP，两台机器通用
export SPARK_LOCAL_IP=$(hostname -I | awk '{print $1}')

# ---- Standalone 集群（Master / Worker）----
export SPARK_MASTER_HOST=master
export SPARK_MASTER_PORT=7077
export SPARK_MASTER_WEBUI_PORT=8080
export SPARK_WORKER_WEBUI_PORT=8081

# 每个 Worker 只给 1 核 1.5 GB（4 GiB 机器的安全值）
export SPARK_WORKER_CORES=1
export SPARK_WORKER_MEMORY=1536m

# 提交任务时 driver 的默认堆
export SPARK_DRIVER_MEMORY=1g

# ---- 历史服务器 ----
export SPARK_HISTORY_OPTS="-Dspark.history.fs.logDirectory=hdfs://master:9000/spark-logs -Dspark.history.ui.port=18080"

# ---- PySpark 使用的 Python（CentOS 7 自带 3.6，Spark 3.5 要求 >= 3.8）----
export PYSPARK_PYTHON=/opt/miniconda3/bin/python3
export PYSPARK_DRIVER_PYTHON=/opt/miniconda3/bin/python3

# 让 Spark 能读到 hadoop 的原生库（压缩、校验和加速）
export LD_LIBRARY_PATH=$HADOOP_HOME/lib/native:$LD_LIBRARY_PATH
