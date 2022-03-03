#!/bin/sh

#IP rules
ip rule add fwmark 1 lookup 100
ip route add local 0.0.0.0/0 dev lo table 100

# 局域网流量不做处理
iptables -t mangle -N TP_CLASH_V4
iptables -t mangle -F TP_CLASH_V4
iptables -t mangle -A TP_CLASH_V4 -d 0.0.0.0/8 -j RETURN
iptables -t mangle -A TP_CLASH_V4 -d 127.0.0.0/8 -j RETURN
iptables -t mangle -A TP_CLASH_V4 -d 10.0.0.0/8 -j RETURN
iptables -t mangle -A TP_CLASH_V4 -d 172.16.0.0/12 -j RETURN
iptables -t mangle -A TP_CLASH_V4 -d 192.168.0.0/16 -j RETURN
iptables -t mangle -A TP_CLASH_V4 -d 169.254.0.0/16 -j RETURN
iptables -t mangle -A TP_CLASH_V4 -d 224.0.0.0/4 -j RETURN
iptables -t mangle -A TP_CLASH_V4 -d 240.0.0.0/4 -j RETURN

# 所有 DNS 流量不做处理, 由后面的 NAT 表做 REDIRECT
iptables -t mangle -A TP_CLASH_V4 -p udp -m udp --dport 53 -j RETURN

# 其他 TCP/UDP 流量全部打 MARK, 进行 TProxy 处理
iptables -t mangle -A TP_CLASH_V4 -p tcp -j TPROXY --on-port 7893 --on-ip 0.0.0.0 --tproxy-mark 0x1/0x1
iptables -t mangle -A TP_CLASH_V4 -p udp -j TPROXY --on-port 7893 --on-ip 0.0.0.0 --tproxy-mark 0x1/0x1

# 对 DNS 流量 REDIRECT 到 Clash DNS 上
iptables -t nat -N TP_CLASH_DNS_V4
iptables -t nat -F TP_CLASH_DNS_V4
iptables -t nat -A TP_CLASH_DNS_V4 -p udp -m udp --dport 53 -j REDIRECT --to-ports 1053

# 通过 mangle/PREROUTING 转发给 TP_CLASH_V4
iptables -t mangle -I PREROUTING -p tcp -j TP_CLASH_V4
iptables -t mangle -I PREROUTING -p udp -j TP_CLASH_V4

# 通过 nat/PREROUTING 转发给 TP_CLASH_DNS_V4
iptables -t nat -I PREROUTING -p udp -m udp --dport 53 -j TP_CLASH_DNS_V4

# 转发的 ICMP 流量 DNAT 到本地
iptables -t nat -A PREROUTING -p icmp -j DNAT --to-destination 127.0.0.1
# 本地发出的 ICMP 流量同样 DNAT 到本地
iptables -t nat -A OUTPUT -p icmp -j DNAT --to-destination 127.0.0.1
