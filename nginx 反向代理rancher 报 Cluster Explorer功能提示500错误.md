# nginx 反向代理rancher 报 Cluster Explorer功能提示500错误

### 观察错误

Rancher的其他功能没有受到可观察到的影响，所以我猜测这个应该不是Rancher自己的问题，应该是我的问题（捂脸）

主要的报错是在从Rancher Cluster Global页面，点击集群右边的Explorer按钮进入到CE（Cluster Explorer，以下均偷懒为缩写），就会在主页面上提示这个错误

```shell
HTTP Error 500: Internal Server Error
from /k8s/clusters/c-mppz8/v1/schemas
```



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

