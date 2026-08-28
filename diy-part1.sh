#!/bin/sh

sed -i '/^src-git helloworld /d' feeds.conf.default
sed -i '/^src-git passwall /d' feeds.conf.default
sed -i '/^src-git passwall_luci /d' feeds.conf.default
sed -i '/^src-git passwall_packages /d' feeds.conf.default

temp_file="$(mktemp)"

{
    echo 'src-git passwall_luci https://github.com/Openwrt-Passwall/openwrt-passwall.git;25.8.26-1'
    cat feeds.conf.default
} > "$temp_file"

mv "$temp_file" feeds.conf.default
