# ============================================================================
# 文件名：hadoop-env.sh 的追加内容
# 路径：$HADOOP_HOME/etc/hadoop/hadoop-env.sh（追加到文件末尾）
# 说明：Hadoop 3 默认 JVM 堆是按物理内存比例算的，4 GiB 机器上会直接把内存吃光，
#       必须在这里逐个守护进程写死堆大小。
# ============================================================================

# 只写目录，不写 bin 下的可执行文件
export JAVA_HOME=/usr/lib/jvm/java-1.8.0-openjdk

export HADOOP_HOME=/opt/hadoop
export HADOOP_CONF_DIR=/opt/hadoop/etc/hadoop
export HADOOP_PID_DIR=/opt/hadoop/pids
export HADOOP_LOG_DIR=/opt/hadoop/logs
export HADOOP_SECURE_PID_DIR=/opt/hadoop/pids
export HADOOP_SECURE_LOG_DIR=/opt/hadoop/logs

# root 运行必须显式声明（Hadoop 3 默认禁止 root 启动守护进程，除非置此项）
export HDFS_NAMENODE_USER=root
export HDFS_DATANODE_USER=root
export HDFS_SECONDARYNAMENODE_USER=root
export YARN_RESOURCEMANAGER_USER=root
export YARN_NODEMANAGER_USER=root
export MAPRED_HISTORYSERVER_USER=root

# ---- 关键：4 GiB 机器的堆大小 ----
export HDFS_NAMENODE_OPTS="-Xmx512m -Xms512m -XX:+UseParallelGC"
export HDFS_DATANODE_OPTS="-Xmx320m -Xms320m -XX:+UseParallelGC"
export HDFS_SECONDARYNAMENODE_OPTS="-Xmx320m -Xms320m"
export YARN_RESOURCEMANAGER_OPTS="-Xmx512m -Xms512m"
export YARN_NODEMANAGER_OPTS="-Xmx384m -Xms384m"
export YARN_PROXYSERVER_OPTS="-Xmx256m"
export MAPRED_HISTORYSERVER_OPTS="-Xmx320m"

# 历史服务器需要显式指定配置目录
export HADOOP_MAPRED_HOME=$HADOOP_HOME
export HADOOP_COMMON_HOME=$HADOOP_HOME
export HADOOP_HDFS_HOME=$HADOOP_HOME
export HADOOP_YARN_HOME=$HADOOP_HOME
