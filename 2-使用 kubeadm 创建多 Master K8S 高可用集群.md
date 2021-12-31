# 使用 kubeadm 命令创建多 Master K8S 高可用集群
### 集群架构图
<img src=".\images\etcd-ha-1.png" style="zoom:80%;" />

## 一、集群规划
| 主机名 | IP地址        |                             组件                             |
| :----: | ------------- | :----------------------------------------------------------: |
| k8s-01 | 10.128.25.231 | etcd、apiserver、scheduler、controller-manager、kubeadm、kubeclt、kubelet、kube-proxy、nginx、keepalive |
| k8s-02 | 10.128.25.232 | etcd、apiserver、scheduler、controller-manager、kubeadm、kubeclt、kubelet、kube-proxy、nginx、keepalive |
| k8s-03 | 10.128.25.233 | etcd、apiserver、scheduler、controller-manager、kubeadm、kubeclt、kubelet、kube-proxy、nginx、keepalive |
| k8s-04 | 10.128.25.234 |                 kubeadm、kubelet、kube-proxy                 |
| k8s-05 | 10.128.25.235 |                 kubeadm、kubelet、kube-proxy                 |
| k8s-06 | 10.128.25.236 |                 kubeadm、kubelet、kube-proxy                 |

## 二、系统优化
参考：《0-系统优化及安装docker和kubeadm》文档

## 三、配置API Server HA：
haproxy + keepalived 高可用
### 1. 安装haproxy和keepalived
```
yum -y install haproxy keepalived
```

### 2. 配置haproxy
```
# cat /etc/haproxy/haproxy.cfg
#---------------------------------------------------------------------
global
    log         127.0.0.1 local2

    chroot      /var/lib/haproxy
    pidfile     /var/run/haproxy.pid
    maxconn     4000
    user        haproxy
    group       haproxy
    daemon

    # turn on stats unix socket
    stats socket /var/lib/haproxy/stats

#---------------------------------------------------------------------
defaults
    mode                    http
    log                     global
    option                  httplog
    option                  dontlognull
    option http-server-close
    option forwardfor       except 127.0.0.0/8
    option                  redispatch
    retries                 1
    timeout http-request    10s
    timeout queue           20s
    timeout connect         5s
    timeout client          20s
    timeout server          20s
    timeout http-keep-alive 10s
    timeout check           10s
    #maxconn                 3000

#---------------------------------------------------------------------
frontend  apiserver
    bind *:7443
    mode tcp
    option tcplog
    default_backend apiserver

#---------------------------------------------------------------------
backend apiserver
    option httpchk GET /healthz
    http-check  expect status 200
    mode        tcp
    option      ssl-hello-chk
    balance     roundrobin
    server  k8s-01 10.128.25.231:6443 check
    server  k8s-02 10.128.25.232:6443 check
    server  k8s-03 10.128.25.233:6443 check
```

### 3. 配置keepalived

```
[root@k8s-01 ~]# cat /etc/keepalived/keepalived.conf 
! Configuration File for keepalived

global_defs {
   router_id LVS_DEVEL
   script_user root
   enable_script_security 
}

vrrp_script check_apiserver {
  script "/etc/keepalived/check_apiserver.sh"
  interval 3		 # 脚本执行间隔，每3s检测一次
  weight -3			 # 脚本结果导致的优先级变更，检测失败（脚本返回非0）则优先级 -3
  fall 2			 # 检测连续2次失败才算确定是真失败。会用weight减少优先级（1-255之间）
  rise 1             # 检测2次成功就算成功。但不修改优先级
}

vrrp_instance VI_1 {
    state MASTER		# 从设置BACKUP
    interface eth0
    virtual_router_id 51
    priority 100	 # 100(主)|99(备1)98(备2)定义优先级，数字越大，优先级越高，MASTER的优先级必须大于BACKUP的优先级
    advert_int 1
    authentication {
        auth_type PASS
        auth_pass 1111
    }
    virtual_ipaddress {							# 虚拟IP的设置(VIP)
        10.128.25.237/24 dev eth0 label eth0:1 
    }
    track_script {
        check_apiserver
    }
    unicast_src_ip 10.128.25.231		# 关闭组播，使用单播通信，源ip为本机IP
    unicast_peer { 
        10.128.25.232					# 对端ip
        10.128.25.233
    }
}
```

