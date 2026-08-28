#!/bin/sh

sed -i '/^src-git helloworld /d' feeds.conf.default
sed -i '/^src-git passwall /d' feeds.conf.default
sed -i '/^src-git passwall_packages /d' feeds.conf.default

echo 'src-git passwall_packages https://github.com/xiaorouji/openwrt-passwall-packages.git' >> feeds.conf.default
echo 'src-git passwall https://github.com/xiaorouji/openwrt-passwall.git' >> feeds.conf.default
