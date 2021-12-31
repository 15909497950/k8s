# 使用 kubeadm 创建一个高可用 etcd 集群

说明：
当 kubeadm 用作为外部 etcd 节点管理工具，请注意 kubeadm 不计划支持此类节点的证书更换或升级。对于长期规划是使用 etcdadm 增强工具来管理这方面。

默认情况下，kubeadm 运行单成员的 etcd 集群，该集群由控制面节点上的 kubelet 以静态 Pod 的方式进行管理。由于 etcd 集群只包含一个成员且不能在任一成员不可用时保持运行，所以这不是一种高可用设置。本任务，将告诉你如何在使用 kubeadm 创建一个 kubernetes 集群时创建一个外部 etcd：有三个成员的高可用 etcd 集群。

## 1. 将 kubelet 配置为 etcd 的服务管理器。
说明： 你必须在要运行 etcd 的所有主机上执行此操作。

由于 etcd 是首先创建的，因此你必须通过创建具有更高优先级的新文件来覆盖 kubeadm 提供的 kubelet 单元文件。

```
cat << EOF > /usr/lib/systemd/system/kubelet.service.d/20-etcd-service-manager.conf
[Service]
ExecStart=
# 将下面的 "systemd" 替换为你的容器运行时所使用的 cgroup 驱动。
# kubelet 的默认值为 "cgroupfs"。
ExecStart=/usr/bin/kubelet --address=127.0.0.1 --pod-manifest-path=/etc/kubernetes/manifests --cgroup-driver=systemd --pod-infra-container-image=registry.aliyuncs.com/google_containers/pause:3.2
Restart=always
EOF

systemctl daemon-reload
systemctl restart kubelet
```

## 2. 为 kubeadm 创建配置文件。
使用以下脚本为每个将要运行 etcd 成员的主机生成一个 kubeadm 配置文件。
```
# cat create_ssl.sh 
#!/bin/bash

# 使用 IP 或可解析的主机名替换 HOST0、HOST1 和 HOST2
export HOST0=192.168.26.11
export HOST1=192.168.26.12
export HOST2=192.168.26.13

# 创建临时目录来存储将被分发到其它主机上的文件
mkdir -p /tmp/${HOST0}/ /tmp/${HOST1}/ /tmp/${HOST2}/

ETCDHOSTS=(${HOST0} ${HOST1} ${HOST2})
NAMES=("etcd0" "etcd1" "etcd2")

for i in "${!ETCDHOSTS[@]}"; do
HOST=${ETCDHOSTS[$i]}
NAME=${NAMES[$i]}
cat << EOF > /tmp/${HOST}/kubeadmcfg.yaml
apiVersion: "kubeadm.k8s.io/v1beta2"
kind: ClusterConfiguration
etcd:
    local:
        serverCertSANs:
        - "${HOST}"
        peerCertSANs:
        - "${HOST}"
        extraArgs:
            initial-cluster: etcd0=https://${ETCDHOSTS[0]}:2380,etcd1=https://${ETCDHOSTS[1]}:2380,etcd2=https://${ETCDHOSTS[2]}:2380
            initial-cluster-state: new
            name: ${NAME}
            listen-peer-urls: https://${HOST}:2380
            listen-client-urls: https://${HOST}:2379
            advertise-client-urls: https://${HOST}:2379
            initial-advertise-peer-urls: https://${HOST}:2380
imageRepository: registry.aliyuncs.com/google_containers
kubernetesVersion: v1.20.1
EOF
done

# bash create_ssl.sh 
```
## 3. 生成证书颁发机构

如果你已经拥有 CA，那么唯一的操作是复制 CA 的 `crt` 和 `key` 文件到`etc/kubernetes/pki/etcd/ca.crt` 和 `/etc/kubernetes/pki/etcd/ca.key`。 复制完这些文件后继续下一步，“为每个成员创建证书”。

如果你还没有 CA，则在 `$HOST0`（你为 kubeadm 生成配置文件的位置）上运行此命令。

```
# kubeadm init phase certs etcd-ca
I0609 09:36:04.645431   15622 version.go:251] remote version is much newer: v1.21.1; falling back to: stable-1.20
[certs] Generating "etcd/ca" certificate and key
```
这一操作创建如下两个文件
/etc/kubernetes/pki/etcd/ca.crt
/etc/kubernetes/pki/etcd/ca.key
```
# ls /etc/kubernetes/pki/etcd/
ca.crt  ca.key
```

