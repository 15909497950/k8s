# kubernetes pv,pvc文档及回收策略

## 回收策略：

当用户不再使用其存储卷时，他们可以从 API 中将 PVC 对象删除，从而允许该资源被回收再利用。PersistentVolume 对象的回收策略告诉集群，当其被从申领中释放时如何处理该数据卷。 目前，数据卷可以被 Retained（保留）、Recycled（回收）或 Deleted（删除）。

1、保留（Retain）

回收策略Retain使得用户可以手动回收资源。当 PersistentVolumeClaim 对象被删除时，PersistentVolume 卷仍然存在，对应的数据卷被视为"已释放（released）"。 由于卷上仍然存在着前一申领人的数据，该卷还不能用于其他申领。 管理员可以通过下面的步骤来手动回收该卷：

2、删除（Delete）

对于支持Delete回收策略的卷插件，删除动作会将 PersistentVolume 对象从 Kubernetes 中移除，同时也会从外部基础设施（如 AWS EBS、GCE PD、Azure Disk 或 Cinder 卷）中移除所关联的存储资产。 动态供应的卷会继承其 StorageClass 中设置的回收策略，该策略默认 为Delete。 管理员需要根据用户的期望来配置 StorageClass；否则 PV 卷被创建之后必须要被 编辑或者修补。

3、回收（Recycle）

警告：回收策略Recycle已被废弃。取而代之的建议方案是使用动态供应。

kubernetes 持久卷概念
PersistentVolume 子系统为用户和管理员提供了一组 API，将存储如何供应的细节从其如何被使用中抽象出来。为了实现这点，引入了一些新的资源和概念：

PV（PersistentVolume，持久卷），是集群中的一块存储，可以由管理员事先供应，或者使用存储类（Storage
Class）来动态供应。 持久卷是集群资源，就像节点也是集群资源一样。
PVC（PersistentVolumeClaim，持久卷申领），表达的是用户对存储的请求。 PVC申领请求特定的大小和访问模式的PV卷。
StorageClass（存储类），集群管理员需要能够提供不同性质的PersistentVolume，并且这些 PV卷之间的差别不仅限于卷大小和访问模式，同时又不能将卷是如何实现的这些细节暴露给用户。为了满足这类需求，就有了存储类（StorageClass）资源。
volume， 卷的核心是一个目录，其中可能存有数据，Pod 中的容器可以访问该目录中的数据。
volumeclaim， 使用卷时,在 .spec.volumes 字段中设置为 Pod 提供的卷，并在 .spec.containers[*].volumeMounts 字段中声明卷在容器中的挂载位置。

## 下面以NFS存储为例演示pv回收策略及如何复用被保留的pv卷。

### pv创建流程,配置回收策略为Retain

1、创建静态pv，定义存储容量、访问模式及回收策略，注意这里的回收策略为Retain保留：

```shell
[root@master hostpath]# cat pv.yaml 
apiVersion: v1
kind: PersistentVolume
metadata:
  name: task-pv-volume
  labels:
    type: local
spec:
  storageClassName: nfs
  capacity:
    storage: 10Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  nfs:
    server: 10.0.0.5
    path: "/nginx"

```

查看创建的pv，该pv状态为`Available` ，可用于pvc申请：

```shell
[root@master hostpath]# kubectl apply -f pv.yaml 

[root@master hostpath]# kubectl get pv
NAME                                       CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS      CLAIM                           STORAGECLASS   REASON   AGE
task-pv-volume                             10Gi       RWO            Retain           Available                                   nfs                     2s

```

2、创建pvc绑定到pv

```shell
[root@master hostpath]# cat pvc.yaml 
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: task-pv-claim
spec:
  storageClassName: nfs
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 3Gi

```

查看创建的pvc，此时pvc已经随机获取到一个可用pv并与其绑定，查看pvc及pv都为`Bound`状态

