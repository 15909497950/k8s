# 系统优化及安装docker和kubeadm/kubeclt/kubelet

## 一、系统优化

### 1、最小化安装系统，并修改主机名和IP地址：
    yum install bash-completion curl wget vim net-tools
    
    hostnamectl set-hostname  xxx
    nmcli connection modify eth0 ipv4.method manual ipv4.gateway xx.xx.xx.xx ipv4.dns xx.xx.xx.xx ipv4.addresses xx.xx.xx.xx/24
    sed -i '/^ONBOOT/s/.*/ONBOOT=yes/g' /etc/sysconfig/network-scripts/ifcfg-eth0
    nmcli connection up eth0

### 2、添加hosts解析

    # cat /etc/hosts
    ... ...
    10.128.25.230 harbor.example.com
    10.128.25.231 k8s-01 
    10.128.25.232 k8s-02
    10.128.25.233 k8s-03
    10.128.25.234 k8s-04
    10.128.25.235 k8s-05
    10.128.25.236 k8s-06

### 3、配置阿里源：

    rm -rf /etc/yum.repos.d/*
    curl -o /etc/yum.repos.d/CentOS-Base.repo https://mirrors.aliyun.com/repo/Centos-7.repo
    sed -i -e '/mirrors.cloud.aliyuncs.com/d' -e '/mirrors.aliyuncs.com/d' /etc/yum.repos.d/CentOS-Base.repo
    curl -o /etc/yum.repos.d/epel.repo http://mirrors.aliyun.com/repo/epel-7.repo

### 4、优化系统：

    cat <<EOE > one-int.sh
    #!/bin/bash
    
    # 禁用selinux
    setenforce 0
    sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config
    
    # 禁用防火墙
    systemctl stop firewalld ; systemctl disable firewalld
    
    # 启用br_netfilter内核模块
    modprobe br_netfilter
    echo '1' > /proc/sys/net/bridge/bridge-nf-call-iptables
    
    # 修改内核参数
    cat > /etc/sysctl.d/k8s.conf<<EOF
    net.bridge.bridge-nf-call-ip6tables = 1
    net.bridge.bridge-nf-call-iptables = 1
    net.ipv4.ip_nonlocal_bind = 1
    net.ipv4.ip_forward = 1
    vm.swappiness=0
    EOF
    sysctl --system
    
    # 加载ipvs模块
    yum -y install ipset ipvsadm
    cat > /etc/sysconfig/modules/ipvs.modules <<EOF
    #!/bin/bash
    modprobe -- ip_vs
    modprobe -- ip_vs_rr
    modprobe -- ip_vs_wrr
    modprobe -- ip_vs_sh
    modprobe -- nf_conntrack_ipv4
    EOF
    chmod +x /etc/sysconfig/modules/ipvs.modules 
    source /etc/sysconfig/modules/ipvs.modules
    lsmod | grep -e ip_vs -e nf_conntrack_ipv4
    cut -f1 -d " "  /proc/modules | grep -e ip_vs -e nf_conntrack_ipv4
    
    # 禁用SWAP
    swapoff -a
    sed -i '/swap/s/.*/#&/g' /etc/fstab
    
    # 优化ssh禁用DNS解析
    sed -i '/UseDNS/s/.*/UseDNS no/g' /etc/ssh/sshd_config
    systemctl restart sshd
    EOE


​    
    bash one-int.sh

## 二、安装dokcer

```
yum install -y yum-utils device-mapper-persistent-data lvm2
yum-config-manager --add-repo https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
yum makecache fast
yum list docker-ce.x86_64  --showduplicates |sort -r
yum -y install docker-ce-19.03.9-3.el7
```

### 配置镜像加速器
```
mkdir /etc/docker
cat > /etc/docker/daemon.json <<EOF
{
"registry-mirrors": ["https://i9utjj72.mirror.aliyuncs.com"],
"exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2",
  "storage-opts": [
    "overlay2.override_kernel_check=true"
  ]
}
EOF

systemctl enable docker --now && systemctl status docker 

#  docker  info | grep -i cgroup 
Cgroup Driver: systemd
```

## 三、安装kubeadm、kubelet、kubectl
```
cat  > /etc/yum.repos.d/kubernetes.repo<<EOF
[kubernetes]
name=Kubernetes
baseurl=https://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-x86_64/
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://mirrors.aliyun.com/kubernetes/yum/doc/yum-key.gpg https://mirrors.aliyun.com/kubernetes/yum/doc/rpm-package-key.gpg
EOF

yum install -y kubelet-1.20.1 kubeadm-1.20.1 kubectl-1.20.1

# vim /etc/sysconfig/kubelet
KUBELET_CGROUP_ARGS="--cgroup-driver=systemd"
KUBELET_EXTRA_ARGS="--fail-swap-on=false"

systemctl enable kubelet --now && systemctl status kubelet
```

