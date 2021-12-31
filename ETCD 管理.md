# ETCD 管理



```
[root@k8s-01 ~]# ETCDCTL_API=3 etcdctl --endpoints "https://10.128.25.231:2379,https://10.128.25.232:2379,https://10.128.25.233:2379" --cacert /etc/kubernetes/pki/etcd/ca.crt --cert /etc/kubernetes/pki/etcd/server.crt --key /etc/kubernetes/pki/etcd/server.key   endpoint status
https://10.128.25.231:2379, 6b678576cf5a43ae, 3.4.13, 8.7 MB, false, false, 338, 251606, 251606, 
https://10.128.25.232:2379, 71194ff7de65c3a2, 3.4.13, 8.7 MB, true, false, 338, 251606, 251606, 
https://10.128.25.233:2379, 5f0c762e6afe1b5, 3.4.13, 8.7 MB, false, false, 338, 251606, 251606, 
```

```

[root@k8s-01 ~]#  ETCDCTL_API=3 etcdctl --endpoints "https://10.128.25.231:2379,https://10.128.25.232:2379,https://10.128.25.233:2379" --cacert /etc/kubernetes/pki/etcd/ca.crt --cert /etc/kubernetes/pki/etcd/server.crt --key /etc/kubernetes/pki/etcd/server.key -w table member list
+------------------+---------+--------+----------------------------+----------------------------+------------+
|        ID        | STATUS  |  NAME  |         PEER ADDRS         |        CLIENT ADDRS        | IS LEARNER |
+------------------+---------+--------+----------------------------+----------------------------+------------+
|  5f0c762e6afe1b5 | started | k8s-03 | https://10.128.25.233:2380 | https://10.128.25.233:2379 |      false |
| 6b678576cf5a43ae | started | k8s-01 | https://10.128.25.231:2380 | https://10.128.25.231:2379 |      false |
| 71194ff7de65c3a2 | started | k8s-02 | https://10.128.25.232:2380 | https://10.128.25.232:2379 |      false |
+------------------+---------+--------+----------------------------+----------------------------+------------+

```



```
[root@k8s-01 ~]#  ETCDCTL_API=3 etcdctl --endpoints "https://10.128.25.231:2379,https://10.128.25.232:2379,https://10.128.25.233:2379" --cacert /etc/kubernetes/pki/etcd/ca.crt --cert /etc/kubernetes/pki/etcd/server.crt --key /etc/kubernetes/pki/etcd/server.key get /registry --prefix --keys-only


```



```

[root@k8s-01 ~]#  ETCDCTL_API=3 etcdctl --endpoints "https://10.128.25.231:2379,https://10.128.25.232:2379,https://10.128.25.233:2379" --cacert /etc/kubernetes/pki/etcd/ca.crt --cert /etc/kubernetes/pki/etcd/server.crt --key /etc/kubernetes/pki/etcd/server.key get -w json /registry/storageclasses/local
{"header":{"cluster_id":10357897792034037751,"member_id":7739301229990921134,"revision":172700,"raft_term":338}}

```

