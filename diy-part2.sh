#!/bin/sh
set -eu

# MosDNS 5.3.4 requires Go 1.26. Replace OpenWrt's Host Go package.
rm -rf feeds/packages/lang/golang
git clone --depth=1 --branch 26.x \
    https://github.com/sbwml/packages_lang_golang.git \
    feeds/packages/lang/golang
git -C feeds/packages/lang/golang fetch --depth=1 origin \
    dba928c4f25b3290090d5937fcc6271f01a2ec91
git -C feeds/packages/lang/golang checkout --detach FETCH_HEAD
echo "OpenWrt Host Go source: $(git -C feeds/packages/lang/golang rev-parse --short HEAD)"

# Backport AdGuard Home 0.107.79 and its matching frontend from ImmortalWrt's
# current package recipe. Keep the 24.10 init script and /etc/adguardhome.yaml
# layout, while updating dependencies for the shared Go toolchain.
adguard_makefile=feeds/packages/net/adguardhome/Makefile
test -f "$adguard_makefile"
sed -i \
    -e 's/^PKG_VERSION:=.*/PKG_VERSION:=0.107.79/' \
    -e 's/^PKG_HASH:=.*/PKG_HASH:=5f4fa119f24ea741bb8cecfa74203165fe6b86b904cef05ff429fb227b07d425/' \
    -e 's/^[[:space:]]*HASH:=.*/\tHASH:=30184c157d4aefe5371b575a43c0ab5a7314aef039a820cc421ea67bab994ce8/' \
    -e 's@internal/version.buildtime=$(AGH_BUILD_TIME)@internal/version.committime=$(SOURCE_DATE_EPOCH)@' \
    "$adguard_makefile"

mkdir -p files/etc/uci-defaults

cat > files/etc/uci-defaults/99-router-baseline <<'EOF'
#!/bin/sh
set -eu

uci set luci.main.mediaurlbase='/luci-static/argon'
uci commit luci

# The main router remains the DHCP server. Keep the existing LAN address:
# configure LAN IP, gateway and interface assignment for the actual PVE host.
uci set dhcp.lan.ignore='1'
uci set network.lan.ip6assign='0'
uci set dhcp.lan.ra='disabled'
uci set dhcp.lan.dhcpv6='disabled'
uci set dhcp.lan.ndp='disabled'
uci commit network

# Initial boot: dnsmasq :53 -> MosDNS :5335. Only move dnsmasq to :54 when
# setting up AdGuard Home, so DNS remains usable before its account exists.
uci set dhcp.@dnsmasq[0].port='53'
uci set dhcp.@dnsmasq[0].noresolv='1'
uci set dhcp.@dnsmasq[0].cachesize='0'
uci set dhcp.@dnsmasq[0].dns_redirect='0'
uci -q delete dhcp.@dnsmasq[0].server || true
uci add_list dhcp.@dnsmasq[0].server='127.0.0.1#5335'
uci commit dhcp

# MosDNS is a direct resolver here. Never derive its upstream from LAN DNS,
# which will eventually point back to AdGuard Home and create a DNS loop.
uci set mosdns.config.enabled='1'
uci set mosdns.config.listen_address='127.0.0.1'
uci set mosdns.config.listen_port='5335'
uci set mosdns.config.redirect='0'
uci set mosdns.config.local_dns_redirect='0'
uci set mosdns.config.adblock='0'
uci set mosdns.config.custom_local_dns='1'
uci -q delete mosdns.config.local_dns || true
uci add_list mosdns.config.local_dns='223.5.5.5'
uci add_list mosdns.config.local_dns='119.29.29.29'
uci -q delete mosdns.config.remote_dns || true
uci add_list mosdns.config.remote_dns='https://dns.alidns.com/dns-query'
uci add_list mosdns.config.remote_dns='https://doh.pub/dns-query'
uci set mosdns.config.bootstrap_dns='223.5.5.5'
uci commit mosdns
/etc/init.d/mosdns enable

# PassWall owns domain/proxy routing in dnsmasq. DNS hijacking and per-client
# ACL DNS instances would bypass the AdGuard Home entry point, so leave them off.
if ! uci -q get passwall.@global[0] >/dev/null; then
    cp /usr/share/passwall/0_default_config /etc/config/passwall
fi
uci set passwall.@global[0].enabled='0'
uci set passwall.@global[0].dns_shunt='dnsmasq'
uci set passwall.@global[0].dns_redirect='0'
uci set passwall.@global[0].acl_enable='0'
uci set passwall.@global[0].direct_dns_mode='udp'
uci set passwall.@global[0].direct_dns='127.0.0.1:5335'
uci set passwall.@global[0].dns_mode='xray'
uci set passwall.@global[0].v2ray_dns_mode='tcp'
uci set passwall.@global[0].remote_dns='1.1.1.1'
uci set passwall.@global[0].use_default_dns='direct'
uci set passwall.@global[0].remote_fakedns='0'
uci set passwall.@global_forwarding[0].prefer_nft='1'
uci commit passwall

# AdGuard Home's wizard creates the administrator account and YAML config.
# Preserve filters/statistics on disk instead of the default volatile /var.
uci set adguardhome.config.enabled='0'
uci set adguardhome.config.workdir='/etc/adguardhome'
uci commit adguardhome

uci set firewall.@defaults[0].flow_offloading='0'
uci set firewall.@defaults[0].flow_offloading_hw='0'
uci commit firewall

exit 0
EOF

chmod 0755 files/etc/uci-defaults/99-router-baseline

# ICMP redirects on a one-arm router can make clients bypass its gateway.
mkdir -p files/etc/sysctl.d
cat > files/etc/sysctl.d/99-bypass-router.conf <<'EOF'
net.ipv4.ip_forward=1
net.ipv4.conf.all.send_redirects=0
net.ipv4.conf.default.send_redirects=0
EOF

# Existing interfaces may still have send_redirects=1 even when all/default
# are zero. Apply it to each interface whenever the network comes up.
mkdir -p files/etc/hotplug.d/iface
cat > files/etc/hotplug.d/iface/90-bypass-router <<'EOF'
#!/bin/sh
[ "$ACTION" = 'ifup' ] || exit 0
for setting in /proc/sys/net/ipv4/conf/*/send_redirects; do
    [ -f "$setting" ] || continue
    echo 0 > "$setting"
done
EOF
chmod 0755 files/etc/hotplug.d/iface/90-bypass-router