```shell
[root@master hostpath]# kubectl apply -f pvc.yaml 

[root@master hostpath]# kubectl get pvc
NAME            STATUS   VOLUME           CAPACITY   ACCESS MODES   STORAGECLASS   AGE
task-pv-claim   Bound    task-pv-volume   10Gi       RWO            nfs            3s

[root@master hostpath]# kubectl get pv
NAME                                       CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM                           STORAGECLASS   REASON   AGE
task-pv-volume                             10Gi       RWO            Retain           Bound    default/task-pv-claim           nfs                     2m58s

```

3、创建pod申请pvc

```shell
[root@master hostpath]# cat pod.yaml 
kind: Service
apiVersion: v1
metadata:
  name: task-pv-service
spec:
  ports:
    - port: 80
  type: NodePort
  selector:
    app: nginx
---
apiVersion: v1
kind: Pod
metadata:
  name: task-pv-pod
  labels:
    app: nginx 
spec:
  containers:
    - name: task-pv-container
      image: nginx
      ports:
        - containerPort: 80
          name: "http-server"
      volumeMounts:
        - mountPath: "/usr/share/nginx/html"
          name: task-pv-storage
  volumes:
    - name: task-pv-storage
      persistentVolumeClaim:
        claimName: task-pv-claim

```

查看创建的pod：

```shell
[root@master hostpath]# kubectl get pod
NAME          READY   STATUS    RESTARTS   AGE
task-pv-pod   1/1     Running   0          84s

[root@master hostpath]# kubectl get svc
NAME              TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)        AGE
task-pv-service   NodePort    10.233.11.207   <none>        80:31181/TCP   6s

```

向pod内写入测试数据，并连接到NFS Server查看持久化数据：

```shell
[root@master hostpath]# kubectl exec task-pv-pod -- sh -c "echo 'Hello from Kubernetes storage' > /usr/share/nginx/html/index.html"

[root@nfs-server nfs-share]# cat nginx/index.html 
Hello from Kubernetes storage

```

## 验证pv回收策略Retain

1、删除pod，该pvc及pv依然保留并处于绑定状态，因此删除pod对pvc及pv没有影响：

```shell
[root@product-cluster nfs-share]# kubectl delete pods task-pv-pod 

```

2、继续删除pvc，此时pv是否被删除取决于其回收策略，回收策略为`Delete`则pv也会被自动删除，回收策略为`Retain`则pv会被保留

```shell
[root@product-cluster nfs-share]# kubectl delete pvc task-pv-claim

```

可以看到pv依然保留，并且状态由Bound变为Released，该状态pv无法被新的pvc申领，只有PV处于Available状态时才能被pvc申领。

```shell
[root@product-cluster nfs-share]# kubectl get pv
NAME                                       CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS     CLAIM                           STORAGECLASS   REASON   AGE
task-pv-volume                             10Gi       RWO            Retain           Released   default/task-pv-claim           nfs                     10m

```

被保留下来的PV在`spec.claimRef`字段记录着原来PVC的绑定信息:

```shell
[root@product-cluster nfs-share]# kubectl get pv task-pv-volume -o yaml
apiVersion: v1
kind: PersistentVolume
......
spec:
  accessModes:
  - ReadWriteOnce
  capacity:
    storage: 10Gi
  claimRef:
    apiVersion: v1
    kind: PersistentVolumeClaim
    name: task-pv-claim
    namespace: default
    resourceVersion: "792426"
    uid: 325b013f-0467-4078-88e9-0fc208c6993c
  nfs:
    path: /nginx
    server: 10.0.0.5
  persistentVolumeReclaimPolicy: Retain
  storageClassName: nfs
  volumeMode: Filesystem
status:
  phase: Released

```

删除绑定信息中的`resourceVersion`和`uid`键，即可重新释放PV使其状态由Released变为Available

```shell
[root@product-cluster nfs-share]# kubectl edit pv task-pv-volume
......
spec:
  accessModes:
  - ReadWriteOnce
  capacity:
    storage: 10Gi
  claimRef:
    apiVersion: v1
    kind: PersistentVolumeClaim
    name: task-pv-claim
    namespace: default
......

```

再次查看pv状态已经变为Available

