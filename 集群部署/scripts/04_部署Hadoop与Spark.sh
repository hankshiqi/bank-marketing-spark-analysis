#!/usr/bin/env bash
# =============================================================================
# 04_部署Hadoop与Spark.sh —— 只在 master 上执行（root）
# 前提：① 01/02/03 三个脚本已在两台机器执行完
#       ② 两台机器 ssh 免密已通（ssh worker1 hostname 不需要密码）
#       ③ conf/ 目录与本脚本同级
# 用法：sudo bash 04_部署Hadoop与Spark.sh
# =============================================================================
set -eu

# ======== 版本（如需更换改这里）========
HADOOP_VER="3.3.6"
SPARK_VER="3.5.1"
HADOOP_TGZ="hadoop-${HADOOP_VER}.tar.gz"
SPARK_TGZ="spark-${SPARK_VER}-bin-hadoop3.tgz"
MIRROR="https://repo.huaweicloud.com/apache"
ARCHIVE="https://archive.apache.org/dist"
# =======================================

CONF_DIR="$(cd "$(dirname "$0")/../conf" && pwd)"
cd /opt

echo "===== 1/8 下载 Hadoop ${HADOOP_VER} ====="
if [[ -d /opt/hadoop ]]; then
  echo "[SKIP] /opt/hadoop 已存在"
else
  wget -c "${MIRROR}/hadoop/common/hadoop-${HADOOP_VER}/${HADOOP_TGZ}" -O /tmp/${HADOOP_TGZ} || \
  wget -c "${ARCHIVE}/hadoop/common/hadoop-${HADOOP_VER}/${HADOOP_TGZ}" -O /tmp/${HADOOP_TGZ}
  tar -zxf /tmp/${HADOOP_TGZ} -C /opt/
  mv /opt/hadoop-${HADOOP_VER} /opt/hadoop
fi

echo "===== 2/8 下载 Spark ${SPARK_VER} ====="
if [[ -d /opt/spark ]]; then
  echo "[SKIP] /opt/spark 已存在"
else
  wget -c "${MIRROR}/spark/spark-${SPARK_VER}/${SPARK_TGZ}" -O /tmp/${SPARK_TGZ} || \
  wget -c "${ARCHIVE}/spark/spark-${SPARK_VER}/${SPARK_TGZ}" -O /tmp/${SPARK_TGZ}
  tar -zxf /tmp/${SPARK_TGZ} -C /opt/
  mv /opt/spark-${SPARK_VER}-bin-hadoop3 /opt/spark
fi

echo "===== 3/8 应用配置文件 ====="
cp -f "${CONF_DIR}/core-site.xml"    /opt/hadoop/etc/hadoop/
cp -f "${CONF_DIR}/hdfs-site.xml"    /opt/hadoop/etc/hadoop/
cp -f "${CONF_DIR}/mapred-site.xml"  /opt/hadoop/etc/hadoop/
cp -f "${CONF_DIR}/yarn-site.xml"    /opt/hadoop/etc/hadoop/
cp -f "${CONF_DIR}/workers"          /opt/hadoop/etc/hadoop/workers

# hadoop-env.sh 追加（幂等：先删掉上次追加的标记段）
grep -q "大数据课程设计" /opt/hadoop/etc/hadoop/hadoop-env.sh 2>/dev/null || {
  echo "" >> /opt/hadoop/etc/hadoop/hadoop-env.sh
  echo "# ===== 大数据课程设计 追加段 =====" >> /opt/hadoop/etc/hadoop/hadoop-env.sh
  cat "${CONF_DIR}/hadoop-env.append.sh" >> /opt/hadoop/etc/hadoop/hadoop-env.sh
}

cp -f "${CONF_DIR}/spark-env.sh"       /opt/spark/conf/
cp -f "${CONF_DIR}/spark-defaults.conf" /opt/spark/conf/
cp -f "${CONF_DIR}/workers"            /opt/spark/conf/workers
chmod +x /opt/spark/conf/spark-env.sh
chmod -R 755 /opt/hadoop /opt/spark

echo "===== 4/8 创建 HDFS 数据目录 ====="
mkdir -p /opt/hadoop/data/{tmp,name,data} /opt/hadoop/{logs,pids}

echo "===== 5/8 分发到 worker1 ====="
for h in worker1; do
  echo "--> rsync 到 $h"
  ssh root@$h "mkdir -p /opt/hadoop/data/{tmp,name,data} /opt/hadoop/{logs,pids}"
  rsync -a --delete-after --exclude='logs/*' --exclude='pids/*' --exclude='data/*' \
        /opt/hadoop/ root@$h:/opt/hadoop/
  rsync -a --delete-after /opt/spark/ root@$h:/opt/spark/
  rsync -a /etc/profile.d/bigdata.sh root@$h:/etc/profile.d/
done

echo "===== 6/8 格式化 NameNode（只在首次部署执行！）====="
if [[ -d /opt/hadoop/data/name/current ]]; then
  echo "[WARN] 检测到已存在 NameNode 元数据，跳过格式化。"
  echo "       确需重来请执行："
  echo "       rm -rf /opt/hadoop/data/name/* /opt/hadoop/data/data/* && 两台都执行"
else
  hdfs namenode -format -force -nonInteractive
fi

echo "===== 7/8 启动 HDFS + YARN ====="
start-dfs.sh
start-yarn.sh
mapred --daemon start historyserver || true

echo "===== 8/8 创建 Spark 日志目录并启动 Standalone ====="
hdfs dfs -mkdir -p /spark-logs && hdfs dfs -chmod 777 /spark-logs
/opt/spark/sbin/start-all.sh

echo ""
echo "========== 自检 =========="
sleep 5
jps
hdfs dfsadmin -report | head -20
/opt/spark/bin/spark-submit --version 2>/dev/null | head -5
echo ""
echo "Web UI："
echo "  HDFS   http://<master公网IP>:9870"
echo "  YARN   http://<master公网IP>:8088"
echo "  Spark  http://<master公网IP>:8080"
echo "  JobHist http://<master公网IP>:19888"
