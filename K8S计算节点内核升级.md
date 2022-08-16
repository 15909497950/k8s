**K8S****计算节点内核升级**

(一)      提前迁移业务pod到其他节点

设置节点不可调度和驱赶POD

```shell
# kubectl get node 
# kubectl cordon <node>
# kubectl drain <node> --delete-emptydir-data --ignore-daemonsets --force

```

内核升级

```shell
1、查看内核版本
# uname -sr
Linux 3.10.0-1160.42.2.el7.x86_64
外网环境下: 一般来说，只有从https://www.kernel.org/ 下载并编译安装的内核才是官方内核
#导入ELRepo软件仓库的公共秘钥
rpm --import https://www.elrepo.org/RPM-GPG-KEY-elrepo.org

#Centos7系统安装ELRepo
yum install https://www.elrepo.org/elrepo-release-7.el7.elrepo.noarch.rpm
#Centos8系统安装ELRepo
yum install https://www.elrepo.org/elrepo-release-8.el8.elrepo.noarch.rpm

#查看ELRepo提供的内核版本
yum --disablerepo="*" --enablerepo="elrepo-kernel" list available

2、配置DC内网kernel源
# cat <<EOF > /etc/yum.repos.d/elrepo-kernel.repo 
[elrepo-kernel]
name= Linux Kernel Repository - el7
baseurl=http://100.65.34.22/elrepo/kernel/
enabled=0
gpgcheck=1
gpgkey=http://100.65.34.22/elrepo/kernel/RPM-GPG-KEY-elrepo.org
EOF
# yum makecache 
3、查看安装包
# yum --disablerepo="*" --enablerepo="elrepo-kernel" list available
4、安装kernel-lt包
# yum --enablerepo=elrepo-kernel install kernel-lt –y

5、查看可用内核版本及启动顺序
# awk -F\' '$1=="menuentry " {print i++ " : " $2}' /boot/grub2/grub.cfg
0 : CentOS Linux (5.4.195-1.el7.elrepo.x86_64) 7 (Core)
1 : CentOS Linux (3.10.0-1160.el7.x86_64) 7 (Core)
2 : CentOS Linux (0-rescue-c44e9056ef2d44cc86d0a39088da6456) 7 (Core)

6、设置开机启动并重启系统
# grub2-set-default 0
# reboot
7、检查内核版本确认系统运行正常
# uname -sr
Linux 5.4.195-1.el7.elrepo.x86_64

```

取消不可调度

```shell
kubectl uncordon <node>
```

