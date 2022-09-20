# K8S集群创建用户并赋权访问特定namespace

```shell
目的
创建一个myuser1用户，让该用户只能操作myns1下的pod，其它的都无权操作。
创建用户
创建新用户的证书，在任意目录下操作
我这里在/opt/mytest目录中操作
[root@manager mytest]# openssl genrsa -out myuser1.key 2048
Generating RSA private key, 2048 bit long modulus
...........+++
......................+++
e is 65537 (0x10001)
[root@manager mytest]# openssl req -new -key myuser1.key -out myuser1.csr -subj "/CN=myuser1"
[root@manager mytest]# openssl x509 -req -in myuser1.csr -CA /etc/kubernetes/pki/ca.crt -CAkey /etc/kubernetes/pki/ca.key -CAcreateserial -out myuser1.crt -days 365
Signature ok
subject=/CN=myuser1
Getting CA Private Key
[root@manager mytest]# openssl x509 -in myuser1.crt -text -noout
Certificate:
    Data:
        Version: 1 (0x0)
        Serial Number:
            c7:48:13:1e:63:1b:7e:5b
    Signature Algorithm: sha256WithRSAEncryption
        Issuer: CN=kubernetes
        Validity
            Not Before: Jun  1 07:39:15 2020 GMT
            Not After : Jun  1 07:39:15 2021 GMT
        Subject: CN=myuser1
        Subject Public Key Info:
            Public Key Algorithm: rsaEncryption
                Public-Key: (2048 bit)
                Modulus:
		......
                Exponent: 65537 (0x10001)
    Signature Algorithm: sha256WithRSAEncryption
        ......

```

更改集群配置和用户上下文环境

```shell
[root@manager mytest]# kubectl config set-credentials myuser1 --client-certificate=/opt/mytest/myuser1.crt --client-key=/opt/mytest/myuser1.key --embed-certs=true
User "myuser1" set.
[root@manager mytest]# kubectl config set-context myuser1@kubernetes --cluster=kubernetes --user=myuser1
Context "myuser1@kubernetes" created.
[root@manager mytest]# kubectl config use-context myuser1@kubernetes
Switched to context "myuser1@kubernetes".

```

没赋权状态下，`pod、service`等信息都无法获取

```shell
[root@manager mytest]# kubectl get pods,svc
Error from server (Forbidden): pods is forbidden: User "myuser1" cannot list resource "pods" in API group "" in the namespace "default"
Error from server (Forbidden): services is forbidden: User "myuser1" cannot list resource "services" in API group "" in the namespace "default"
[root@manager mytest]# kubectl get pods,svc -n myns1
Error from server (Forbidden): pods is forbidden: User "myuser1" cannot list resource "pods" in API group "" in the namespace "myns1"
Error from server (Forbidden): services is forbidden: User "myuser1" cannot list resource "services" in API group "" in the namespace "myns1"
[root@manager mytest]# kubectl get ns
Error from server (Forbidden): namespaces is forbidden: User "myuser1" cannot list resource "namespaces" in API group "" at the cluster scope

```

# 赋权

```shell
切换回管理员身份
[root@manager mytest]# kubectl config use-context kubernetes-admin@kubernetes
Switched to context "kubernetes-admin@kubernetes".
[root@manager mytest]# kubectl get ns
NAME              STATUS   AGE
default           Active   6d1h
hdfstgm           Active   4d2h
kube-node-lease   Active   6d1h
kube-public       Active   6d1h
kube-system       Active   6d1h
myns1             Active   2d22h

```

创建角色`role.yaml`

```shell
# vim role.yaml
kind: Role
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  namespace: myns1
  name: myrole1
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get","watch","list","create","update","patch","delete"]

```

```shell
创建角色绑定rolebinding.yaml
# vim rolebinding.yaml
kind: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: my-rolebinding1
  namespace: myns1
subjects:
- kind: User
  name: myuser1
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: myrole1
  apiGroup: rbac.authorization.k8s.io

```

执行创建

```shell
[root@manager mytest]# kubectl create -f role.yaml 
role.rbac.authorization.k8s.io/myrole1 created
[root@manager mytest]# kubectl create -f rolebinding.yaml 
rolebinding.rbac.authorization.k8s.io/my-rolebinding1 created

```

# 切换用户验证

