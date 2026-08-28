#!/bin/bash

# 在首次启动时应用配置，执行成功后 OpenWrt 会自动删除此文件。
mkdir -p files/etc/uci-defaults

cat > files/etc/uci-defaults/99-passwall-baseline <<'EOF'
#!/bin/sh

# Argon 作为 LuCI 默认主题。
uci set luci.main.mediaurlbase='/luci-static/argon'
uci commit luci

# DHCP 由爱快提供，OpenWrt 不参与下发。
uci set dhcp.lan.ignore='1'

# 不在 OpenWrt LAN 下发 IPv6。
uci set network.lan.ip6assign='0'
uci set dhcp.lan.ra='disabled'
uci set dhcp.lan.dhcpv6='disabled'
uci set dhcp.lan.ndp='disabled'
uci commit network
uci commit dhcp

# 单臂旁路由同接口 NAT 回程修复。
grep -qxF 'net.bridge.bridge-nf-call-iptables=0' /etc/sysctl.conf || \
    echo 'net.bridge.bridge-nf-call-iptables=0' >> /etc/sysctl.conf
sysctl -w net.bridge.bridge-nf-call-iptables=0

exit 0
EOF

chmod 0755 files/etc/uci-defaults/99-passwall-baseline
