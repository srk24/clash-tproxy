#!/bin/sh

### 注意事项：
###   1. 代理本地流量时需要使用 userclash 用户启动 clash

echo "clash iptables start init..."
echo "[INFO] Please start clash with uid=userclash!"

# route rules
ip rule add fwmark 1 lookup 100
ip route add local 0.0.0.0/0 dev lo table 100

# init TP_CLASH
iptables -t mangle -N TP_CLASH
iptables -t mangle -F TP_CLASH

# local clients
iptables -t mangle -A TP_CLASH -d 0.0.0.0/8 -j RETURN
iptables -t mangle -A TP_CLASH -d 127.0.0.0/8 -j RETURN
iptables -t mangle -A TP_CLASH -d 10.0.0.0/8 -j RETURN
iptables -t mangle -A TP_CLASH -d 172.16.0.0/12 -j RETURN
iptables -t mangle -A TP_CLASH -d 192.168.0.0/16 -j RETURN
iptables -t mangle -A TP_CLASH -d 169.254.0.0/16 -j RETURN
iptables -t mangle -A TP_CLASH -d 224.0.0.0/4 -j RETURN
iptables -t mangle -A TP_CLASH -d 240.0.0.0/4 -j RETURN

# prevent dns redirect
iptables -t mangle -A TP_CLASH -p udp --dport 53 -j RETURN

# tproxy mark
iptables -t mangle -A TP_CLASH -p tcp -j TPROXY --on-port 7893 --tproxy-mark 1
iptables -t mangle -A TP_CLASH -p udp -j TPROXY --on-port 7893 --tproxy-mark 1

# redirect
iptables -t mangle -A PREROUTING -j TP_CLASH

# init TP_CLASH_DNS
iptables -t nat -N TP_CLASH_DNS
iptables -t nat -F TP_CLASH_DNS

# redirect to clash dns
iptables -t nat -A TP_CLASH_DNS -p udp -j REDIRECT --to-ports 1053

# redirect
iptables -t nat -A PREROUTING -p udp --dport 53 -j TP_CLASH_DNS

# DNAT ICMP to local
iptables -t nat -A PREROUTING -d 198.18.0.0/16 -p icmp -j DNAT --to-destination 127.0.0.1


## host network 

# init TP_CLASH_LOCAL
iptables -t mangle -N TP_CLASH_LOCAL
iptables -t mangle -F TP_CLASH_LOCAL

# local clients
iptables -t mangle -A TP_CLASH_LOCAL -d 0.0.0.0/8 -j RETURN
iptables -t mangle -A TP_CLASH_LOCAL -d 127.0.0.0/8 -j RETURN
iptables -t mangle -A TP_CLASH_LOCAL -d 10.0.0.0/8 -j RETURN
iptables -t mangle -A TP_CLASH_LOCAL -d 172.16.0.0/12 -j RETURN
iptables -t mangle -A TP_CLASH_LOCAL -d 192.168.0.0/16 -j RETURN
iptables -t mangle -A TP_CLASH_LOCAL -d 169.254.0.0/16 -j RETURN
iptables -t mangle -A TP_CLASH_LOCAL -d 224.0.0.0/4 -j RETURN
iptables -t mangle -A TP_CLASH_LOCAL -d 240.0.0.0/4 -j RETURN

# Clash 自己的流量不做处理
iptables -t mangle -A TP_CLASH_LOCAL -m owner --uid-owner userclash -j RETURN

# 跳过 DNS 流量, 由后面的 NAT 表做 REDIRECT
iptables -t mangle -A TP_CLASH_LOCAL -p udp --dport 53 -j RETURN

# 其他 TCP/UDP 流量打 MARK 重新路由
iptables -t mangle -A TP_CLASH_LOCAL -p tcp -j MARK --set-xmark 1
iptables -t mangle -A TP_CLASH_LOCAL -p udp -j MARK --set-xmark 1

# redirect
iptables -t mangle -A OUTPUT -j TP_CLASH_LOCAL

# init TP_CLASH_DNS
iptables -t nat -N TP_CLASH_DNS_LOCAL
iptables -t nat -F TP_CLASH_DNS_LOCAL

# redirect to clash dns
iptables -t nat -A TP_CLASH_DNS_LOCAL -m owner --uid-owner userclash -j RETURN
iptables -t nat -A TP_CLASH_DNS_LOCAL -p udp -j REDIRECT --to-ports 1053

# redirect
iptables -t nat -A OUTPUT -p udp --dport 53 -j TP_CLASH_DNS_LOCAL

# DNAT ICMP to local
iptables -t nat -A OUTPUT -d 198.18.0.0/16 -p icmp -j DNAT --to-destination 127.0.0.1

echo "clash iptables init done."