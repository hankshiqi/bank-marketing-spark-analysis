# Hadoop 与 Spark 双节点部署

本目录提供课程实验使用的 Hadoop 3.3.6 / Spark 3.5.x 配置模板，按一台 master 和一台 worker1 编写。配置仅使用主机别名，不包含任何云账号、实例 ID 或实际服务器地址。请先在私有网络中准备 Linux 主机和 SSH 访问，再按自己的操作系统与资源规格检查脚本后执行。

## 节点配置

1. 在两台机器之间配置 SSH 公钥认证，并确认双方私网地址可互通。
2. 复制 `scripts/02_主机名与免密.example.sh` 为 `scripts/02_主机名与免密.sh`。在执行时通过环境变量提供两台节点的私网 IP 和原系统主机名；不要把实际地址提交到公开仓库。
3. 两台机器分别执行系统初始化、节点名称设置和 JDK/Python 安装。主节点再执行 Hadoop/Spark 部署与自检脚本。
4. 复核 `conf/` 中目录、内存、端口和副本数配置，再启动 HDFS、YARN 和 Spark。

节点名称配置示例（将示例地址替换为自己 VPC 内的私网地址）：

```bash
sudo env MASTER_IP=10.0.0.10 WORKER1_IP=10.0.0.11 \
  MASTER_NODE_NAME=master WORKER1_NODE_NAME=worker1 \
  bash scripts/02_主机名与免密.sh master
```

在 worker 节点上使用相同的变量，将最后一个参数改为 `worker1`。按实际情况调整示例节点名。不要将 SSH 私钥、`authorized_keys` 内容或真实 IP 地址加入版本控制。

## 执行脚本

以下命令仅说明顺序；脚本会修改系统配置，请先阅读内容并按自己的发行版、账号和磁盘布局核对：

```bash
sudo bash scripts/01_系统初始化.sh
sudo bash scripts/03_安装JDK与Python.sh
sudo bash scripts/04_部署Hadoop与Spark.sh
sudo bash scripts/99_自检.sh
```

`01`、`03` 和 `04` 的软件版本、安装路径与发行版假设应先确认。两台机器之间的免密访问须单独配置完成后再部署 Hadoop/Spark。

## 网络安全

SSH 仅允许可信来源访问。HDFS、YARN、MapReduce 和 Spark 管理端口应限制在私有网络或可信来源内；不要把管理界面端口开放给 `0.0.0.0/0`。确需远程查看时，优先使用 SSH 隧道或受控的 VPN/堡垒机。
