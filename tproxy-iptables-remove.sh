#!/bin/sh

iptables -t mangle -D PREROUTING -p tcp -j TP_CLASH
iptables -t mangle -D PREROUTING -p udp -j TP_CLASH
iptables -t nat -D PREROUTING -p udp -m udp --dport 53 -j TP_CLASH_DNS

iptables -t mangle -F TP_CLASH
iptables -t mangle -X TP_CLASH
iptables -t nat -F TP_CLASH_DNS
iptables -t nat -X TP_CLASH_DNS
