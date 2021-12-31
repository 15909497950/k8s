# 使用 kubeadm 命令创建单 Master K8S集群
## 一、集群规划
主机名 |  IP地址 | 组件 
|-|--|--|
| master    | 192.168.2.10 |  etcd、apiserver、scheduler、controller-manager、kubeadm、kubeclt、kubelet、kube-proxy  |
| worker-1 | 192.168.2.11 |  kubeadm、kubelet、kube-proxy |
| worker-2 | 192.168.2.12 |  kubeadm、kubelet、kube-proxy |

## 二、系统优化
参考：《0-系统优化及安装docker和kubeadm》文档

## 三、初始化Kubernetes集群：
### 1. 拉取镜像
```
# kubeadm config images pull --kubernetes-version=1.20.0 --image-repository registry.aliyuncs.com/google_containers
```
### 2. 导出所有默认的配置
```
# kubeadm config print init-defaults > kubeadm.yaml
```
### 3. 修改kubeadm.yaml文件
```
# cat <<EOF > kubeadm.yaml 
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
  advertiseAddress: 192.168.2.10    # 修改为API Server的地址
  bindPort: 6443
nodeRegistration:
  criSocket: /var/run/dockershim.sock
  name: node
  taints: null
---
apiServer:
  timeoutForControlPlane: 4m0s
apiVersion: kubeadm.k8s.io/v1beta2
certificatesDir: /etc/kubernetes/pki
clusterName: kubernetes
controllerManager: {}
dns:
  type: CoreDNS
etcd:
  local:
    dataDir: /var/lib/etcd
imageRepository: registry.aliyuncs.com/google_containers   # 修改为阿里云镜像仓库
kind: ClusterConfiguration
kubernetesVersion: 1.20.0          # 修改为具体的版本
networking:
  dnsDomain: cluster.local
   serviceSubnet: 10.1.0.0/16   #修改Service的网络
   podSubnet: 10.2.0.0/16      #新增Pod的网络
scheduler: {}
# 下面有增加的三行配置，用于设置Kubeproxy使用LVS
---   
apiVersion: kubeproxy.config.k8s.io/v1alpha1            
kind: KubeProxyConfiguration
mode: ipvs
EOF
```

### 4. 执行初始化操作
```
# kubeadm init --config kubeadm.yaml
```
如果测试环境资源小于2CPU 2G内存的可能会报如下错误：
```
[init] Using Kubernetes version: v1.20.0
[preflight] Running pre-flight checks
error execution phase preflight: [preflight] Some fatal errors occurred:
        [ERROR NumCPU]: the number of available CPUs 1 is less than the required 2
        [ERROR Swap]: running with swap on is not supported. Please disable swap
[preflight] If you know what you are doing, you can make a check non-fatal with `--ignore-preflight-errors=...`
To see the stack trace of this error execute with --v=5 or higher
```
上面这样的报错，是因为在实验环境开启了交换分区，以及CPU的核数小于2造成的，可以使用--ignore-preflight-errors=进行忽略。 --ignore-preflight-errors=：忽略运行时的错误，例如上面目前存在[ERROR NumCPU]和[ERROR Swap]，忽略这两个报错就是增加--ignore-preflight-errors=NumCPU 和--ignore-preflight-errors=Swap的配置即可。
再次执行初始化操作：
```
# kubeadm init --config kubeadm.yaml --ignore-preflight-errors=Swap,NumCPU 
```
这里省略了所有输出，初始化操作主要经历了下面15个步骤，每个阶段均输出均使用[步骤名称]作为开头：
```
[init]：指定版本进行初始化操作
[preflight] ：初始化前的检查和下载所需要的Docker镜像文件。
[kubelet-start]：生成kubelet的配置文件”/var/lib/kubelet/config.yaml”，没有这个文件kubelet无法启动，所以初始化之前的kubelet实际上启动失败。
[certificates]：生成Kubernetes使用的证书，存放在/etc/kubernetes/pki目录中。
[kubeconfig] ：生成 KubeConfig文件，存放在/etc/kubernetes目录中，组件之间通信需要使用对应文件。
[control-plane]：使用/etc/kubernetes/manifest目录下的YAML文件，安装 Master组件。
[etcd]：使用/etc/kubernetes/manifest/etcd.yaml安装Etcd服务。
[wait-control-plane]：等待control-plan部署的Master组件启动。
[apiclient]：检查Master组件服务状态。
[uploadconfig]：更新配置
[kubelet]：使用configMap配置kubelet。
[patchnode]：更新CNI信息到Node上，通过注释的方式记录。
[mark-control-plane]：为当前节点打标签，打了角色Master，和不可调度标签，这样默认就不会使用Master节点来运行Pod。
[bootstrap-token]：生成token记录下来，后边使用kubeadm join往集群中添加节点时会用到
[addons]：安装附加组件CoreDNS和kube-proxy
 ```
成功执行之后，你会看到下面的输出：
```
Your Kubernetes master has initialized successfully!
To start using your cluster, you need to run the following as a regular user:

mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

You should now deploy a pod network to the cluster.

Run "kubectl apply -f [podnetwork].yaml" with one of the options listed at:
https://kubernetes.io/docs/concepts/cluster-administration/addons/

You can now join any number of machines by running the following on each node
as root:
kubeadm join 192.168.26.10:6443 --token 19fhhl.3mzkyk16tcgp6vga --discovery-token-ca-cert-hash sha256:76a88c38b673d3
```
如果执行失败，那意味着之前的操作存在问题，检查顺序如下：

基础环境
主机名是否可以解析，SELinux，iptables是否关闭。
交换分区是否存在free -m查看
内核参数是否修改、IPVS是否修改（目前阶段不会造成失败）

基础软件

Docker是否安装并启动
Kubelet是否安装并启动
执行kubeadm是否有别的报错是否忽略
systemctl status kubelet查看kubelet是否启动
如果kubelet无法启动，查看日志有什么报错，并解决报错。

以上都解决完毕，需要重新初始化

kubeadm reset 进行重置（生产千万不要执行，会直接删除集群）
根据kubeadm reset 提升，清楚iptables和LVS。
请根据上面输出的要求配置kubectl命令来访问集群。

为kubectl准备Kubeconfig文件。

kubectl默认会在执行的用户家目录下面的.kube目录下寻找config文件。这里是将在初始化时[kubeconfig]步骤生成的admin.conf拷贝到.kube/config。

```
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```
在该配置文件中，记录了API Server的访问地址，所以后面直接执行kubectl命令就可以正常连接到API Server中。

### 5. 使用kubectl命令查看node状态
```
# kubectl get node
NAME STATUS ROLES AGE VERSION
master NotReady master 14m v1.20.0
```

### 6. 部署网络插件
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
# kubectl get nodes
NAME       STATUS   ROLES                  AGE   VERSION
master     Ready    control-plane,master   24d   v1.20.0
worker-1   Ready    <none>                 8d    v1.20.0
worker-2   Ready    <none>                 24d   v1.20.0
```
