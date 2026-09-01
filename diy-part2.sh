#!/bin/sh
set -eu

# This revision contains the current sing-box configuration generator fixes.
git -C feeds/homeproxy checkout -q edece28a0085f36d469ec82c8d45f562f602db53
echo "HomeProxy commit: $(git -C feeds/homeproxy rev-parse --short HEAD)"

mkdir -p files/etc/uci-defaults

cat > files/etc/uci-defaults/99-router-baseline <<'EOF'
#!/bin/sh

uci set luci.main.mediaurlbase='/luci-static/argon'
uci commit luci

uci set dhcp.lan.ignore='1'
uci commit dhcp

uci set network.lan.ip6assign='0'
uci set dhcp.lan.ra='disabled'
uci set dhcp.lan.dhcpv6='disabled'
uci set dhcp.lan.ndp='disabled'
uci commit network
uci commit dhcp

grep -qxF 'net.bridge.bridge-nf-call-iptables=0' /etc/sysctl.conf || \
    echo 'net.bridge.bridge-nf-call-iptables=0' >> /etc/sysctl.conf
sysctl -w net.bridge.bridge-nf-call-iptables=0

exit 0
EOF

chmod 0755 files/etc/uci-defaults/99-router-baseline
