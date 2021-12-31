# Kubernetes前端负载均衡器方案

## 一、安装HAproxy或者NGINX(二选一)

### 方案1：HAproxy + KeepAlived

#### 1. 安装 haproxy
```
yum -y install haproxy keepalived
```

#### 2. 配置haproxy
```
# cat <<EOF /etc/haproxy/haproxy.cfg
# /etc/haproxy/haproxy.cfg
#---------------------------------------------------------------------
# Global settings
#---------------------------------------------------------------------
global
    log         127.0.0.1 local2

    chroot      /var/lib/haproxy
    pidfile     /var/run/haproxy.pid
    maxconn     4000
    user        haproxy
    group       haproxy
    daemon

    # turn on stats unix socket
    stats socket /var/lib/haproxy/stats

#---------------------------------------------------------------------
# common defaults that all the 'listen' and 'backend' sections will
# use if not designated in their block
#---------------------------------------------------------------------
defaults
    mode                    http
    log                     global
    option                  httplog
    option                  dontlognull
    option http-server-close
    option forwardfor       except 127.0.0.0/8
    option                  redispatch
    retries                 1
    timeout http-request    10s
    timeout queue           20s
    timeout connect         5s
    timeout client          20s
    timeout server          20s
    timeout http-keep-alive 10s
    timeout check           10s

#---------------------------------------------------------------------
# apiserver frontend which proxys to the masters
#---------------------------------------------------------------------
frontend  apiserver
    bind *:7443
    mode tcp
    option tcplog
    default_backend apiserver

#---------------------------------------------------------------------
# round robin balancing for apiserver
#---------------------------------------------------------------------
backend apiserver
    option httpchk GET /healthz
    http-check  expect status 200
    mode        tcp
    option      ssl-hello-chk
    balance     roundrobin
        server  vms15 192.168.26.15:6443 check
        server  vms16 192.168.26.16:6443 check
```

#### 3. 启动haproxy服务
```
systemctl enable haproxy --now
```

### 方案2：NGINX + KeepAlived 
#### 1. 安装nginx

```
# yum -y install nginx keepalived 
```

#### 2. 配置nginx：
```
# cat <<'EOF' > /etc/nginx/nginx.conf
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log;
pid /run/nginx.pid;

# Load dynamic modules. See /usr/share/doc/nginx/README.dynamic.

include /usr/share/nginx/modules/*.conf;

events {
    worker_connections 1024;
}

# 添加四层转发
stream {
    log_format  main  '$remote_addr $upstream_addr - [$time_local] $status $upstream_bytes_sent';
    access_log  /var/log/nginx/k8s-access.log  main;

    upstream kube-apiserver {
		server 192.168.26.15:6443 max_fails=3 fail_timeout=30s;
		server 192.168.26.16:6443 max_fails=3 fail_timeout=30s;
    }
   
    server {
    	listen 7443;
        proxy_connect_timeout 2s;
        proxy_timeout 600s;
        proxy_pass kube-apiserver;
    }

}
EOF
```

#### 3. 启动nginx服务
```
nginx -t
systemctl enable nginx --now
```

## 二、安装keepalived
#### 1. 安装keepalived
```
# yum install keepalived -y
```

#### 2. 配置keepalived

```
# cat <<EOF > /etc/keepalived/keepalived.conf 
! Configuration File for keepalived

global_defs {
   router_id LVS_DEVEL
   script_user root
   enable_script_security 
}

vrrp_script check_apiserver {
  script "/etc/keepalived/check_apiserver.sh"
  interval 3 # 脚本执行间隔，每3s检测一次
  weight -3 # 脚本结果导致的优先级变更，检测失败（脚本返回非0）则优先级 -3
  fall 2 # 检测连续2次失败才算确定是真失败。会用weight减少优先级（1-255之间）
  rise 1             # 检测2次成功就算成功。但不修改优先级
}

vrrp_instance VI_1 {
    state MASTER
    interface ens33
    virtual_router_id 51
    priority 100
    advert_int 1
    authentication {
        auth_type PASS
        auth_pass 1111
    }
    virtual_ipaddress {
        192.168.26.10/24 dev ens33 label ens33:1   # 虚拟IP的设置(VIP)
    }
    track_script {
        check_apiserver
    }
    unicast_src_ip 192.168.26.15         # 关闭组播，使用单播通信，源ip为本机IP
    unicast_peer {                       # 对端ip，有多高填写多个IP
        192.168.26.16
    }
}
EOF
```

健康检查脚本
```
# cat <<'EOF' > /etc/keepalived/check_apiserver.sh 
#!/bin/sh

errorExit() {
    echo "*** $*" 1>&2
    exit 1
}

APISERVER_VIP="10.128.25.237"
APISERVER_DEST_PORT="7443"

curl --silent --max-time 2 --insecure https://localhost:${APISERVER_DEST_PORT}/ -o /dev/null || errorExit "Error GET https://localhost:${APISERVER_DEST_PORT}/"
if ip addr | grep -q ${APISERVER_VIP}; then
    curl --silent --max-time 2 --insecure https://${APISERVER_VIP}:${APISERVER_DEST_PORT}/ -o /dev/null || errorExit "Error GET https://${APISERVER_VIP}:${APISERVER_DEST_PORT}/"
fi
EOF

chmod +x /etc/keepalived/check_apiserver.sh
```

#### 3. 启动keepalived服务
```
systemctl enable keepalived --now
```

#### 4. 如果配置完全Ok,应该会看到如下信息
```
$ curl --cacert ca.pem https://10.128.25.234:8443/version
{
"major": "1",
"minor": "18",
"gitVersion": "v1.18.16",
"gitCommit": "7a98bb2b7c9112935387825f2fce1b7d40b76236",
"gitTreeState": "clean",
"buildDate": "2021-02-17T11:52:32Z",
"goVersion": "go1.13.15",
"compiler": "gc",
"platform": "linux/amd64"
```

