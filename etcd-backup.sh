#!/bin/bash

date;

CACERT="/etc/ssl/etcd/ssl/ca.pem"
CERT="/etc/ssl/etcd/ssl/member-`hostname`.pem"
EKY="/etc/ssl/etcd/ssl/member-`hostname`-key.pem"
ENDPOINTS="https://127.0.0.1:2379"

ETCDCTL_API=3 /usr/local/bin/etcdctl \
--cacert="${CACERT}" --cert="${CERT}" --key="${EKY}" \
--endpoints=${ENDPOINTS} \
snapshot save /home/etcd-backup/`hostname`-etcd-snapshot-`date +%Y-%m-%d-%H%M`.db

# 备份保留30天
find /home/etcd-backup/ -type f -name "*.db" -mtime +30 -exec rm -f {} \;

示例
#!/bin/bash

/usr/local/bin/etcdctl snapshot save \
  --endpoints="https://127.0.0.1:2379" \
  --cacert="/etc/kubernetes/pki/etcd/ca.crt" \
  --cert="/etc/kubernetes/pki/etcd/server.crt" \
  --key="/etc/kubernetes/pki/etcd/server.key" \
  "/var/lib/etcd-backup/etcd-snapshot-`date +%Y%m%d-%H%M%S`.db"
