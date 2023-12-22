# nginx 反向代理rancher 报 Cluster Explorer功能提示500错误

### 观察错误

Rancher的其他功能没有受到可观察到的影响，所以我猜测这个应该不是Rancher自己的问题，应该是我的问题（捂脸）

主要的报错是在从Rancher Cluster Global页面，点击集群右边的Explorer按钮进入到CE（Cluster Explorer，以下均偷懒为缩写），就会在主页面上提示这个错误

```shell
HTTP Error 500: Internal Server Error
from /k8s/clusters/c-mppz8/v1/schemas
```

### 查找解决方法

经过在谷歌搜索后发现github有人报相关的issue：[Internal Server Error In Cluster Explorer After Upgrade to v2.5.2](https://www.xjh.me/go/?url=aHR0cHM6Ly9naXRodWIuY29tL3JhbmNoZXIvcmFuY2hlci9pc3N1ZXMvMzAxODI=)

看了一下上下文，发现环境和报错都和我的实际情况相近，感觉可以参考一下解决方法（之前第一次看到这个错误的时候，其实没有意识到是我自己的问题）

实在没想到竟然可能是Websocket头的问题（

我之前反向代理Websocket一直都是使用的这段，也没有遇到过奇怪问题，所以一直没有用那种更~~麻烦~~准确的方法（

```
proxy_set_header Connection "Upgrade";
```

------

### 尝试解决

我记得反代Websocket还有另一种更准确的方法，于是使用了那段替换掉直接替换为Upgrade的代码，即

~~~shell
###nginx.conf####
# outside the server range
map $http_upgrade $connection_upgrade {
default upgrade;
'' close;
}

server {
````
proxy_set_header Connection $connection_upgrade;
````
}
~~~

