#!/bin/sh
set -eu

# Keep the image focused on HomeProxy. PassWall and HomeProxy must not manage
# the same transparent-proxy nftables hooks in the initial compatibility test.
sed -i '/^src-git \(helloworld\|passwall\|passwall_luci\|passwall_packages\|homeproxy\|mosdns\) /d' feeds.conf.default

temp_file="$(mktemp)"
{
    echo 'src-git mosdns https://github.com/sbwml/luci-app-mosdns.git'
    cat feeds.conf.default
} > "$temp_file"

mv "$temp_file" feeds.conf.default
