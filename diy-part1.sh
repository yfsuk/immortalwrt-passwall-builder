#!/bin/sh
set -eu

sed -i '/^src-git \(helloworld\|passwall\|passwall_luci\|passwall_packages\|homeproxy\|mosdns\) /d' feeds.conf.default

# Remove the old standalone HomeProxy checkout when reusing a build tree.
rm -rf package/homeproxy

# Put the maintained PassWall feeds first so their cores take precedence over
# the older packages bundled with ImmortalWrt 24.10. Pin reviewed revisions.
temp_file="$(mktemp)"
{
    echo 'src-git passwall_packages https://github.com/Openwrt-Passwall/openwrt-passwall-packages.git^4a66c03c357333538f161bcb2588043c08673c19'
    echo 'src-git passwall_luci https://github.com/Openwrt-Passwall/openwrt-passwall.git^447fa53504dc314f051c29930b23169592c14457'
    echo 'src-git mosdns https://github.com/sbwml/luci-app-mosdns.git^bd40245303cd0ba56804d49eed5dbc4be2a082ca'
    cat feeds.conf.default
} > "$temp_file"

mv "$temp_file" feeds.conf.default
