#!/usr/bin/env bash
# Public template: provide the actual node addresses and names at invocation time.
# Usage: sudo env MASTER_IP=... WORKER1_IP=... MASTER_NODE_NAME=... \
#   WORKER1_NODE_NAME=... bash 02_主机名与免密.sh <master|worker1>
set -u

: "${MASTER_IP:?Set MASTER_IP to the master's private IP}"
: "${WORKER1_IP:?Set WORKER1_IP to the worker's private IP}"
: "${MASTER_NODE_NAME:?Set MASTER_NODE_NAME to the master's current system name}"
: "${WORKER1_NODE_NAME:?Set WORKER1_NODE_NAME to the worker's current system name}"

MY_ROLE="${1:-}"
if [[ "$MY_ROLE" != "master" && "$MY_ROLE" != "worker1" ]]; then
  echo "Usage: sudo env MASTER_IP=... WORKER1_IP=... MASTER_NODE_NAME=... WORKER1_NODE_NAME=... bash $0 <master|worker1>"
  exit 1
fi

echo "===== 1/4 Set hostname ====="
hostnamectl set-hostname "$MY_ROLE"
grep -q "$MY_ROLE" /etc/hostname && echo "[OK] hostname=$(cat /etc/hostname)"

echo "===== 2/4 Configure /etc/hosts ====="
cp -f /etc/hosts "/etc/hosts.bak.$(date +%s)"
sed -i '/[[:space:]]master$/d;/[[:space:]]worker1$/d' /etc/hosts
cat >> /etc/hosts <<EOF
$MASTER_IP    master
$WORKER1_IP   worker1
$MASTER_IP    $MASTER_NODE_NAME
$WORKER1_IP   $WORKER1_NODE_NAME
EOF
getent hosts master worker1

echo "===== 3/4 Generate this node's SSH key if needed ====="
mkdir -p /root/.ssh && chmod 700 /root/.ssh
if [[ ! -f /root/.ssh/id_rsa ]]; then
  ssh-keygen -t rsa -b 2048 -P '' -f /root/.ssh/id_rsa -q
  echo "[OK] generated /root/.ssh/id_rsa"
else
  echo "[SKIP] SSH key already exists"
fi
touch /root/.ssh/authorized_keys
cat /root/.ssh/id_rsa.pub >> /root/.ssh/authorized_keys
chmod 600 /root/.ssh/authorized_keys
sort -u /root/.ssh/authorized_keys -o /root/.ssh/authorized_keys

echo "===== 4/4 Exchange public keys with the other node ====="
cat /root/.ssh/id_rsa.pub
echo "Append the public key above to the other node's /root/.ssh/authorized_keys."
echo "After both nodes are configured, verify from master:"
echo "  ssh -o StrictHostKeyChecking=no master hostname"
echo "  ssh -o StrictHostKeyChecking=no worker1 hostname"