健康检查脚本
```
# cat /etc/keepalived/check_apiserver.sh 
#!/bin/sh

errorExit() {
    echo "*** $*" 1>&2
    exit 1
}

APISERVER_VIP="10.128.25.237"
APISERVER_DEST_PORT="7443"

curl --silent --max-time 2 --insecure https://localhost:${APISERVER_DEST_PORT}/ -o /dev/null || errorExit "Error GET https://localhost:${APISERVER_DEST_PORT}/"
if ip addr | grep -q ${APISERVER_VIP}; then
    curl --silent --max-time 2 --insecure https://${APISERVER_VIP}:${APISERVER_DEST_PORT}/ -o /dev/null || errorExit "Error GET https://${APISERVER_VIP}:${APISERVER_DEST_PORT}/"
fi

# chmod +x /etc/keepalived/check_apiserver.sh
```

### 4. 启动服务
```
systemctl enable haproxy --now
systemctl enable keepalived --now
```

## 四、Kubernetes cluster安装：
### 1. 拉取镜像
```
kubeadm config images pull --kubernetes-version=1.20.1 --image-repository registry.aliyuncs.com/google_containers
```

### 2. 导出所有默认的配置
```
kubeadm config print init-defaults > kubeadm-ha.yaml
```

### 3. 修改 kubeadm-ha.yaml 文件
```
# cat <<EOF > kubeadm-ha.yaml
apiVersion: kubeadm.k8s.io/v1beta2
bootstrapTokens:
- groups:
  - system:bootstrappers:kubeadm:default-node-token
  token: abcdef.0123456789abcdef
  ttl: 24h0m0s
  usages:
  - signing
  - authentication
kind: InitConfiguration
localAPIEndpoint:
  advertiseAddress: 10.128.25.231
  bindPort: 6443
nodeRegistration:
  criSocket: /var/run/dockershim.sock
  name: k8s-01
  taints:
  - effect: NoSchedule
    key: node-role.kubernetes.io/master
---
apiServer:
  timeoutForControlPlane: 4m0s
apiVersion: kubeadm.k8s.io/v1beta2
certificatesDir: /etc/kubernetes/pki
clusterName: kubernetes
controlPlaneEndpoint: "10.128.25.237:7443"     
controllerManager: {}
dns:
  type: CoreDNS
etcd:
  local:
    dataDir: /var/lib/etcd
imageRepository: registry.aliyuncs.com/google_containers
kind: ClusterConfiguration
kubernetesVersion: v1.20.1
networking:
  dnsDomain: cluster.local
  serviceSubnet: 10.1.0.0/16
  podSubnet: 10.2.0.0/16
scheduler: {}
---
apiVersion: kubeproxy.config.k8s.io/v1alpha1
kind: KubeProxyConfiguration
mode: ipvs
EOF
```

### 4. 执行初始化操作
```
kubeadm init --config kubeadm-ha.yaml --upload-certs
```

