#!/bin/sh
set -eu

# MosDNS 5.3.4 requires Go 1.26. Replace OpenWrt's Host Go package.
rm -rf feeds/packages/lang/golang
git clone --depth=1 --branch 26.x \
    https://github.com/sbwml/packages_lang_golang.git \
    feeds/packages/lang/golang
echo "OpenWrt Host Go source: $(git -C feeds/packages/lang/golang rev-parse --short HEAD)"

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
