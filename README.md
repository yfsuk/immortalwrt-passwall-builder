# PVE 旁路由：ImmortalWrt + PassWall + MosDNS + AdGuard Home

使用 GitHub Actions 编译 ImmortalWrt `v24.10.6`，目标为 x86_64 单网口旁路由。
主路由负责拨号和 DHCP；旁路由默认关闭 DHCP、IPv6 RA/DHCPv6 和流量卸载。

## 软件与编译文件

| 组件 | 用途 |
| --- | --- |
| PassWall（不是 PassWall2） | nftables 透明代理、域名分流，包含 Xray 和 sing-box |
| MosDNS 5.3.4 | 直连 DNS 解析和缓存，监听 `127.0.0.1:5335` |
| AdGuard Home 0.107.79 | 广告过滤、客户端查询日志和统计，自带独立网页 |
| dnsmasq-full | 对接 PassWall 域名规则及 nftset |
| Argon + 中文 LuCI | 路由管理界面 |

没有使用第三方 AdGuard Home LuCI 包；在它自己的网页中管理广告规则和统计。

| 文件 | 作用 |
| --- | --- |
| `.config` | 平台、镜像格式、软件包；根分区为 1024 MiB |
| `diy-part1.sh` | 移除旧 HomeProxy 源，添加并固定 PassWall、MosDNS 源 |
| `diy-part2.sh` | 固定 Go 1.26.9、回移新版 AdGuard Home、生成首次启动配置 |
| `.github/workflows/openwrt-builder.yml` | 安装软件源、检查必要软件包、编译并上传固件 |
| `.github/workflows/update-checker.yml` | 检查与构建一致的 ImmortalWrt 版本；未开启定时运行 |

AdGuard Home 使用 ImmortalWrt 当前配方的源码、前端版本及 SHA256，保留 24.10 的
启动脚本和配置路径。插件与工具链固定到具体提交；升级时需一起检查兼容性。

## 编译和 PVE 部署

将文件上传到自己的 GitHub 仓库，包含隐藏文件 `.config`、`.gitattributes` 和 `.github`。
在 **Actions → OpenWrt Builder → Run workflow** 手动构建，完成后下载固件 Artifact。
流程会在 `make defconfig` 后检查三个服务和必要依赖是否真正选中，缺包提前失败。

- PVE 虚拟机 SeaBIOS：使用 `*ext4-combined.img.gz`，解压后导入虚拟磁盘。
- PVE 虚拟机 OVMF/UEFI：使用 `*ext4-combined-efi.img.gz`。
- PVE LXC：使用 `*rootfs.tar.gz`。容器共用 PVE 内核，需要宿主机支持 nftables、
  TPROXY、策略路由并授予容器相应权限；固件内的 kmod 不能替代宿主机支持。
  希望减少这部分配置时使用虚拟机。

虚拟机使用 VirtIO 网卡，连接家庭 LAN 的桥（例如 `vmbr0`）。建议以 2 个 vCPU、
至少 1 GiB 内存起步；大量广告规则和长期日志需要更多空间和内存。
镜像根分区不会随着虚拟磁盘扩容而自动扩展。

## DNS 顺序

首次启动，尚未初始化 AdGuard Home 时：

```text
客户端 → dnsmasq :53 → MosDNS 127.0.0.1:5335 → 公共直连 DNS
```

完成端口交接、配置并启用 PassWall 后：

```text
客户端 → AdGuard Home :53（广告过滤、按客户端统计）
       → dnsmasq 127.0.0.1:54（PassWall 域名分流、nftset）
         ├─ 直连查询 → MosDNS 127.0.0.1:5335 → 直连 DNS
         └─ 代理查询 → PassWall 内部 DNS → 代理节点 → 远程 DNS
```

由 **PassWall 负责直连/代理分流**，MosDNS 只负责直连分支的解析和缓存。
MosDNS 的本地和远程上游均设为国内公共解析器，不再承担第二套代理分流。
PassWall 未启用时，普通查询经 MosDNS 直连解析；代理解析需等节点配置好。

AdGuard Home 的普通上游只填 `127.0.0.1:54`，不能指回自身的 53 端口；
也不要直接跳过 dnsmasq 指向 MosDNS，否则部分 PassWall 域名规则无法正常工作。

## 初始化步骤

### 1. 设置旁路由网络

先在 PVE 控制台或 LuCI 中设置 LAN 静态 IP、掩码、网关和 DNS。
**脚本不会预填你家的 IP、主路由地址或网卡名称。**
网关填写主路由，LAN 绑定 PVE 实际网卡，先确认旁路由能访问互联网。

例如主路由为 `192.168.1.1/24`，旁路由可设为未被占用、且不在 DHCP 地址池中的
`192.168.1.2/24`。这些地址只是示例，请替换为实际值。
旁路由接口 DNS 可先填 `223.5.5.5`，方便首次联网和下载订阅。
主路由保持为唯一 DHCP 服务器；全部配置完成前先用一台设备测试。

### 2. 初始化 AdGuard Home

AdGuard Home 已编译但默认未启用，不预设管理员账号或密码。
MosDNS 已启用，dnsmasq 暂时监听 53。先在旁路由 SSH 执行：

```sh
uci set dhcp.@dnsmasq[0].port='54'
uci commit dhcp
/etc/init.d/dnsmasq restart

uci set adguardhome.config.enabled='1'
uci commit adguardhome
/etc/init.d/adguardhome enable
/etc/init.d/adguardhome start
```

