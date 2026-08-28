#!/bin/sh

mkdir -p files/etc/uci-defaults

cat > files/etc/uci-defaults/99-passwall-baseline <<'EOF'
#!/bin/sh

# Use Argon as the default LuCI theme.
uci set luci.main.mediaurlbase='/luci-static/argon'
uci commit luci

# iKuai remains the DHCP server.
uci set dhcp.lan.ignore='1'
uci commit dhcp

# Disable IPv6 address assignment and advertisements on LAN.
uci set network.lan.ip6assign='0'
uci set dhcp.lan.ra='disabled'
uci set dhcp.lan.dhcpv6='disabled'
uci set dhcp.lan.ndp='disabled'
uci commit network
uci commit dhcp

# Required for one-arm NAT on a bridged LAN.
grep -qxF 'net.bridge.bridge-nf-call-iptables=0' /etc/sysctl.conf || \
    echo 'net.bridge.bridge-nf-call-iptables=0' >> /etc/sysctl.conf
sysctl -w net.bridge.bridge-nf-call-iptables=0

exit 0
EOF

chmod 0755 files/etc/uci-defaults/99-passwall-baseline