成功执行之后，你会看到下面的输出：
```
Your Kubernetes control-plane has initialized successfully!

To start using your cluster, you need to run the following as a regular user:

  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config

Alternatively, if you are the root user, you can run:

  export KUBECONFIG=/etc/kubernetes/admin.conf

You should now deploy a pod network to the cluster.
Run "kubectl apply -f [podnetwork].yaml" with one of the options listed at:
  https://kubernetes.io/docs/concepts/cluster-administration/addons/

You can now join any number of the control-plane node running the following command on each as root:

  kubeadm join 10.128.25.237:7443 --token abcdef.0123456789abcdef \
    --discovery-token-ca-cert-hash sha256:78ffc4bb87f4be7d2680e6b4167bcb699bf434e2cda97f4240758b6e095bdae9 \
    --control-plane --certificate-key f553f1f767c7eb3867acf5281f10195a535dd3e5156e1f466a846d49102c2038

Please note that the certificate-key gives access to cluster sensitive data, keep it secret!
As a safeguard, uploaded-certs will be deleted in two hours; If necessary, you can use
"kubeadm init phase upload-certs --upload-certs" to reload certs afterward.

Then you can join any number of worker nodes by running the following on each as root:

kubeadm join 10.128.25.237:7443 --token abcdef.0123456789abcdef \
    --discovery-token-ca-cert-hash sha256:78ffc4bb87f4be7d2680e6b4167bcb699bf434e2cda97f4240758b6e095bdae9 
```
kubectl默认会在执行的用户家目录下面的.kube目录下寻找config文件。这里是将在初始化时[kubeconfig]步骤生成的admin.conf拷贝到.kube/config。
```
  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

### 5. 部署网络插件
【部署Flannel网络插件】部署Flannel网络插件需要修改Pod的IP地址段，修改为和你初始化一直的网段，可以先下载Flannel的YAML文件修改后，再执行。

https://github.com/coreos/flannel.git

```
# wget https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml
 
# vim kube-flannel.yml
# 修改"Network": "10.244.0.0/16"为"Network": "10.2.0.0/16",

74   net-conf.json: |
75     {
76       "Network": "10.2.0.0/16",
77       "Backend": {
78         "Type": "vxlan"
79       }
80     }

# 请注意，Flannel的镜像拉取速度会比较慢，可以替换为国内镜像
# image: quay.io/coreos/flannel:v0.10.0-amd64
image: quay-mirror.qiniu.com/coreos/flannel:v0.11.0-amd64

# 如果Node中有多个网卡，可以使用--iface来指定对应的网卡参数。
containers:
      - name: kube-flannel
        image: quay-mirror.qiniu.com/coreos/flannel:v0.11.0-amd64
        command:
        - /opt/bin/flanneld
        args:
        - --ip-masq
        - --kube-subnet-mgr
        - --iface=eth0
```

部署Flannel
```
# kubectl create -f kube-flannel.yml
```

查看Pod状态
```
# kubectl get pod -n kube-system
```

### 6. 部署其他Master节点
```
  kubeadm join 10.128.25.237:7443 --token abcdef.0123456789abcdef \
    --discovery-token-ca-cert-hash sha256:78ffc4bb87f4be7d2680e6b4167bcb699bf434e2cda97f4240758b6e095bdae9 \
    --control-plane --certificate-key f553f1f767c7eb3867acf5281f10195a535dd3e5156e1f466a846d49102c2038
```

### 7. 部署Node节点
1、在Master节点输出增加节点的命令
```
# kubeadm token create --print-join-command
kubeadm join 192.168.26.10:6443 --token isggqa.xjwsm3i6nex91d2x --discovery-token-ca-cert-hash sha256:718827895a9a5e63dfa9ff54e16ad6dc0c493139c9c573b67ad66968036cd569
```
2、在Node节点执行
```
kubeadm join 192.168.26.10:6443 --token isggqa.xjwsm3i6nex91d2x --discovery-token-ca-cert-hash sha256:718827895a9a5e63dfa9ff54e16ad6dc0c493139c9c573b67ad66968036cd569
```
3、在Master节点执行
```
# kubectl get node
NAME     STATUS   ROLES                  AGE   VERSION
k8s-01   Ready    control-plane,master   22m   v1.20.1
k8s-02   Ready    control-plane,master   19m   v1.20.1
k8s-03   Ready    control-plane,master   12m   v1.20.1
k8s-04   Ready    <none>                 21m   v1.20.1
k8s-05   Ready    <none>                 21m   v1.20.1
k8s-06   Ready    <none>                 21m   v1.20.1
```

