#!/usr/bin/env bash
# KVM NAT 流量绕过 mihomo TUN 接管（开机恢复策略路由）
# 背景: mihomo 1.19 auto-route 的 ip rule (9002: not from all iif lo lookup 2022)
#       会接管 virbr0 转发的 VM 流量和 dnsmasq 上游查询, 导致 VM 出网/解析异常。
# 8900: VM (192.168.122.0/24, iif virbr0) 转发流量走主路由表直连出网
# 8800: dnsmasq 上游查询(源 192.168.122.1)走主路由表, 避免被 fake-ip 污染
# 注意: 两条规则优先级(8800/8900)低于 mihomo 的规则(9000+), 互不冲突。
set -u

ip rule del priority 8800 2>/dev/null || true
ip rule add priority 8800 from 192.168.122.1 lookup main
ip rule del priority 8900 2>/dev/null || true
ip rule add priority 8900 from 192.168.122.0/24 iif virbr0 lookup main
