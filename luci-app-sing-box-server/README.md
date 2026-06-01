# luci-app-sing-box-server

OpenWrt LuCI 插件 —— sing-box 服务端管理界面，支持 **OpenWrt 25.03** (及 23.05 / 24.10)。

---

## 功能特性

| 协议 | 传输层 | TLS | REALITY |
|------|--------|-----|---------|
| VMess | TCP / WebSocket / HTTP/2 / gRPC / HTTP Upgrade | ✓ | — |
| VLESS | TCP / WebSocket / HTTP/2 / gRPC / HTTP Upgrade | ✓ | ✓ |
| Shadowsocks (含 2022) | TCP / UDP | — | — |
| Trojan | TCP / WebSocket / HTTP/2 / gRPC / HTTP Upgrade | ✓ | — |
| Hysteria2 | QUIC（内置）| 必须 | — |
| TUIC v5 | QUIC（内置）| 必须 | — |
| SOCKS5 | TCP | — | — |
| HTTP | TCP | — | — |

- **多用户**：VMess / VLESS / Trojan / Hysteria2 / TUIC 支持在一个端口配置多个 UUID/密码。
- **多实例**：每个"用户"条目独立运行一个 sing-box 进程，互不影响。
- **防火墙**：自动调用 fw4 (nftables) 为启用端口放行入站流量。
- **日志**：Web 界面实时滚动查看运行日志，一键清空。
- **运行状态**：用户列表自动轮询每个实例的运行状态（绿色 ✓ / 红色 ✗）。

---

## 目录结构

```
luci-app-sing-box-server/
├── Makefile                                         # OpenWrt 包构建文件
├── root/
│   ├── etc/
│   │   ├── config/sing_box_server                   # UCI 默认配置
│   │   ├── init.d/sing_box_server                   # 服务管理脚本
│   │   └── uci-defaults/luci-app-sing-box-server    # 安装后初始化
│   └── usr/share/sing_box_server/
│       └── firewall.include                         # fw4 防火墙规则脚本
├── luasrc/
│   ├── controller/sing_box_server.lua               # LuCI 路由控制器
│   ├── model/cbi/sing_box_server/
│   │   ├── index.lua                                # 主页：全局开关 + 用户列表
│   │   ├── config.lua                               # 用户详情配置页
│   │   └── api/
│   │       ├── genconfig.lua                        # UCI → sing-box JSON 生成器
│   │       └── singbox.lua                          # 版本/状态工具函数
│   └── view/sing_box_server/
│       ├── status.htm                               # 版本号 + 重启按钮
│       ├── users_status.htm                         # 每行状态徽章
│       ├── users_list_status.htm                    # XHR 轮询脚本
│       └── log.htm                                  # 日志查看器
└── po/zh-cn/sing_box_server.po                      # 简体中文翻译
```

---

## 依赖

| 依赖 | 说明 |
|------|------|
| `sing-box` | 核心运行时（`/usr/bin/sing-box`）|
| `luci-base` | LuCI 框架（luci.mk 自动引入）|

OpenWrt 25.03 官方源已包含 sing-box 软件包：

```sh
opkg update && opkg install sing-box
```

---

## 安装方法

### 方法 A：放入 OpenWrt 构建树（推荐）

1. 将本目录放置到 OpenWrt SDK 或构建树中：

   ```
   feeds/luci/applications/luci-app-sing-box-server/
   ```

2. 更新 feeds 索引并安装：

   ```sh
   ./scripts/feeds update luci
   ./scripts/feeds install luci-app-sing-box-server
   make menuconfig   # 选中 LuCI → Applications → luci-app-sing-box-server
   make package/luci-app-sing-box-server/compile V=s
   ```

3. 生成的 `.ipk` 文件位于 `bin/packages/<arch>/luci/` 下，scp 到路由器后：

   ```sh
   opkg install luci-app-sing-box-server_*.ipk
   ```

### 方法 B：直接拷贝文件（开发/调试）

```sh
# 以下操作在路由器上执行
scp -r luasrc/controller/sing_box_server.lua root@router:/usr/lib/lua/luci/controller/
scp -r luasrc/model/cbi/sing_box_server       root@router:/usr/lib/lua/luci/model/cbi/
scp -r luasrc/view/sing_box_server             root@router:/usr/lib/lua/luci/view/
scp root/etc/init.d/sing_box_server            root@router:/etc/init.d/
scp root/etc/config/sing_box_server            root@router:/etc/config/
scp root/usr/share/sing_box_server/firewall.include \
    root@router:/usr/share/sing_box_server/
chmod +x /etc/init.d/sing_box_server /usr/share/sing_box_server/firewall.include
rm -rf /tmp/luci-*          # 清除 LuCI 缓存
/etc/init.d/sing_box_server enable
```

---

## 配置说明

Web 界面路径：**LuCI → VPN → sing-box Server**

### 全局设置

| 选项 | 说明 |
|------|------|
| Enable | 总开关；关闭时停止所有实例并清除防火墙规则 |

### 用户/实例设置

