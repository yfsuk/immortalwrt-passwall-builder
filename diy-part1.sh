#!/bin/sh

sed -i '/^src-git helloworld /d' feeds.conf.default
sed -i '/^src-git passwall /d' feeds.conf.default
sed -i '/^src-git passwall_luci /d' feeds.conf.default
sed -i '/^src-git passwall_packages /d' feeds.conf.default

temp_file="$(mktemp)"

{
    echo 'src-git passwall_packages https://github.com/Openwrt-Passwall/openwrt-passwall-packages.git;main'
    echo 'src-git passwall_luci https://github.com/Openwrt-Passwall/openwrt-passwall.git;main'
    cat feeds.conf.default
} > "$temp_file"

mv "$temp_file" feeds.conf.default
