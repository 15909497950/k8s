# 解决 Kubeadm 添加新 Master 节点到集群出现 ETCD 健康检查失败错误

## master节点重新加入集群报错

```
# kubeadm join 10.128.25.237:7443 --token ajfcj9.d0n1fmvubbzc1dl0     --discovery-token-ca-cert-hash sha256:78ffc4bb87f4be7d2680e6b4167bcb699bf434e2cda97f4240758b6e095bdae9 --certificate-key e968e61a8e807147efa16e97cc2a19069b5eafdd921975936abc6e100255b247   --control-plane

... ...
[check-etcd] Checking that the etcd cluster is healthy
error execution phase check-etcd: etcd cluster is not healthy: failed to dial endpoint https://10.128.25.231:2379 with maintenance client: context deadline exceeded
To see the stack trace of this error execute with --v=5 or higher
```



## 查看ETCD节点：

```
# ETCDCTL_API=3 etcdctl --endpoints 127.0.0.1:2379 --cacert /etc/kubernetes/pki/etcd/ca.crt --cert /etc/kubernetes/pki/etcd/server.crt --key /etc/kubernetes/pki/etcd/server.key member list

5f0c762e6afe1b5, started, k8s-03, https://10.128.25.233:2380, https://10.128.25.233:2379, false
124d123bb5d273bd, started, k8s-01, https://10.128.25.231:2380, https://10.128.25.231:2379, false
71194ff7de65c3a2, started, k8s-02, https://10.128.25.232:2380, https://10.128.25.232:2379, false
```

## 删除ETCD节点：

```
ETCDCTL_API=3 etcdctl --endpoints 127.0.0.1:2379 --cacert /etc/kubernetes/pki/etcd/ca.crt --cert /etc/kubernetes/pki/etcd/server.crt --key /etc/kubernetes/pki/etcd/server.key member remove 124d123bb5d273bd
```

查看节点：

```
# ETCDCTL_API=3 etcdctl --endpoints 127.0.0.1:2379 --cacert /etc/kubernetes/pki/etcd/ca.crt --cert /etc/kubernetes/pki/etcd/server.crt --key /etc/kubernetes/pki/etcd/server.key member list

5f0c762e6afe1b5, started, k8s-03, https://10.128.25.233:2380, https://10.128.25.233:2379, false
71194ff7de65c3a2, started, k8s-02, https://10.128.25.232:2380, https://10.128.25.232:2379, false
```

## 查看kubeadm配置信息：

```
# kubectl describe configmaps kubeadm-config -n kube-system

Name:         kubeadm-config
Namespace:    kube-system
Labels:       <none>
Annotations:  <none>

Data
====

ClusterConfiguration:
----

apiServer:
  extraArgs:
    authorization-mode: Node,RBAC
  timeoutForControlPlane: 4m0s
apiVersion: kubeadm.k8s.io/v1beta2
certificatesDir: /etc/kubernetes/pki
clusterName: kubernetes
controlPlaneEndpoint: 10.128.25.237:7443
controllerManager: {}
dns:
  type: CoreDNS
etcd:
  local:
    dataDir: /var/lib/etcd
imageRepository: harbor.example.com/public
kind: ClusterConfiguration
kubernetesVersion: v1.20.1
networking:
  dnsDomain: cluster.local
  podSubnet: 10.2.0.0/16
  serviceSubnet: 10.1.0.0/16
scheduler: {}

ClusterStatus:
----

apiEndpoints:
  k8s-01:
    advertiseAddress: 10.128.25.231
    bindPort: 6443
  k8s-02:
    advertiseAddress: 10.128.25.232
    bindPort: 6443
  k8s-03:
    advertiseAddress: 10.128.25.233
    bindPort: 6443
apiVersion: kubeadm.k8s.io/v1beta2
kind: ClusterStatus

Events:  <none>
```



## 重新获得加入集群的命令

```
# kubeadm init phase upload-certs --upload-certs
...  ...
[upload-certs] Using certificate key:
9533ed43fa18ef01883df8f77b009f8b0993673cc986bedfe5a1729feb79e0c1

# kubeadm token create --print-join-command
kubeadm join 10.128.25.237:7443 --token ygsxnn.bo95xxkvgmx6vvh4     --discovery-token-ca-cert-hash sha256:78ffc4bb87f4be7d2680e6b4167bcb699bf434e2cda97f4240758b6e095bdae9 

master节点加入集群命令：
# kubeadm join 10.128.25.237:7443 --token ajfcj9.d0n1fmvubbzc1dl0     --discovery-token-ca-cert-hash sha256:78ffc4bb87f4be7d2680e6b4167bcb699bf434e2cda97f4240758b6e095bdae9  \
--control-plane  --certificate-key  e968e61a8e807147efa16e97cc2a19069b5eafdd921975936abc6e100255b247 

```

