## tcpdump抓包分析keepalived

```
# tcpdump -i ens33 vrrp -w /tmp/keepalived15.pcap
```

## Wireshark(网络抓包工具)分析

<img src=".\images\tcpdump-1.png" style="zoom:80%;" />

<img src=".\images\tcpdump-2.png" style="zoom:80%;" />

正常是每秒发送一条vrrp消息，在第24秒时，停掉了MASTER机器的keepalived，发生了浮动IP飘移，源地址也由192.168.26.15变为了192.168.26.16，这时浮动IP已经跑到了BACKUP机器上。

<img src=".\images\tcpdump-3.png" style="zoom:80%;" />

另外图下方的红框中，包内容部分还可以看到的信息和配置文件一致，

```
  	route id:51 			
      优先级：99			
      认证：1111 			
      VIP：192.168.26.10
```

<img src=".\images\tcpdump-4.png" style="zoom:80%;" />



```
#  tcpdump -i ens33 vrrp -vv -nn
```

keepalived是通过vrrp协议做主备之间的心跳，当发生切换备获得浮动IP时，发送ARP包告诉其他机器现在VIP对应的mac地址已经变成了备机的网卡的mac地址。这时如果有新的机器要和VIP通信时，找到的就是备机，从而实现的高可用。

<img src=".\images\tcpdump-5.png" style="zoom:80%;" />

优先级为0，表示keepalived服务停了。