# GRAFANA 备份与恢复

### 创建API KEY

![](.\images\grafna-01.png)

![](.\images\grafna-02.png)

复制API Key保存好

```shell
eyJrIjoiRVNVV2dVeGY4QndRa3BVVzkyeGlhU1BhZTM1aTJxWEoiLCJuIjoiZ3JhZmFuYS1kYXNoYm9hcmQtYmFja3VwIiwiaWQiOjF9

```

测试

```shell
curl -H "Authorization: Bearer eyJrIjoiRVNVV2dVeGY4QndRa3BVVzkyeGlhU1BhZTM1aTJxWEoiLCJuIjoiZ3JhZmFuYS1kYXNoYm9hcmQtYmFja3VwIiwiaWQiOjF9" https://grafana.addpchina.com/api/dashboards/home
```

### 下载镜像

打包上传到DC本地镜像仓库

```shell
docker pull ysde/docker-grafana-backup-tool:latest
```

### 创建备份

```shell
mkdir /tmp/backup
sudo chown 1337:1337 /tmp/backup

docker run --user $(id -u):$(id -g) --rm --name grafana-backup-tool \
           -e GRAFANA_TOKEN="eyJrIjoiRVNVV2dVeGY4QndRa3BVVzkyeGlhU1BhZTM1aTJxWEoiLCJuIjoiZ3JhZmFuYS1kYXNoYm9hcmQtYmFja3VwIiwiaWQiOjF9" \
           -e GRAFANA_URL=https://grafana.addpchina.com \
           -e GRAFANA_ADMIN_ACCOUNT=admin \
           -e GRAFANA_ADMIN_PASSWORD='admin@123' \
           -e VERIFY_SSL=False \
           -v /data/backup/service/grafana/:/opt/grafana-backup-tool/_OUTPUT_ \
           docker.addpchina.com/ysde/docker-grafana-backup-tool:latest
```

### 通过备份恢复

```shell
docker run --user $(id -u):$(id -g) --rm --name grafana-backup-tool \
           -e GRAFANA_TOKEN="eyJrIjoiNGZqTDEyeXNaY0RsMXNhbkNTSnlKN2M3bE1VeHdqVTEiLCJuIjoiZ3JhZmFuYS1iYWNrdXAiLCJpZCI6MX0=" \
           -e GRAFANA_URL=https://grafana.addpchina.com \
           -e GRAFANA_ADMIN_ACCOUNT=admin \
           -e GRAFANA_ADMIN_PASSWORD='admin@123' \
           -e VERIFY_SSL=False \
           -e RESTORE="true" \
           -e ARCHIVE_FILE="202204110523.tar.gz" \
           -v /tmp/backup/:/opt/grafana-backup-tool/_OUTPUT_ \
           docker.addpchina.com/ysde/docker-grafana-backup-tool:latest
```

### 创建计划任务

```
[root@backup-0 grafana]# cat /data/backup/service/grafana/grafana-backup.sh 
#!/bin/bash

logs="`date  +%F-%H%M`.log"
cd /data/backup/service/grafana/

docker run --user $(id -u):$(id -g) --rm --name grafana-backup-tool \
           -e GRAFANA_TOKEN="eyJrIjoiRVNVV2dVeGY4QndRa3BVVzkyeGlhU1BhZTM1aTJxWEoiLCJuIjoiZ3JhZmFuYS1kYXNoYm9hcmQtYmFja3VwIiwiaWQiOjF9" \
           -e GRAFANA_URL=https://grafana.addpchina.com \
           -e GRAFANA_ADMIN_ACCOUNT=admin \
           -e GRAFANA_ADMIN_PASSWORD='admin@123' \
           -e VERIFY_SSL=False \
           -v /data/backup/service/grafana/:/opt/grafana-backup-tool/_OUTPUT_ \
           docker.addpchina.com/ysde/docker-grafana-backup-tool:latest   > $logs 2>&1

find /data/backup/service/grafana/ -name "*log" -ctime -1 -exec rm -f {} \;

添加计划任务
[root@backup-0 grafana]# crontab -l
58 23 *  *  *  /usr/bin/python3.6 /data/backup/network/1.py
0  14 *  *  *  /bin/bash /data/backup/service/grafana/grafana-backup.sh
```

参考：https://github.com/ysde/grafana-backup-tool



### K8S部署cronjob

```shell
apiVersion: batch/v1beta1
kind: CronJob
metadata:
  name: grafana-backup
spec:
  schedule: "*/3 * * * *"
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: grafana-backup
            image: docker.addpchina.com/ysde/docker-grafana-backup-tool:latest
            imagePullPolicy: IfNotPresent
            env:
            - name: GRAFANA_TOKEN
              value: "eyJrIjoienNPQjNidlpMNEZyazlSSDI2OEppUkxhWUpyYVdMcHYiLCJuIjoiZ3JhZmFuYS1kYXNoYm9hcmQtYmFja3VwIiwiaWQiOjF9"
            - name: GRAFANA_URL
              value: "https://t-grafana.addpchina.com"
            - name: GRAFANA_ADMIN_ACCOUNT
              value: "admin"
            - name: GRAFANA_ADMIN_PASSWORD
              value: "admin@123"
            - name: VERIFY_SSL
              value: "False"
            volumeMounts:
            - mountPath: /opt/grafana-backup-tool/_OUTPUT_
              name: data
          volumes:
          - name: data
            hostPath:
              path: /opt/grafana-backup
          restartPolicy: OnFailure

 chown 1337:1337 /opt/grafana-backup
```

#####################

### 测试环境备份恢复测试

```shell
docker run --user $(id -u):$(id -g) --rm --name grafana-backup-tool \
           -e GRAFANA_TOKEN="eyJrIjoienNPQjNidlpMNEZyazlSSDI2OEppUkxhWUpyYVdMcHYiLCJuIjoiZ3JhZmFuYS1kYXNoYm9hcmQtYmFja3VwIiwiaWQiOjF9" \
           -e GRAFANA_URL=https://t-grafana.addpchina.com \
           -e GRAFANA_ADMIN_ACCOUNT=admin \
           -e GRAFANA_ADMIN_PASSWORD='admin@123' \
           -e VERIFY_SSL=False \
           -v /tmp/backup/:/opt/grafana-backup-tool/_OUTPUT_ \
           docker.addpchina.com/ysde/docker-grafana-backup-tool:latest

docker run --user $(id -u):$(id -g) --rm --name grafana-backup-tool \
           -e GRAFANA_TOKEN="eyJrIjoienNPQjNidlpMNEZyazlSSDI2OEppUkxhWUpyYVdMcHYiLCJuIjoiZ3JhZmFuYS1kYXNoYm9hcmQtYmFja3VwIiwiaWQiOjF9" \
           -e GRAFANA_URL=https://t-grafana.addpchina.com \
           -e GRAFANA_ADMIN_ACCOUNT=admin \
           -e GRAFANA_ADMIN_PASSWORD='admin@123' \
           -e VERIFY_SSL=False \
           -e RESTORE="true" \
           -e ARCHIVE_FILE="202204120335.tar.gz" \
           -v /tmp/backup/:/opt/grafana-backup-tool/_OUTPUT_ \
           docker.addpchina.com/ysde/docker-grafana-backup-tool:latest
```





