#!/bin/sh
set -eu

# Clone PassWall dependency packages from the same point in time as the LuCI tag.
passwall_date="$(git -C feeds/passwall_luci show -s --format=%cI)"

rm -rf package/passwall-packages
git clone https://github.com/Openwrt-Passwall/openwrt-passwall-packages.git package/passwall-packages

passwall_packages_commit="$(
    git -C package/passwall-packages rev-list -n 1 --before="$passwall_date" origin/main
)"

test -n "$passwall_packages_commit"
git -C package/passwall-packages checkout -q "$passwall_packages_commit"

echo "PassWall LuCI date: $passwall_date"
echo "PassWall packages commit: $passwall_packages_commit"

mkdir -p files/etc/uci-defaults

cat > files/etc/uci-defaults/99-passwall-baseline <<'EOF'
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

chmod 0755 files/etc/uci-defaults/99-passwall-baseline
