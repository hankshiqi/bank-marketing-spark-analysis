#!/usr/bin/env bash
# =============================================================================
# 01_系统初始化.sh  ——  两台节点都要执行（root）
# 作用：检查/修复 yum 源、创建 4 GB swap、时区、内核参数、目录、防火墙
# 用法：sudo bash 01_系统初始化.sh
# =============================================================================
set -u
echo "===== 1/6 检查 yum 源 ====="
if yum -y makecache >/dev/null 2>&1 && yum repolist enabled 2>/dev/null | grep -q .; then
  echo "[OK] yum 源可用（阿里云 ECS 默认走内网 mirrors.cloud.aliyuncs.com）"
else
  echo "[WARN] yum 源不可用，CentOS 7 已于 2024-06-30 EOL，正在切换到 vault 归档源"
  mkdir -p /etc/yum.repos.d/bak
  mv /etc/yum.repos.d/CentOS-*.repo /etc/yum.repos.d/bak/ 2>/dev/null || true
  cat > /etc/yum.repos.d/CentOS-Vault.repo <<'EOF'
[centos-vault-base]
name=CentOS-7.9.2009 - Base
baseurl=https://mirrors.aliyun.com/centos-vault/7.9.2009/os/$basearch/
gpgcheck=1
gpgkey=https://mirrors.aliyun.com/centos-vault/RPM-GPG-KEY-CentOS-7
enabled=1

[centos-vault-updates]
name=CentOS-7.9.2009 - Updates
baseurl=https://mirrors.aliyun.com/centos-vault/7.9.2009/updates/$basearch/
gpgcheck=1
gpgkey=https://mirrors.aliyun.com/centos-vault/RPM-GPG-KEY-CentOS-7
enabled=1

[centos-vault-extras]
name=CentOS-7.9.2009 - Extras
baseurl=https://mirrors.aliyun.com/centos-vault/7.9.2009/extras/$basearch/
gpgcheck=1
gpgkey=https://mirrors.aliyun.com/centos-vault/RPM-GPG-KEY-CentOS-7
enabled=1
EOF
  yum -y clean all && yum -y makecache
  echo "[INFO] 若仍失败，把 baseurl 换成 https://mirrors.tuna.tsinghua.edu.cn/centos-vault/7.9.2009/... 再试"
fi

echo "===== 2/6 基础工具 ====="
yum -y install wget vim net-tools lsof tar unzip rsync epel-release >/dev/null 2>&1 || \
  yum -y install wget vim net-tools lsof tar unzip rsync

echo "===== 3/6 时区 + 时钟 ====="
timedatectl set-timezone Asia/Shanghai 2>/dev/null || cp -f /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
yum -y install ntpdate >/dev/null 2>&1 && ntpdate -u ntp.aliyun.com >/dev/null 2>&1 || true
date

echo "===== 4/6 创建 4 GB Swap（4 GiB 物理内存的救命稻草）====="
if swapon --show | grep -q swapfile; then
  echo "[SKIP] swap 已存在"
else
  fallocate -l 4G /swapfile || dd if=/dev/zero of=/swapfile bs=1M count=4096
  chmod 600 /swapfile && mkswap /swapfile && swapon /swapfile
  grep -q '/swapfile' /etc/fstab || echo '/swapfile swap swap defaults 0 0' >> /etc/fstab
fi
# 尽量少用 swap，但不禁止（Spark driver 抖动能救命）
sysctl -w vm.swappiness=10
grep -q 'vm.swappiness' /etc/sysctl.conf || echo 'vm.swappiness=10' >> /etc/sysctl.conf
free -h

echo "===== 5/6 内核与文件句柄 ====="
cat >> /etc/security/limits.conf <<'EOF'
* soft nofile 65536
* hard nofile 65536
* soft nproc  65536
* hard nproc  65536
EOF
sysctl -w vm.overcommit_memory=1
grep -q 'vm.overcommit_memory' /etc/sysctl.conf || echo 'vm.overcommit_memory=1' >> /etc/sysctl.conf
sysctl -w net.core.somaxconn=1024

echo "===== 6/6 目录规划 + 防火墙 ====="
# 注意：/opt/hadoop、/opt/spark、/opt/scala 由后续安装脚本解压生成，
# 这里千万不要预先创建，否则安装脚本里的"目录已存在则跳过"判断会误判。
mkdir -p /opt/data
# 课程演示建议直接关闭防火墙（阿里云安全组已做外层防护）
systemctl disable --now firewalld 2>/dev/null || true
setenforce 0 2>/dev/null || true
sed -i 's/^SELINUX=enforcing/SELINUX=disabled/' /etc/selinux/config 2>/dev/null || true

echo "===== 完成，请 reboot ====="
echo "下一步：在控制台确认两台机器的【私网 IP】，然后编辑 02_主机名与免密.sh 顶部变量"
