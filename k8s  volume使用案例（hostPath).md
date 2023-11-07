# k8s  volume使用案例（hostPath)

几种常用的卷

emptyDir：用于存储临时数据的简单空目录；
hostPath：用于将目录从工作节点的文件系统挂载到pod中；
local volume：Local volume 允许用户通过标准PVC接口以简单且可移植的方式访问node节点的本地存储。 PV的定义中需要包含描述节点亲和性的信息，k8s系统则使用该信息将容器调度到正确的node节点。（StorageClass local模式）
CongfigMap、secret：特殊的卷，不是用于存储数据，而是用于将配置文件公开给pod中的应用程序；

hostPath类型则是映射node文件系统中的文件或者目录到pod里，**与宿主机目录映射**。在使用hostPath类型的存储卷时，也可以设置type字段，支持的类型有文件、`Directory`、`File`、`Socket`、`CharDevice`和`BlockDevice`。

```shell
  volumes:
       
        - name: etc-ssl-certs
          hostPath:
            path: /etc/ssl/certs/
            type: Directory
        - name: tls-ca-bundle
          hostPath:
            path: /etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem
            type: File
        - name: ca-bundle-trust-crt
          hostPath:
            path: /etc/pki/ca-trust/extracted/openssl/ca-bundle.trust.crt
            type: File


```

```shell
        volumeMounts:
            - name: etc-ssl-certs
              mountPath: /etc/ssl/certs/
            - name: tls-ca-bundle
              mountPath: /etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem
            - name: ca-bundle-trust-crt
              mountPath: /etc/pki/ca-trust/extracted/openssl/ca-bundle.trust.crt
```

