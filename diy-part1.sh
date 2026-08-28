#!/bin/bash

# 移除模板自带的 HellWorld feed，避免引入不需要的代理插件。
sed -i '/^src-git helloworld /d' feeds.conf.default
sed -i '/^src-git passwall /d' feeds.conf.default
sed -i '/^src-git passwall_packages /d' feeds.conf.default

# PassWall 主程序与依赖软件包。
echo 'src-git passwall_packages https://github.com/xiaorouji/openwrt-passwall-packages.git' >> feeds.conf.default
echo 'src-git passwall https://github.com/xiaorouji/openwrt-passwall.git' >> feeds.conf.default
