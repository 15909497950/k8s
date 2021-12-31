



# kube-bench检测k8s集群的漏洞

https://github.com/aquasecurity/kube-bench/releases/tag/v0.6.2

```
[root@k8s-01 ~]# tar -xvf kube-bench_0.6.2_linux_amd64.tar.gz 

[root@k8s-01 ~]# ./kube-bench --config-dir `pwd`/cfg --config `pwd`/cfg/config.yaml master

[root@k8s-01 ~]# ./kube-bench run --targets master,node,etcd,policies  --config-dir `pwd`/cfg --config `pwd`/cfg/config.yaml 
```

