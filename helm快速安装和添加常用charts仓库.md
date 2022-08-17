国外下载比较慢，使用国内华为镜像源下载

国外官方地址：https://github.com/helm/helm/releases

国内镜像地址：[Index of helm-local![icon-default.png?t=M666](https://csdnimg.cn/release/blog_editor_html/release2.1.7/ckeditor/plugins/CsdnLink/icons/icon-default.png?t=M666)https://mirrors.huaweicloud.com/helm/](https://mirrors.huaweicloud.com/helm/)

添加国内源：

helm几个常用仓库：

helm官方：https://hub.helm.sh/

bitnami: https://charts.bitnami.com/bitnami

开源社是由中国支持开源的企业,社区及个人所组织的一个开源联盟,旨在推广开源。

开源社镜像：

http://mirror.kaiyuanshe.cn/kubernetes/charts/

http://mirror.azure.cn/kubernetes/charts/

kubernetes app商店：

https://hub.kubeapps.com/

```shell
# 查看当前配置的仓库地址
$ helm repo list
# 删除默认仓库，默认在国外pull很慢
$ helm repo remove stable
# 添加几个常用的仓库,可自定义名字
$ helm repo add stable https://kubernetes.oss-cn-hangzhou.aliyuncs.com/charts
$ helm repo add kaiyuanshe http://mirror.kaiyuanshe.cn/kubernetes/charts
$ helm repo add azure http://mirror.azure.cn/kubernetes/charts
$ helm repo add dandydev https://dandydeveloper.github.io/charts
$ helm repo add bitnami https://charts.bitnami.com/bitnami
# 搜索chart
$ helm search repo redis
# 拉取chart包到本地
$ helm pull bitnami/redis-cluster --version 8.1.2
# 安装redis-ha集群，取名redis-ha，需要指定持存储类
$ helm install redis-cluster bitnami/redis-cluster --set global.storageClass=nfs,global.redis.password=xiagao --version 8.1.2
# 卸载
$ helm uninstall redis-cluster
```

