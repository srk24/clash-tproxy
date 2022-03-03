#!/bin/sh

### 注意事项：
###   1. 代理本地流量时需要使用 userclash 用户启动 clash

echo "start set clash iptables..."

# IP rules
ip rule add fwmark 1 lookup 100
ip route add local 0.0.0.0/0 dev lo table 100

iptables -t mangle -N TP_CLASH
iptables -t mangle -F TP_CLASH

# 将 clash fake ip pool 流量转发给clash
# iptables -t mangle -A TP_CLASH -p tcp -d 198.18.0.1/16 -j TPROXY --on-port 7893 --on-ip 0.0.0.0 --tproxy-mark 0x1/0x1
# iptables -t mangle -A TP_CLASH -p udp -d 198.18.0.1/16 -j TPROXY --on-port 7893 --on-ip 0.0.0.0 --tproxy-mark 0x1/0x1

# 局域网流量不做处理
iptables -t mangle -A TP_CLASH -d 0.0.0.0/8 -j RETURN
iptables -t mangle -A TP_CLASH -d 127.0.0.0/8 -j RETURN
iptables -t mangle -A TP_CLASH -d 10.0.0.0/8 -j RETURN
iptables -t mangle -A TP_CLASH -d 172.16.0.0/12 -j RETURN
iptables -t mangle -A TP_CLASH -d 192.168.0.0/16 -j RETURN
iptables -t mangle -A TP_CLASH -d 169.254.0.0/16 -j RETURN
iptables -t mangle -A TP_CLASH -d 224.0.0.0/4 -j RETURN
iptables -t mangle -A TP_CLASH -d 240.0.0.0/4 -j RETURN

# Clash 自己的流量不做处理
iptables -t mangle -A TP_CLASH -m owner --uid-owner userclash -j RETURN

# 所有 DNS 流量不做处理, 由后面的 NAT 表做 REDIRECT
iptables -t mangle -A TP_CLASH -p udp -m udp --dport 53 -j RETURN

# 其他 TCP/UDP 流量全部打 MARK, 进行 TProxy 处理
iptables -t mangle -A TP_CLASH -p tcp -j TPROXY --on-port 7893 --on-ip 0.0.0.0 --tproxy-mark 0x1/0x1
iptables -t mangle -A TP_CLASH -p udp -j TPROXY --on-port 7893 --on-ip 0.0.0.0 --tproxy-mark 0x1/0x1

# TCP/UDP 流量转发给 TP_CLASH
iptables -t mangle -I PREROUTING -p tcp -j TP_CLASH
iptables -t mangle -I PREROUTING -p udp -j TP_CLASH
iptables -t mangle -I OUTPUT -p tcp -j TP_CLASH
iptables -t mangle -I OUTPUT -p udp -j TP_CLASH

iptables -t nat -N TP_CLASH_DNS
iptables -t nat -F TP_CLASH_DNS

# Clash 自己发出的 DNS 流量不做处理
iptables -t nat -A TP_CLASH_DNS -m owner --uid-owner userclash -j RETURN

# DNS 流量 REDIRECT 到 Clash DNS
iptables -t nat -A TP_CLASH_DNS -p udp -m udp --dport 53 -j REDIRECT --to-ports 1053

# DNS 流量转发给 TP_CLASH_DNS
iptables -t nat -I PREROUTING -p udp -m udp --dport 53 -j TP_CLASH_DNS
iptables -t nat -I OUTPUT -p udp -m udp --dport 53 -j TP_CLASH_DNS

# ICMP 流量 DNAT 到本地
iptables -t nat -I PREROUTING -d 198.18.0.0/16 -p icmp -j DNAT --to-destination 127.0.0.1
iptables -t nat -I OUTPUT -d 198.18.0.0/16 -p icmp -j DNAT --to-destination 127.0.0.1

echo "set clash iptables done."
