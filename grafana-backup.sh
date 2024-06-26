#!/bin/bash

logs="`date  +%F-%H%M`.log"
cd /data/backup/service/grafana/

docker run --user $(id -u):$(id -g) --rm --name grafana-backup-tool \
           -e GRAFANA_TOKEN="eyJrIjoiRVNVV2dVeGY4QndRa3BVVzkyeGlhU1BhZTM1aTJxWEoiLCJuIjoiZ3JhZmFuYS1kYXNoYm9hcmQtYmFja3VwIiwiaWQiOjF9" \
           -e GRAFANA_URL=https://grafana.test.com \
           -e GRAFANA_ADMIN_ACCOUNT=admin \
           -e GRAFANA_ADMIN_PASSWORD='admin@123' \
           -e VERIFY_SSL=False \
           -v /data/backup/service/grafana/:/opt/grafana-backup-tool/_OUTPUT_ \
           docker.test.com/ysde/docker-grafana-backup-tool:latest   > $logs 2>&1

find /data/backup/service/grafana/ -name "*log" -type f -ctime +30 -exec rm -f {} \;
find /data/backup/service/grafana/ -name "*.tar.gz" -type f -ctime +30 -exec rm -f {} \;
find /data/backup/service/grafana/dashboard_versions/ -type d -ctime +30 -exec rm -rf {} \;
