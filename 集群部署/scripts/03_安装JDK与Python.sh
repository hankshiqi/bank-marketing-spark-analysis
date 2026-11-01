#!/usr/bin/env bash
# Install the project runtime on either CentOS 7 node.
set -euo pipefail

JAVA_HOME=/usr/lib/jvm/java-1.8.0-openjdk
MINICONDA_PREFIX=/opt/miniconda3
SCALA_PREFIX=/opt/scala
SCALA_VER=2.12.18
MINICONDA_FILE=Miniconda3-py310_23.1.0-1-Linux-x86_64.sh

download() {
  local url="$1" dest="$2"
  curl --fail --location --retry 3 --connect-timeout 20 --max-time 1800 \
    "$url" --output "${dest}.part"
  test -s "${dest}.part"
  mv "${dest}.part" "$dest"
}

preserve_incomplete() {
  local path="$1"
  if [[ -e "$path" ]]; then
    mv "$path" "${path}.incomplete.$(date +%Y%m%d%H%M%S)"
  fi
}

echo "===== 1/5 Install OpenJDK 8 ====="
if [[ ! -x "$JAVA_HOME/bin/java" ]]; then
  yum -y install java-1.8.0-openjdk java-1.8.0-openjdk-devel
fi
"$JAVA_HOME/bin/java" -version

echo "===== 2/5 Install Python 3.10 compatible with CentOS 7 ====="
if [[ ! -x "$MINICONDA_PREFIX/bin/python3" ]]; then
  preserve_incomplete "$MINICONDA_PREFIX"
  installer="/tmp/$MINICONDA_FILE"
  download "https://repo.anaconda.com/miniconda/$MINICONDA_FILE" "$installer"
  bash "$installer" -b -p "$MINICONDA_PREFIX"
fi
"$MINICONDA_PREFIX/bin/python3" -c 'import sys; assert sys.version_info >= (3, 8); print(sys.version)'

echo "===== 3/5 Install project Python dependencies ====="
"$MINICONDA_PREFIX/bin/python3" -m pip install --disable-pip-version-check --prefer-binary \
  -i https://mirrors.aliyun.com/pypi/simple/ \
  pyspark==3.5.1 pandas==2.0.3 numpy==1.24.4 pyarrow==14.0.2 \
  flask==3.0.3 flask-cors==6.0.5 jieba

echo "===== 4/5 Install Scala 2.12 ====="
if [[ ! -x "$SCALA_PREFIX/bin/scala" ]]; then
  preserve_incomplete "$SCALA_PREFIX"
  archive="/tmp/scala-${SCALA_VER}.tgz"
  download "https://downloads.lightbend.com/scala/${SCALA_VER}/scala-${SCALA_VER}.tgz" "$archive"
  tar -tzf "$archive" >/dev/null
  tar -xzf "$archive" -C /opt
  mv "/opt/scala-${SCALA_VER}" "$SCALA_PREFIX"
fi
"$SCALA_PREFIX/bin/scala" -version 2>&1

echo "===== 5/5 Configure environment ====="
cat > /etc/profile.d/bigdata.sh <<'EOF'
# Big data course runtime environment
export JAVA_HOME=/usr/lib/jvm/java-1.8.0-openjdk
export SCALA_HOME=/opt/scala
export HADOOP_HOME=/opt/hadoop
export HADOOP_CONF_DIR=/opt/hadoop/etc/hadoop
export YARN_CONF_DIR=$HADOOP_CONF_DIR
export SPARK_HOME=/opt/spark
export CONDA_HOME=/opt/miniconda3
export PYSPARK_PYTHON=/opt/miniconda3/bin/python3
export PYSPARK_DRIVER_PYTHON=/opt/miniconda3/bin/python3
export HIVE_HOME=/opt/hive
export PATH=$JAVA_HOME/bin:$SCALA_HOME/bin:$HADOOP_HOME/bin:$HADOOP_HOME/sbin:$SPARK_HOME/bin:$HIVE_HOME/bin:$CONDA_HOME/bin:$PATH
EOF
chmod 755 /etc/profile.d/bigdata.sh
source /etc/profile.d/bigdata.sh
printf 'JAVA_HOME=%s\n' "$JAVA_HOME"
java -version
python3 -V
echo "RUNTIME_OK"