## 4. 为每个成员创建证书
```
export HOST0=192.168.26.11
export HOST1=192.168.26.12
export HOST2=192.168.26.13

kubeadm init phase certs etcd-server --config=/tmp/${HOST2}/kubeadmcfg.yaml
kubeadm init phase certs etcd-peer --config=/tmp/${HOST2}/kubeadmcfg.yaml
kubeadm init phase certs etcd-healthcheck-client --config=/tmp/${HOST2}/kubeadmcfg.yaml
kubeadm init phase certs apiserver-etcd-client --config=/tmp/${HOST2}/kubeadmcfg.yaml
cp -R /etc/kubernetes/pki /tmp/${HOST2}/
# 清理不可重复使用的证书
find /etc/kubernetes/pki -not -name ca.crt -not -name ca.key -type f -delete

kubeadm init phase certs etcd-server --config=/tmp/${HOST1}/kubeadmcfg.yaml
kubeadm init phase certs etcd-peer --config=/tmp/${HOST1}/kubeadmcfg.yaml
kubeadm init phase certs etcd-healthcheck-client --config=/tmp/${HOST1}/kubeadmcfg.yaml
kubeadm init phase certs apiserver-etcd-client --config=/tmp/${HOST1}/kubeadmcfg.yaml
cp -R /etc/kubernetes/pki /tmp/${HOST1}/
find /etc/kubernetes/pki -not -name ca.crt -not -name ca.key -type f -delete

kubeadm init phase certs etcd-server --config=/tmp/${HOST0}/kubeadmcfg.yaml
kubeadm init phase certs etcd-peer --config=/tmp/${HOST0}/kubeadmcfg.yaml
kubeadm init phase certs etcd-healthcheck-client --config=/tmp/${HOST0}/kubeadmcfg.yaml
kubeadm init phase certs apiserver-etcd-client --config=/tmp/${HOST0}/kubeadmcfg.yaml
# 不需要移动 certs 因为它们是给 HOST0 使用的

# 清理不应从此主机复制的证书
find /tmp/${HOST2} -name ca.key -type f -delete
find /tmp/${HOST1} -name ca.key -type f -delete
```
## 5. 复制证书和 kubeadm 配置
证书已生成，现在必须将它们移动到对应的主机。
```
export HOST0=192.168.26.11
export HOST1=192.168.26.12
export HOST2=192.168.26.13
cp /tmp/${HOST}/* ~
for HOST in ${HOST1} ${HOST2};do
USER=root
scp -r /tmp/${HOST}/* ${USER}@${HOST}:
ssh ${USER}@${HOST}  chown -R root:root pki
ssh ${USER}@${HOST}  mv pki /etc/kubernetes/
done
```
## 6. 确保已经所有预期的文件都存在
```
# ls -R /etc/kubernetes/pki/
/etc/kubernetes/pki/:
apiserver-etcd-client.crt  apiserver-etcd-client.key  etcd

/etc/kubernetes/pki/etcd:
ca.crt  healthcheck-client.crt  healthcheck-client.key  peer.crt  peer.key  server.crt  server.key

```
### 7. 创建静态 Pod 清单
既然证书和配置已经就绪，是时候去创建清单了。 在每台主机上运行 kubeadm 命令来生成 etcd 使用的静态清单。
```
# kubeadm init phase etcd local --config=kubeadmcfg.yaml
[etcd] Creating static Pod manifest for local etcd in "/etc/kubernetes/manifests"
```
## 8. 检查群集运行状况
```
# grep image /etc/kubernetes/manifests/etcd.yaml 
    image: registry.aliyuncs.com/google_containers/etcd:3.4.13-0

docker run --rm -it \
--net host \
-v /etc/kubernetes:/etc/kubernetes registry.aliyuncs.com/google_containers/etcd:3.4.13-0 etcdctl \
--cert /etc/kubernetes/pki/etcd/peer.crt \
--key /etc/kubernetes/pki/etcd/peer.key \
--cacert /etc/kubernetes/pki/etcd/ca.crt \
--endpoints https://192.168.26.11:2379 endpoint health --cluster
```

参考：https://kubernetes.io/zh/docs/setup/production-environment/tools/kubeadm/setup-ha-etcd-with-kubeadm/