| 选项 | 说明 |
|------|------|
| Enable | 单独启用/禁用该实例 |
| Remarks | 仅供界面显示用的备注 |
| Bind Local | 仅监听 127.0.0.1，配合 Nginx 等反代使用 |
| Port | 监听端口（1–65535）|
| Protocol | 见上方协议表 |

#### VMess / VLESS 特有选项

| 选项 | 说明 |
|------|------|
| UUID | 支持多个，一行一个（DynamicList）|
| Alter ID | VMess 专用，保持 0 使用 AEAD（推荐）|
| Flow | VLESS 专用，`xtls-rprx-vision` 需配合 TCP+TLS/REALITY |
| Transport | TCP / WebSocket / HTTP/2 / gRPC / HTTP Upgrade |

#### Shadowsocks 特有选项

| 选项 | 说明 |
|------|------|
| Encrypt Method | 支持 AEAD 及 2022 系列算法 |
| Network | TCP / UDP / TCP+UDP（默认）|

#### Hysteria2 特有选项

| 选项 | 说明 |
|------|------|
| Password | 多用户，每行一个密码 |
| Obfs Password | Salamander 混淆密码（可选）|
| Upload/Download Mbps | 服务端带宽限速（留空不限）|

#### TUIC v5 特有选项

| 选项 | 说明 |
|------|------|
| UUID | 多用户，与下方密码列表一一对应 |
| Password (per UUID) | 与上方 UUID 列表一一对应 |
| Congestion Control | BBR（默认）/ CUBIC / New Reno |

#### TLS / REALITY 选项

| 选项 | 说明 |
|------|------|
| Enable TLS | VMess / VLESS / Trojan 可选；Hysteria2 / TUIC 强制启用 |
| Certificate File | PEM 格式证书绝对路径（如 `/etc/ssl/fullchain.pem`）|
| Key File | 私钥绝对路径（如 `/etc/ssl/private.key`）|
| Enable REALITY | 仅 VLESS；替代 TLS，无需证书文件 |
| Handshake Server / Port | REALITY 伪装目标（需支持 TLS 1.3）|
| Private / Public Key | 用 `sing-box generate reality-keypair` 生成 |
| Short ID | 最多 8 字节十六进制串 |

---

## UCI 配置示例

```uci
config global
    option enable '1'

# VMess + WebSocket + TLS
config user
    option enable '1'
    option remarks 'vmess-ws-tls'
    option bind_local '0'
    option protocol 'vmess'
    option port '443'
    list vmess_uuid 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx'
    option vmess_alter_id '0'
    option transport 'ws'
    option ws_path '/ws'
    option tls_enable '1'
    option tls_cert_file '/etc/ssl/fullchain.pem'
    option tls_key_file '/etc/ssl/private.key'

# VLESS + TCP + REALITY
config user
    option enable '1'
    option remarks 'vless-reality'
    option bind_local '0'
    option protocol 'vless'
    option port '8443'
    list vless_uuid 'yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyyy'
    option vless_flow 'xtls-rprx-vision'
    option transport 'tcp'
    option reality_enable '1'
    option reality_server 'www.microsoft.com'
    option reality_server_port '443'
    option reality_private_key '<x25519-private-key>'
    option reality_public_key '<x25519-public-key>'
    option reality_short_id '1234abcd'

# Hysteria2
config user
    option enable '1'
    option remarks 'hysteria2'
    option bind_local '0'
    option protocol 'hysteria2'
    option port '8080'
    list hysteria2_password 'mypassword'
    option tls_cert_file '/etc/ssl/fullchain.pem'
    option tls_key_file '/etc/ssl/private.key'

# Shadowsocks 2022
config user
    option enable '1'
    option remarks 'ss2022'
    option bind_local '0'
    option protocol 'shadowsocks'
    option port '8388'
    option ss_method '2022-blake3-chacha20-poly1305'
    option ss_password 'base64encodedkey=='
    option ss_network 'tcp,udp'
```

---

## REALITY 密钥对生成

在路由器上执行（需已安装 sing-box）：

```sh
sing-box generate reality-keypair
```

输出示例：

```
PrivateKey: <填入 Private Key 字段>
PublicKey:  <填入 Public Key 字段，分发给客户端>
```

---

## 与原 luci-app-v2ray-server 的主要差异

| 方面 | v2ray-server | sing-box-server |
|------|-------------|-----------------|
| 核心进程 | xray / v2ray | sing-box |
| 配置格式 | v2ray JSON (v4) | sing-box JSON |
| 防火墙框架 | fw3 / iptables | **fw4 / nftables**（OpenWrt 21.02+）|
| 新增协议 | — | VLESS、Trojan、Hysteria2、TUIC v5 |
| REALITY | — | ✓ |
| Shadowsocks 2022 | — | ✓ |
| 传输层 | TCP/mKCP/WS/H2/QUIC | TCP/WS/H2/gRPC/HTTPUpgrade |
| 多用户 | 单端口单用户 | 单端口多用户（UUID 列表）|

---

## License

GPL-3.0-or-later
