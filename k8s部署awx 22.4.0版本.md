# k8s部署awx 22.4.0版本

需要提前准备k8s集群，由于用到了ingress暴露服务，需要提前部署ingress-nginx-controller(v1.3.0)

ingress-nginx-controller(v1.3.0)部署参考链接https://blog.csdn.net/weixin_43501172/article/details/126016524?spm=1001.2014.3001.5506

```shell
[root@node-1 awx-deploy-main]# kubectl get pods -n ingress-nginx -o wide
NAME                                        READY   STATUS      RESTARTS   AGE   IP              NODE     NOMINATED NODE   READINESS GATES
ingress-nginx-admission-create-xv8fj        0/1     Completed   0          24h   10.2.247.16     node-2   <none>           <none>
ingress-nginx-admission-patch-8s972         0/1     Completed   1          24h   10.2.247.15     node-2   <none>           <none>
ingress-nginx-controller-6686c99d5f-zw9mk   1/1     Running     0          24h   100.65.35.227   node-2   <none>           <none>
###awx-web域名的解析地址为 ingress-nginx-controller pod ip,也是主机IP，100.65.35.227,因为用的hostnetwork###
```

awx从17版本开始推荐使用https://github.com/ansible/awx-operator   项目部署，也就是部署在k8s集群中

先下载 git代码，此次部署的是awx-operator-2.3.0（awx 22.4.0）

```shell
git clone https://github.com/ansible/awx-operator.git
cd awx-operator
git checkout 2.3.0
$ Deploy AWX Operator
export NAMESPACE=awx
make deploy
需要执行段时间，因为要拉取镜像，如果是内网需要提前准备好镜像
```

```shell
[root@node-1 awx-deploy-main]# kubectl get pods -n awx
NAME                                               READY   STATUS    RESTARTS   AGE
awx-operator-controller-manager-594f8f54f9-bglhp   2/2     Running   0          7h10m
查看pod运行情况

后面配置账号密码证书和pv，pvc以及 kind awx
cat 01-secret.yaml
---
apiVersion: v1
kind: Secret
metadata:
  name: awx-postgres-configuration
  namespace: awx
stringData:
  host: awx-postgres   ###特别注意等pgsql pod运行后改为pod ip，否则无法连接数据库
  port: "5432"
  database: awx
  username: awx
  password: AnsibleRocks
  type: managed
type: Opaque

---
apiVersion: v1
kind: Secret
metadata:
  name: awx-admin-password
  namespace: awx
stringData:
  password: AnsibleRocks
type: Opaque

```

```shell
域名证书自签
#########自建域名证书####
AWX_WEB_FQDN="k8sawx.addpchina.com"
openssl req -x509 -nodes -days 3650 -newkey rsa:2048 -out tls-cert.pem -keyout tls-key.pem -subj "/CN=${AWX_WEB_FQDN}/O=${AWX_WEB_FQDN}" 
kubectl -n awx create secret tls awx-secret-tls --cert=./tls-cert.pem --key=tls-key.pem --dry-run=client -o yaml
复制yaml文件到01-secret.yaml
## kubectl apply -f 01-secret.yaml

```

```shell
[root@node-1 awx-deploy-main]# cat 02-pv.yaml 
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: awx-postgres-volume
  namespace: awx
spec:
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  capacity:
    storage: 8Gi
  storageClassName: awx-postgres-volume
  hostPath:
    path: /data/postgres

---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: awx-projects-volume
  namespace: awx
spec:
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  capacity:
    storage: 2Gi
  storageClassName: awx-projects-volume
  hostPath:
    path: /data/projects
####提前在机器创建目录/data/postgres，/data/projects，授予权限
chmod 755 /data/postgres/
chown 1000:0 /data/projects/
```

```shell
[root@node-1 awx-deploy-main]# cat 03-pvc.yaml 
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: awx-projects-claim
  namespace: awx
spec:
  accessModes:
    - ReadWriteOnce
  volumeMode: Filesystem
  resources:
    requests:
      storage: 2Gi
  storageClassName: awx-projects-volume

```

```shell
[root@node-1 awx-deploy-main]# cat 04-awx.yaml 
---
apiVersion: awx.ansible.com/v1beta1
kind: AWX
metadata:
  name: awx
  namespace: awx
spec:
  
  # Set the replicas count to scale AWX pods
  replicas: 1
  
  admin_user: admin
  admin_password_secret: awx-admin-password

  ingress_type: ingress
  ingress_tls_secret: awx-secret-tls
  hostname: k8sawx.addpchina.com    # Replace fqdn.awx.host.com with Host FQDN and DO NOT use IP.
##hostname 改为实际域名####
  postgres_configuration_secret: awx-postgres-configuration

  postgres_storage_class: awx-postgres-volume
  postgres_storage_requirements:
    requests:
      storage: 8Gi

  projects_persistence: true
  projects_existing_claim: awx-projects-claim
------------------------------------------------------------------------------
kubectl apply -f 02-pv.yaml
kubectl apply -f 03-pvc.yaml
kubectl apply -f 04-awx.yaml
[root@node-1 awx-deploy-main]# kubectl get awx -n awx
NAME   AGE
awx    25h

```

```shell
[root@node-1 awx-deploy-main]# kubectl get all -n awx
NAME                                                   READY   STATUS    RESTARTS   AGE
pod/awx-operator-controller-manager-594f8f54f9-bglhp   2/2     Running   0          7h23m
pod/awx-postgres-13-0                                  1/1     Running   0          25h
pod/awx-task-7b79cd989-nsn8z                           4/4     Running   0          3h12m
pod/awx-web-65d59977c5-x6hvp                           3/3     Running   0          3h1m

NAME                                                      TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)    AGE
service/awx-operator-controller-manager-metrics-service   ClusterIP   10.100.169.79   <none>        8443/TCP   31h
service/awx-postgres-13                                   ClusterIP   None            <none>        5432/TCP   25h
service/awx-service                                       ClusterIP   10.101.41.64    <none>        80/TCP     25h

NAME                                              READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/awx-operator-controller-manager   1/1     1            1           31h
deployment.apps/awx-task                          1/1     1            1           25h
deployment.apps/awx-web                           1/1     1            1           25h

NAME                                                         DESIRED   CURRENT   READY   AGE
replicaset.apps/awx-operator-controller-manager-594f8f54f9   1         1         1       25h
replicaset.apps/awx-operator-controller-manager-7c8db4fc5c   0         0         0       31h
replicaset.apps/awx-task-5488cf9695                          0         0         0       25h
replicaset.apps/awx-task-58f6d67bcd                          0         0         0       3h14m
replicaset.apps/awx-task-7b79cd989                           1         1         1       3h12m
replicaset.apps/awx-web-557dd67688                           0         0         0       3h14m
replicaset.apps/awx-web-65d59977c5                           1         1         1       3h12m
replicaset.apps/awx-web-86d5b75f65                           0         0         0       25h

NAME                               READY   AGE
statefulset.apps/awx-postgres-13   1/1     25h

```

```shell
由于我们使用的ingress class是nginx，所以要指定awx的ingress class
···
spec:
  ingressClassName: nginx  ###添加这行
  rules:
  - host: k8sawx.addpchina.com
    http:
      paths:
      - backend:
·····
```

