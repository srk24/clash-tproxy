#!/bin/sh

#IP rules
ip rule add fwmark 1 lookup 100
ip route add local 0.0.0.0/0 dev lo table 100

# 局域网流量不做处理
iptables -t mangle -N TP_CLASH
iptables -t mangle -F TP_CLASH
iptables -t mangle -A TP_CLASH -d 0.0.0.0/8 -j RETURN
iptables -t mangle -A TP_CLASH -d 127.0.0.0/8 -j RETURN
iptables -t mangle -A TP_CLASH -d 10.0.0.0/8 -j RETURN
iptables -t mangle -A TP_CLASH -d 172.16.0.0/12 -j RETURN
iptables -t mangle -A TP_CLASH -d 192.168.0.0/16 -j RETURN
iptables -t mangle -A TP_CLASH -d 169.254.0.0/16 -j RETURN
iptables -t mangle -A TP_CLASH -d 224.0.0.0/4 -j RETURN
iptables -t mangle -A TP_CLASH -d 240.0.0.0/4 -j RETURN

# 所有 DNS 流量不做处理, 由后面的 NAT 表做 REDIRECT
iptables -t mangle -A TP_CLASH -p udp -m udp --dport 53 -j RETURN

# 其他 TCP/UDP 流量全部打 MARK, 进行 TProxy 处理
iptables -t mangle -A TP_CLASH -p tcp -j TPROXY --on-port 7893 --on-ip 0.0.0.0 --tproxy-mark 0x1/0x1
iptables -t mangle -A TP_CLASH -p udp -j TPROXY --on-port 7893 --on-ip 0.0.0.0 --tproxy-mark 0x1/0x1

# 对 DNS 流量 REDIRECT 到 Clash DNS 上
iptables -t nat -N TP_CLASH_DNS
iptables -t nat -F TP_CLASH_DNS
iptables -t nat -A TP_CLASH_DNS -p udp -m udp --dport 53 -j REDIRECT --to-ports 1053

# 通过 mangle/PREROUTING 转发给 TP_CLASH
iptables -t mangle -I PREROUTING -p tcp -j TP_CLASH
iptables -t mangle -I PREROUTING -p udp -j TP_CLASH

# 通过 nat/PREROUTING 转发给 TP_CLASH_DNS
iptables -t nat -I PREROUTING -p udp -m udp --dport 53 -j TP_CLASH_DNS
