#!/bin/sh
set -eu

sed -i '/^src-git \(helloworld\|passwall\|passwall_luci\|passwall_packages\|homeproxy\|mosdns\) /d' feeds.conf.default

rm -rf package/homeproxy
git clone https://github.com/immortalwrt/homeproxy.git \
  package/homeproxy/luci-app-homeproxy
git -C package/homeproxy/luci-app-homeproxy checkout -q \
  edece28a0085f36d469ec82c8d45f562f602db53

temp_file="$(mktemp)"
{
    echo 'src-git mosdns https://github.com/sbwml/luci-app-mosdns.git;v5'
    cat feeds.conf.default
} > "$temp_file"

mv "$temp_file" feeds.conf.default
