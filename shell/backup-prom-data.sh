#!/bin/bash

curl -XPOST https://prometheus.addpchina.com/api/v1/admin/tsdb/snapshot
# 因数据太大，不好拷贝到远程主机，请检查k8s-node-01,k8s-node-02节点本地目录/mnt/fast-disks/vol2/prometheus-db/snapshots
#backupdate=`date +%Y%m%d`
#cd /data/backup/service/prometheus
#
#for i in 5 9
#do
#   scp -rp 100.65.16.${i}:/mnt/fast-disks/vol2/prometheus-db/snapshots/${backupdate}* .
#done
#
#find /data/backup/service/prometheus -type d -ctime +45 -exec rm -f {} \;