至向导完成前，旁路由 53 端口暂时没有 DNS。电脑可临时使用主路由或公共 DNS。
访问 `http://旁路由IP:3000` 完成向导：

- 网页端口保持 **3000**，避免占用 LuCI 的 80/443。
- DNS 监听旁路由 LAN 地址或所有接口，端口 **53**。
- 创建自己的管理员账号和密码。

向导完成后，在 **设置 → DNS 设置** 中修改：

- 上游 DNS：只保留 `127.0.0.1:54`。
- 后备 DNS：留空，避免绕过 PassWall 分流。
- Bootstrap DNS：可填 `223.5.5.5`；普通上游为 IP，本身不需要域名引导。
- DNS 缓存大小：设为 **0**，直连缓存由 MosDNS 管理，避免前置缓存命中时
  dnsmasq/PassWall 的域名 IP 集合没有及时更新。
- 关闭“使用私有反向 DNS 解析器”和客户端反向解析；确需使用时，填写独立的主路由
  反向解析地址，避免自动取到旁路由自身而循环查询。
- 在“过滤器 → DNS 封锁清单”启用需要的广告规则，先从少量规则开始。

配置文件是 `/etc/adguardhome.yaml`，工作目录是 `/etc/adguardhome`，
过滤规则和统计保存在磁盘。建议限制查询日志保留时间，避免占满根分区。

### 3. 配置 PassWall

在 **服务 → PassWall** 导入订阅或节点，选择可用节点，再启用主开关。
首次启动已设置：

- nftables 透明代理，DNS 分流方式为 `dnsmasq`。
- 直连 DNS：UDP `127.0.0.1:5335`，即 MosDNS。
- 代理 DNS：Xray，TCP 远程 DNS `1.1.1.1`，经配置的代理节点访问。
- 关闭 DNS 重定向/劫持、FakeDNS，以及访问控制中的独立客户端规则。

保留这些 DNS 设置，尤其不要开启 PassWall DNS 劫持，或为访问控制启用独立 DNS
实例，否则查询可能绕过 AdGuard Home。普通域名分流规则仍然有效。
如果选用 Xray 分流节点，需要将默认代理出口设为实际节点，不能保持“直连”。
MosDNS 中保持“DNS 转发到 MosDNS”“DNS 劫持”和广告过滤关闭，避免多个服务
同时改写 dnsmasq 或重复屏蔽；广告规则由 AdGuard Home 管理。

### 4. 切换客户端

对需要代理和广告过滤的客户端设置：

- IPv4 网关：旁路由 LAN IP。
- DNS：旁路由 LAN IP，不额外添加公共 DNS 作为备用。

测试正常后，可在主路由 DHCP 中下发旁路由网关和 DNS。
客户端直接查询旁路由时，AdGuard Home 才能记录每台客户端的来源地址；
如果统一由主路由转发 DNS，日志通常只显示主路由。

此配置按 IPv4 旁路由设计。只关闭旁路由 IPv6 服务，不能阻止主路由继续向客户端
下发 IPv6 默认路由或 DNS；测试时需一起检查主路由和客户端 IPv6 设置。
浏览器/系统 DoH、私人 DNS 也可能绕过本地 DNS，需要在测试设备上检查。

默认关闭 ICMP Redirect 和流量卸载。若单臂转发受主路由回程路径影响，出现部分连接
异常，可在 LAN 防火墙区域评估开启 IPv4 masquerading，使经过旁路由的连接使用
旁路由源地址；这会改变主路由看到的来源，不在未知网络下自动启用。

## 检查和恢复

旁路由 SSH 中检查：

```sh
/etc/init.d/mosdns status
/etc/init.d/adguardhome status
/etc/init.d/passwall status
netstat -lntup | grep -E ':(53|54|5335|3000)[[:space:]]'
logread -e mosdns
logread -e adguardhome
```

预期 AdGuard Home 监听 53，dnsmasq 监听 54，MosDNS 监听 `127.0.0.1:5335`。
PassWall 启用后还会创建内部监听端口。
客户端运行 `nslookup example.com 旁路由IP`，确认 AdGuard Home 日志出现该客户端；
再测试封锁清单内的域名和需要代理的网站。重启旁路由后再次确认解析和自启动。

AdGuard Home 初始化失败时，可以暂时恢复 dnsmasq：

```sh
/etc/init.d/adguardhome stop
uci set adguardhome.config.enabled='0'
uci commit adguardhome
uci set dhcp.@dnsmasq[0].port='53'
uci commit dhcp
/etc/init.d/dnsmasq restart
```

默认配置仅适用于新系统首次启动。保留设置升级会继续使用旧的 `/etc/config/*`，
不会自动完成 HomeProxy 迁移。请先备份，在 PVE 新建虚拟机验证，或逐项手动迁移，
并停止旧 HomeProxy 服务。

## 致谢与许可证

构建流程基于 [P3TERX/Actions-OpenWrt](https://github.com/P3TERX/Actions-OpenWrt)，
使用 [ImmortalWrt](https://github.com/immortalwrt/immortalwrt)、
[PassWall](https://github.com/Openwrt-Passwall/openwrt-passwall)、
[MosDNS LuCI](https://github.com/sbwml/luci-app-mosdns) 和
[AdGuard Home](https://github.com/AdguardTeam/AdGuardHome)。
脚本沿用 MIT 许可证，见 [LICENSE](LICENSE)；上游软件适用各自许可证。
