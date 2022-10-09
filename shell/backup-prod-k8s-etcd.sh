#!/bin/bash

backupdate=`date +%Y-%m-%d`
cd /data/backup/kubernetes/prod-k8s-etcd

for i in 3 4 8
do
   scp 100.65.16.${i}:/home/etcd-backup/*etcd-snapshot-${backupdate}*.db .
done

find /data/backup/kubernetes/prod-k8s-etcd -name "*.db" -ctime +45 -exec rm -f {} \;
