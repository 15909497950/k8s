# 修改k8s 节点docker  kubelet工作目录

## 一、设置节点不可调度和驱赶POD（master节点操作)

```shell
# kubectl get node 
# kubectl cordon <node>  ##设置节点为不可调度状态
# kubectl drain <node> --delete-emptydir-data --ignore-daemonsets --force  ##驱逐该节点上的pod
 
实例
[uatk8s@ansible ~]$ kubectl drain k8s-3.novalocal --delete-emptydir-data --ignore-daemonsets --force
node/k8s-3.novalocal already cordoned
WARNING: ignoring DaemonSet-managed Pods: kube-system/calico-node-pglcj, kube-system/kube-proxy-srbds, kube-system/node-local-dns-p5k8m, local-volume/local-volume-provisioner-5f98t
node/k8s-3.novalocal drained
[uatk8s@ansible ~]$ kubectl get pod -A -o wide |grep k8s-3.novalocal
kube-system    calico-node-pglcj                         1/1     Running   0          170d   172.16.2.102   k8s-3.novalocal   <none>           <none>
kube-system    kube-proxy-srbds                          1/1     Running   0          170d   172.16.2.102   k8s-3.novalocal   <none>           <none>
kube-system    node-local-dns-p5k8m                      1/1     Running   0          168d   172.16.2.102   k8s-3.novalocal   <none>           <none>
local-volume   local-volume-provisioner-5f98t            1/1     Running   0          170d   10.2.19.193    k8s-3.novalocal   <none>           <none>

```

## 二、去需要修改工作目录节点执行

### 配置数据盘做lvm，并挂载lvm到/data目录

```shell
pvcreate /dev/nvme0n1
vgcreate vgdata /dev/nvme0n1
lvcreate -n lvdata -L 1500G vgdata
mkdir /data
mkfs.xfs /dev/vgdata/lvdata 
echo "/dev/mapper/vgdata-lvdata /data xfs defaults 0 0" >> /etc/fstab 
mount -a
```



### 修改docker数据目录为/data/docker

docker info | grep -i dir

 Docker Root Dir: /var/lib/docker  ##默认目录

```shell
1、先停kubelet（不停该服务会导致容器无法停止，容器会一直启动)
systemctl stop kubelet.service  
查看当前容器
[root@k8s-3 data]# docker ps
CONTAINER ID        IMAGE               CREATED             STATE               NAME                ATTEMPT             POD ID
aa0a506559e31       780a7bc34ed2b       14 minutes ago      Running             calico-node         0                   9483717004b4b
4288dedc32d67       878d033518e56       14 minutes ago      Running             provisioner         0                   217a504d970ed
5826773915745       ff54c88b8ecfa       14 minutes ago      Running             kube-proxy          0                   157956d453f1e
2486ae5ebeff8       21fc69048bd5d       15 minutes ago      Running             node-cache          0                   75c5781f681ca
##停止所有运行的容器
docker ps |awk '{print $1}'|xargs docker stop
###containerd需要使用工具（nerdctl ps --namespace k8s.io |awk '{print $1}' |xargs -i nerdctl stop --namespace k8s.io {}）
2.再停dockerd
systemctl stop docker.service
2、拷贝数据到新目录
rsync -avz /var/lib/docker /data/
拷完数据修改docker数据目录
sed -i 's%/var/lib%/data%g' /etc/systemd/system/docker.service.d/docker-options.conf
启动 kubelet
systemctl daemon-reload &&systemctl restart kubelet.service
检查systemctl status kubelet.service
启动docker
systemctl daemon-reload && systemctl restart docker.service
docker info | grep -i dir
 Docker Root Dir: /data/docker
 
```

### 修改kubelet目录（不在根分区的话，需要设置到docker的子目录)

```shell
rsync -avzh --progress /var/lib/kubelet /data/docker/  #拷贝数据到新目录
修改/etc/kubernetes/kubelet.env配置文件
写入 ROOT_DIR="--root-dir=/data/docker/kubelet"
sed -i '4a ROOT_DIR="--root-dir=/data/docker/kubelet"' /etc/kubernetes/kubelet.env
修改/etc/systemd/system/kubelet.service添加ROOT_DIR参数
root@k8s-node-19:/etc/systemd/system# cat kubelet.service 
[Unit]
Description=Kubernetes Kubelet Server
Documentation=https://github.com/GoogleCloudPlatform/kubernetes
After=docker.service
Wants=docker.socket

[Service]
User=root
EnvironmentFile=-/etc/kubernetes/kubelet.env
ExecStart=/usr/local/bin/kubelet \
		$KUBE_LOGTOSTDERR \
		$KUBE_LOG_LEVEL \
		$KUBELET_API_SERVER \
		$KUBELET_ADDRESS \
		$KUBELET_PORT \
		$KUBELET_HOSTNAME \
		$KUBELET_ARGS \
		$DOCKER_SOCKET \
		$KUBELET_NETWORK_PLUGIN \
		$KUBELET_VOLUME_PLUGIN \
		$KUBELET_CLOUDPROVIDER \
        $ROOT_DIR 
Restart=always
RestartSec=10s

[Install]
WantedBy=multi-user.target
#######################
umount $(df -HT | grep '/var/lib/kubelet/pods' | awk '{print $7}') ##卸载旧目录

```



## 三、取消node禁止调度

恢复节点调度

```shell
kubectl uncordon <node>
kubectl get nodes
```