```shell
查看myns1命名空间中的pod和service
[root@manager mytest]# kubectl config use-context myuser1@kubernetes
Switched to context "myuser1@kubernetes".
[root@manager mytest]# kubectl get pods,svc -n myns1
NAME                      READY   STATUS    RESTARTS   AGE
hadoop-datanode-6-mbqtn   1/1     Running   0          2d22h
hadoop-datanode-6-t7x5j   1/1     Running   0          2d22h
hadoop-datanode-6-wvwwp   1/1     Running   0          2d22h
hdfs-master-4-5stbn       1/1     Running   0          2d22h
Error from server (Forbidden): services is forbidden: User "myuser1" cannot list resource "services" in API group "" in the namespace "myns1"



pod已经有权查看了，但是service还没赋权
重新编辑role.yaml，再次创建角色

# 切换用户
[root@manager mytest]# kubectl config use-context kubernetes-admin@kubernetes
Switched to context "kubernetes-admin@kubernetes".
[root@manager mytest]# kubectl delete -f role.yaml
role.rbac.authorization.k8s.io "myrole1" deleted




修改role.yaml
kind: Role
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  namespace: myns1
  name: myrole1
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get","watch","list","create","update","patch","delete"]
- apiGroups: [""] 
  resources: ["services"]
  verbs: ["get","watch","list"]


再次创建修改后的角色

[root@manager mytest]# kubectl create -f role.yaml
role.rbac.authorization.k8s.io/myrole1 created
[root@manager mytest]# kubectl config use-context myuser1@kubernetes
Switched to context "myuser1@kubernetes".

验证

[root@manager mytest]# kubectl get svc -n myns1
NAME                   TYPE       CLUSTER-IP      EXTERNAL-IP   PORT(S)                          AGE
hadoop-hdfs-master   NodePort   10.96.238.218   <none>        9000:32504/TCP,50070:32227/TCP   2d23h


再次验证进入POD指令
[root@manager ~]# kubectl exec -it hdfs-master-4-5stbn bash -n myns1
kubectl exec [POD] [COMMAND] is DEPRECATED and will be removed in a future version. Use kubectl kubectl exec [POD] -- [COMMAND] instead.
Error from server (Forbidden): pods "hdfs-master-4-5stbn" is forbidden: User "myuser1" cannot create resource "pods/exec" in API group "" in the namespace "myns1"

删除角色，然后修改role.yaml文件
kubectl delete -f role.yaml
rules:
- apiGroups: [""]
  resources: ["pods","pods/exec"]  #增加pods/exec
  verbs: ["get","watch","list","create","update","patch","delete"]
再次创建，再次 执行，就可以正常使用了
kubectl create -f role.yaml
[root@manager mytest]# kubectl exec -it hdfs-master-4-5stbn bash -n myns1
kubectl exec [POD] [COMMAND] is DEPRECATED and will be removed in a future version. Use kubectl kubectl exec [POD] -- [COMMAND] instead.
root@hdfs-master-4-5stbn:
root@hdfs-master-4-5stbn:~# hadoop fs -ls /
root@hdfs-master-4-5stbn:~# hadoop fs -mkdir /mytest
root@hdfs-master-4-5stbn:~# hadoop fs -ls /
Found 1 items
drwxr-xr-x   - root supergroup          0 2020-06-02 09:14 /mytest

```

生成配置文件

```shell
 kubectl config set-cluster kubernetes   --certificate-authority=/etc/kubernetes/pki/ca.crt  --embed-certs=true --server=https://100.65.34.67:6443 --kubeconfig=./config


 kubectl config set-credentials myuser1 --client-certificate=myuser1.crt --client-key=myuser1.key --embed-certs=true --kubeconfig=./config
 
 kubectl config set-context default --cluster=kubernetes  --user=myuser1 --kubeconfig=./config
 kubectl config use-context default --kubeconfig=./config



# 设置集群参数
kubectl config set-cluster kubernetes \
  --certificate-authority=/etc/kubernetes/pki/ca.crt \
  --embed-certs=true \
  --server=https://10.96.51.8:6443 \
  --kubeconfig=./config

# 设置客户端认证参数
kubectl config set-credentials neozhao \
  --client-certificate=neozhao.crt \
  --client-key=neozhao.key \
  --embed-certs=true \
  --kubeconfig=./config

# 设置上下文参数
kubectl config set-context default \
  --cluster=kubernetes \
  --user=neozhao \
  --kubeconfig=./config

# 设置默认上下文
kubectl config use-context default \
  --kubeconfig=./config
```

k8s中有角色和角色绑定，因为K8S有两种资源，一种是集群资源，也就是cluster；一种是namespace资源；所以分别有role,rolebinding,clusterrole,clusterrolebinding.他们的区别在于作用域不同，cluster是针对整个集群资源的，而role则是限制在namespace中的。

这里有个特例就是role可以绑定clusterrole，这是很便捷的一个操作，假设你有十个namespace，每个namespace要建立一个只读权限的角色，那么你需要在10个namespace中分别建立rolebinding为get；但是如果role可以绑定clusterrolebinding，那么只需要建立一个clusterrolebinding为get，然后使用role去绑定这个clusterrolebinding即可，而不需要去建10次。

# 集群角色创建和绑定

```shell
kubectl create clusterrole clusterrole-reader-pods --verb=get,list,watch --resource=pods --dry-run -o yaml > clusterrole-demo.yaml

kubectl create clusterrolebinding cluster-reader --clusterrole=clusterrole-reader-pods --user=myuser1 --dry-run -o yaml > clusterrolebinding-demo.yaml

kubectl apply -f clusterrole-demo.yaml
kubectl apply -f clusterrolebinding-demo.yaml
```

