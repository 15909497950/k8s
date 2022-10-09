#!/bin/bash

backupdate=`date +%Y-%m-%d`
cd /data/backup/kubernetes/caas-k8s-etcd

for i in 71 153 157
do
   scp 100.65.34.${i}:/home/etcd-backup/*etcd-snapshot-${backupdate}*.db .
done

find /data/backup/kubernetes/caas-k8s-etcd -name "*.db" -ctime +45 -exec rm -f {} \;