```shell
[root@product-cluster nfs-share]# kubectl get pv
NAME                                       CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS      CLAIM                           STORAGECLASS   REASON   AGE
task-pv-volume                             10Gi       RWO            Retain           Available   default/task-pv-claim           nfs                     20m

```

由于该pv中`spec.claimRef.name`和`spec.claimRef.namespace`键不变，该pv依然指向原来的pvc名称，具有相应spec的新PVC能够准确绑定到该PV。重新恢复之前删除的pvc及pod：

```shell
[root@master hostpath]# kubectl apply -f pvc.yaml

[root@master hostpath]# kubectl apply -f pod.yaml
查看pvc及pod状态
[root@master hostpath]# kubectl get pvc
NAME            STATUS   VOLUME           CAPACITY   ACCESS MODES   STORAGECLASS   AGE
task-pv-claim   Bound    task-pv-volume   10Gi       RWO            nfs            71s

[root@master hostpath]# kubectl get pv
NAME                                       CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM                           STORAGECLASS   REASON   AGE
task-pv-volume                             10Gi       RWO            Retain           Bound    default/task-pv-claim           nfs                     33m

[root@master hostpath]# kubectl get pods
NAME          READY   STATUS    RESTARTS   AGE
task-pv-pod   1/1     Running   0          62s
再次访问web应用，之前写入的数据依然存在，数据成功恢复：
```

## 配置pv回收策略Recycle

pv回收策略可以在多个地方定义。

```shell
1、在pv中定义回收策略
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv0003
spec:
  capacity:
    storage: 5Gi
  volumeMode: Filesystem
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Recycle
  storageClassName: slow
  mountOptions:
    - hard
    - nfsvers=4.1
  nfs:
    path: /tmp
    server: 172.17.0.2

```

2、在storageclass中定义pv回收策略

```shell
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
  name: gp2-retain
  annotations:
provisioner: kubernetes.io/aws-ebs
parameters:
  type: gp2
  fsType: ext4 
reclaimPolicy: Retain

```

修改pv回收策略
对于动态配置的PersistentVolumes来说，默认回收策略为 “Delete”。这表示当用户删除对应的PersistentVolumeClaim时，动态配置的 volume 将被自动删除。如果 volume 包含重要数据时，这种自动行为可能是不合适的。这种情况下，更适合使用 “Retain” 策略。使用 “Retain” 时，如果用户删除PersistentVolumeClaim，对应的PersistentVolume不会被删除。相反，它将变为Released状态，表示所有的数据可以被手动恢复。
使用如下命令可以修改pv回收策略：

```shell
kubectl patch pv <your-pv-name> -p '{"spec":{"persistentVolumeReclaimPolicy":"Retain"}}'

```

## 绑定pvc到特定pv

默认pvc会随机申请满足条件的任意pv，可以使用如下两种方式将pvc绑定到特定pv上：

1、在pvc中直接指定pv名称

```shell
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: foo-pvc
  namespace: foo
spec:
  storageClassName: "" # Empty string must be explicitly set otherwise default StorageClass will be set
  volumeName: foo-pv

```

首先需要保留该存储卷，claimRef在 PV的字段中指定相关的 PersistentVolumeClaim，以便其他 PVC 无法绑定到它。

```shell
apiVersion: v1
kind: PersistentVolume
metadata:
  name: foo-pv
spec:
  storageClassName: ""
  claimRef:
    name: foo-pvc
    namespace: foo

```

2、可以使用对 pv 打 label 的方式，具体如下：

```shell
创建 pv，指定 label
[root@server PV]# cat pv-test1.yaml   
kind: PersistentVolume
apiVersion: v1
metadata:
  name: test1-pv
  namespace: kubeflow
  labels:
    pv: test1
spec:
  capacity:
    storage: 100Mi
  accessModes:
    - ReadWriteOnce
  hostPath:
    path: "/data/test1"

```

然后创建 pvc，使用 matchLabel 来关联刚创建的 pv

```shell
[root@server PV]# cat pvc1.yaml 
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test2-pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 100Mi
  selector:
    matchLabels:
      pv: test1

```

