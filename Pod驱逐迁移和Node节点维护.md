## 节点维护
1、设置节点不可调度
```
$ kubectl get node
NAME              STATUS   ROLES                  AGE    VERSION
k8s-0.novalocal   Ready    control-plane,master   130d   v1.20.7
k8s-1.novalocal   Ready    control-plane,master   130d   v1.20.7
k8s-2.novalocal   Ready    control-plane,master   130d   v1.20.7
k8s-3.novalocal   Ready    <none>                 130d   v1.20.7
k8s-4.novalocal   Ready    <none>                 130d   v1.20.7
k8s-5.novalocal   Ready    <none>                 130d   v1.20.7
k8s-6.novalocal   Ready    <none>                 130d   v1.20.7
k8s-7.novalocal   Ready    <none>                 130d   v1.20.7

$ kubectl cordon k8s-3.novalocal
node/k8s-3.novalocal cordoned

$ kubectl get node
NAME              STATUS                     ROLES                  AGE    VERSION
k8s-0.novalocal   Ready                      control-plane,master   130d   v1.20.7
k8s-1.novalocal   Ready                      control-plane,master   130d   v1.20.7
k8s-2.novalocal   Ready                      control-plane,master   130d   v1.20.7
k8s-3.novalocal   Ready,SchedulingDisabled   <none>                 130d   v1.20.7
k8s-4.novalocal   Ready                      <none>                 130d   v1.20.7
k8s-5.novalocal   Ready                      <none>                 130d   v1.20.7
k8s-6.novalocal   Ready                      <none>                 130d   v1.20.7
k8s-7.novalocal   Ready                      <none>                 130d   v1.20.7

```
2、驱逐节点上的pod
```
$ kubectl drain k8s-3.novalocal --delete-emptydir-data --ignore-daemonsets --force
```
参数说明：
--delete-local-data 即使pod使用了emptyDir也删除
--ignore-daemonsets 忽略deamonset控制器的pod，如果不忽略，deamonset控制器控制的pod被删除后可能马上又在此节点上启动起来,会成为死循环；
--force 不加force参数只会删除该NODE上由ReplicationController, ReplicaSet, DaemonSet,StatefulSet or Job创建的Pod，加了后还会删除'裸奔的pod'(没有绑定到任何replication controller)

3.维护结束
```
$ kubectl uncordon k8s-3.novalocal
```
