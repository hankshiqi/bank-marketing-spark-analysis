#!/usr/bin/env bash
# =============================================================================
# 99_自检.sh —— 答辩前 / 每次开机后跑一遍
# 用法：sudo bash 99_自检.sh
# 输出：直接可以截图的"体检报告"，也是课程报告里的佐证素材
# =============================================================================
set -u
source /etc/profile.d/bigdata.sh 2>/dev/null || true
PASS=0; FAIL=0
ok(){ echo "  [PASS] $1"; PASS=$((PASS+1)); }
ng(){ echo "  [FAIL] $1"; FAIL=$((FAIL+1)); }

echo "=================================================================="
echo " 大数据集群自检报告   $(date '+%Y-%m-%d %H:%M:%S')   主机：$(hostname)"
echo "=================================================================="

echo ""
echo "【1】系统"
echo "  内核/发行版 : $(uname -r) / $(cat /etc/redhat-release 2>/dev/null)"
echo "  CPU 核数    : $(nproc)"
free -h | sed 's/^/  /'
df -h / | sed 's/^/  /'

echo ""
echo "【2】主机名与 hosts"
hostname | grep -qE '^(master|worker1)$' && ok "hostname=$(hostname)" || ng "hostname 未规范（应为 master/worker1）"
getent hosts master && ok "master 解析正常" || ng "master 无法解析"
getent hosts worker1 && ok "worker1 解析正常" || ng "worker1 无法解析"

echo ""
echo "【3】免密登录"
for h in master worker1; do
  if ssh -o BatchMode=yes -o ConnectTimeout=5 $h hostname >/dev/null 2>&1; then
    ok "ssh $h 免密可用"
  else
    ng "ssh $h 免密失败"
  fi
done

echo ""
echo "【4】环境变量"
for v in JAVA_HOME HADOOP_HOME SPARK_HOME SCALA_HOME; do
  [[ -n "${!v:-}" ]] && ok "$v=${!v}" || ng "$v 未设置"
done
java -version 2>&1 | head -1 | sed 's/^/  /'
echo "  Scala: $(scala -version 2>&1 | head -1)"
echo "  Python: $(/opt/miniconda3/bin/python3 -V 2>&1)"

echo ""
echo "【5】Java 进程（jps）"
jps -l | sed 's/^/  /'
ROLE=$(hostname)
if [[ "$ROLE" == "master" ]]; then
  REQUIRED_PROCESSES=(NameNode DataNode ResourceManager NodeManager SecondaryNameNode)
else
  REQUIRED_PROCESSES=(DataNode NodeManager)
fi
for p in "${REQUIRED_PROCESSES[@]}"; do
  jps -l | grep -q $p && ok "$p 运行中" || ng "$p 未启动"
done
jps -l | grep -q Worker && ok "Spark Worker 运行中（本机为 Worker 节点）" || echo "  [INFO] 本机无 Spark Worker（master 未加入 workers 时正常）"

echo ""
echo "【6】HDFS"
if hdfs dfsadmin -safemode get 2>/dev/null | grep -q OFF; then ok "HDFS 不在安全模式"; else ng "HDFS 处于安全模式"; fi
echo "  活跃 DataNode 数：$(hdfs dfsadmin -report 2>/dev/null | grep -c '^Name:')"
hdfs dfsadmin -report 2>/dev/null | grep -E '^(Name|Hostname|DFS Remaining)' | head -8 | sed 's/^/  /'
hdfs dfs -mkdir -p /tmp/selftest 2>/dev/null
echo "hello bigdata course design" > /tmp/selftest.txt
if hdfs dfs -put -f /tmp/selftest.txt /tmp/selftest/ >/dev/null 2>&1 && \
   hdfs dfs -cat /tmp/selftest/selftest.txt >/dev/null 2>&1; then
  ok "HDFS 读写正常"
else
  ng "HDFS 读写失败"
fi

echo ""
echo "【7】YARN"
yarn node -list 2>/dev/null | grep -E 'Total Nodes|Node-Id' | head -5 | sed 's/^/  /'
yarn node -list 2>/dev/null | grep -q "RUNNING" && ok "有 NodeManager 处于 RUNNING" || ng "无可用 NodeManager"
echo "  队列资源："
yarn queue -status default 2>/dev/null | head -6 | sed 's/^/  /'

echo ""
echo "【8】Spark"
/opt/spark/bin/spark-submit --version 2>&1 | grep -E 'version|Scala' | head -2 | sed 's/^/  /'
if curl -s http://master:8080 | grep -qi spark; then ok "Spark Master UI (8080) 可访问"; else ng "Spark Master UI 不可访问"; fi

echo ""
echo "【9】端口监听"
for port in 9000 9870 8088 8080 7077 19888 18080; do
  if ss -lntp 2>/dev/null | grep -q ":$port "; then ok "端口 $port 监听中"; else echo "  [INFO] 端口 $port 未监听"; fi
done

echo ""
echo "=================================================================="
echo " 结果：PASS=$PASS  FAIL=$FAIL"
echo "=================================================================="
[[ $FAIL -eq 0 ]] && echo " ✅ 集群健康，可以去跑 WordCount 了" || echo " ❌ 请按上面 FAIL 项逐条排查"
