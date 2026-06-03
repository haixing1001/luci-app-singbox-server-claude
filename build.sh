#!/bin/bash

# 创建主目录和子目录
mkdir -p luci-app-singbox-server/{root/etc/config,root/etc/init.d,root/usr/share/singbox_server,luasrc/controller,luasrc/model/cbi/singbox_server,po/zh-cn}

cd luci-app-singbox-server

# 1. 生成 Makefile
cat << 'EOF' > Makefile
include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-singbox-server
PKG_VERSION:=1.0.4
PKG_RELEASE:=0

LUCI_TITLE:=LuCI support for Standalone Sing-Box Server
LUCI_PKGARCH:=all
LUCI_DEPENDS:=+luci-base +luci-compat +luci-lib-jsonc

define Package/$(PKG_NAME)/conffiles
/etc/config/singbox_server
endef

include $(TOPDIR)/feeds/luci/luci.mk

# call BuildPackage - OpenWrt buildroot signature
EOF

# 2. 生成 Controller
cat << 'EOF' > luasrc/controller/singbox_server.lua
module("luci.controller.singbox_server", package.seeall)

function index()
    if not nixio.fs.access("/etc/config/singbox_server") then
        return
    end

    entry({"admin", "services", "singbox_server"}, cbi("singbox_server/server"), _("Sing-Box Server"), 50).dependent = true
end
EOF

# 3. 生成 CBI Model (Web UI)
cat << 'EOF' > luasrc/model/cbi/singbox_server/server.lua
local m, s, o
local fs = require "nixio.fs"

m = Map("singbox_server", translate("Sing-Box Server"), translate("Standalone Sing-Box Server configuration based on Passwall2 logic."))

s = m:section(TypedSection, "server", translate("Server Instances"))
s.anonymous = true
s.addremove = true

o = s:option(Flag, "enable", translate("Enable"))
o.default = 0
o.rmempty = false

o = s:option(Value, "remarks", translate("Remarks"))
o.default = "My Server"

o = s:option(ListValue, "protocol", translate("Protocol"))
o:value("mixed", "Mixed")
o:value("socks", "Socks")
o:value("http", "HTTP")
o:value("shadowsocks", "Shadowsocks")
o:value("vmess", "Vmess")
o:value("vless", "VLESS")
o:value("trojan", "Trojan")
o:value("hysteria2", "Hysteria2")
o:value("tuic", "TUIC")

o = s:option(Value, "port", translate("Listen Port"))
o.datatype = "port"

o = s:option(Flag, "auth", translate("Auth"))
o:depends("protocol", "mixed")
o:depends("protocol", "socks")
o:depends("protocol", "http")

o = s:option(Value, "username", translate("Username"))
o:depends("auth", "1")

o = s:option(Value, "password", translate("Password"))
o.password = true
o:depends("auth", "1")
o:depends("protocol", "shadowsocks")
o:depends("protocol", "tuic")
o:depends("protocol", "hysteria2")

o = s:option(ListValue, "ss_method", translate("Encrypt Method"))
o:value("aes-128-gcm")
o:value("aes-256-gcm")
o:value("chacha20-ietf-poly1305")
o:value("2022-blake3-aes-128-gcm")
o:value("2022-blake3-aes-256-gcm")
o:depends("protocol", "shadowsocks")

o = s:option(DynamicList, "uuid", translate("ID/Password"))
o:depends("protocol", "vmess")
o:depends("protocol", "vless")
o:depends("protocol", "trojan")
o:depends("protocol", "tuic")

o = s:option(ListValue, "flow", translate("Flow"))
o:value("", translate("Disable"))
o:value("xtls-rprx-vision")
o:depends({ protocol = "vless", tls = "1" })

o = s:option(Flag, "tls", translate("TLS"))
o.default = 0
o:depends("protocol", "http")
o:depends("protocol", "vmess")
o:depends("protocol", "vless")
o:depends("protocol", "trojan")

o = s:option(FileUpload, "tls_certificateFile", translate("Public key absolute path"))
o:depends("tls", "1")
o:depends("protocol", "hysteria2")
o:depends("protocol", "tuic")

o = s:option(FileUpload, "tls_keyFile", translate("Private key absolute path"))
o:depends("tls", "1")
o:depends("protocol", "hysteria2")
o:depends("protocol", "tuic")

o = s:option(ListValue, "alpn", translate("ALPN"))
o.default = "default"
o:value("default", translate("Default"))
o:value("h3")
o:value("h2")
o:value("http/1.1")
o:depends("tls", "1")

o = s:option(Flag, "reality", translate("REALITY"))
o.default = 0
o:depends({ protocol = "vless", tls = "1" })

o = s:option(Value, "reality_private_key", translate("Private Key"))
o:depends("reality", "1")

o = s:option(Value, "reality_shortId", translate("Short Id"))
o:depends("reality", "1")

o = s:option(Value, "reality_handshake_server", translate("Handshake Server"))
o.default = "google.com"
o:depends("reality", "1")

o = s:option(ListValue, "transport", translate("Transport"))
o:value("tcp", "TCP")
o:value("http", "HTTP")
o:value("ws", "WebSocket")
o:value("grpc", "gRPC")
o:depends("protocol", "vmess")
o:depends("protocol", "vless")
o:depends("protocol", "trojan")

o = s:option(Value, "ws_path", translate("WebSocket Path"))
o:depends("transport", "ws")

o = s:option(Value, "grpc_serviceName", translate("gRPC ServiceName"))
o:depends("transport", "grpc")

o = s:option(Value, "hysteria2_up_mbps", translate("Max upload Mbps"))
o.default = "100"
o:depends("protocol", "hysteria2")

o = s:option(Value, "hysteria2_down_mbps", translate("Max download Mbps"))
o.default = "100"
o:depends("protocol", "hysteria2")

return m
EOF

# 4. 生成配置转换工具 gen_config.lua
cat << 'EOF' > root/usr/share/singbox_server/gen_config.lua
#!/usr/bin/lua

local uci = require "luci.model.uci".cursor()
local jsonc = require "luci.jsonc"

local section_id = arg[1]
local out_file = arg[2]

if not section_id or not out_file then
    os.exit(1)
end

local node = uci:get_all("singbox_server", section_id)
if not node or node.enable ~= "1" then
    os.exit(0)
end

local function split(str, reps)
    local resultStrList = {}
    string.gsub(str, '[^' .. reps .. ']+', function(w)
        table.insert(resultStrList, w)
    end)
    return resultStrList
end

local tls = {
    enabled = true,
    certificate_path = node.tls_certificateFile,
    key_path = node.tls_keyFile,
    alpn = (node.alpn and node.alpn ~= "default") and split(node.alpn, ',') or nil
}

if node.tls == "1" and node.reality == "1" then
    tls.certificate_path = nil
    tls.key_path = nil
    tls.server_name = node.reality_handshake_server
    tls.reality = {
        enabled = true,
        private_key = node.reality_private_key,
        short_id = { node.reality_shortId },
        handshake = {
            server = node.reality_handshake_server,
            server_port = 443
        }
    }
end

local transport = nil
if node.transport == "ws" then
    transport = { type = "ws", path = node.ws_path or "/" }
elseif node.transport == "grpc" then
    transport = { type = "grpc", service_name = node.grpc_serviceName }
end

local inbound = {
    type = node.protocol,
    tag = "inbound-" .. section_id,
    listen = "::",
    listen_port = tonumber(node.port)
}

local function get_users(is_vless)
    local users = {}
    if node.uuid then
        for _, v in ipairs(type(node.uuid) == "table" and node.uuid or {node.uuid}) do
            if is_vless then
                table.insert(users, { name = v, uuid = v, flow = (node.flow ~= "") and node.flow or nil })
            else
                table.insert(users, { name = v, uuid = v })
            end
        end
    end
    return #users > 0 and users or nil
end

if node.protocol == "shadowsocks" then
    inbound.method = node.ss_method
    inbound.password = node.password
elseif node.protocol == "vless" then
    inbound.users = get_users(true)
    inbound.tls = (node.tls == "1") and tls or nil
    inbound.transport = transport
elseif node.protocol == "vmess" then
    inbound.users = get_users(false)
    inbound.tls = (node.tls == "1") and tls or nil
    inbound.transport = transport
elseif node.protocol == "trojan" then
    local users = {}
    if node.uuid then
        for _, v in ipairs(type(node.uuid) == "table" and node.uuid or {node.uuid}) do
            table.insert(users, { name = v, password = v })
        end
    end
    inbound.users = users
    inbound.tls = (node.tls == "1") and tls or nil
    inbound.transport = transport
elseif node.protocol == "hysteria2" then
    inbound.up_mbps = tonumber(node.hysteria2_up_mbps)
    inbound.down_mbps = tonumber(node.hysteria2_down_mbps)
    inbound.users = {{ name = "user1", password = node.password }}
    inbound.tls = tls
end

local config = {
    log = { level = "info", timestamp = true },
    inbounds = { inbound },
    outbounds = { { type = "direct", tag = "direct" } }
}

local f = io.open(out_file, "w")
if f then
    f:write(jsonc.stringify(config, 1))
    f:close()
end
EOF

# 5. 生成 init.d 启动脚本
cat << 'EOF' > root/etc/init.d/singbox_server
#!/bin/sh /etc/rc.common

USE_PROCD=1
START=99

CONF="singbox_server"
PROG="/usr/bin/sing-box"
JSON_DIR="/var/etc/$CONF"

start_service() {
    config_load "$CONF"
    config_foreach start_instance "server"
}

start_instance() {
    local cfg="$1"
    local enable port
    config_get_bool enable "$cfg" "enable" 0
    [ "$enable" -eq 1 ] || return 1

    config_get port "$cfg" "port"

    mkdir -p "$JSON_DIR"
    local json_file="$JSON_DIR/$cfg.json"

    lua /usr/share/singbox_server/gen_config.lua "$cfg" "$json_file"

    if [ -f "$json_file" ]; then
        procd_open_instance "$CONF-$cfg"
        procd_set_param command "$PROG" run -c "$json_file"
        procd_set_param respawn
        procd_set_param stdout 1
        procd_set_param stderr 1
        procd_close_instance
        
        if [ -n "$port" ]; then
            iptables -I INPUT -p tcp --dport "$port" -m comment --comment "SingBox-Server-$cfg" -j ACCEPT
            iptables -I INPUT -p udp --dport "$port" -m comment --comment "SingBox-Server-$cfg" -j ACCEPT
        fi
    fi
}

stop_service() {
    iptables-save | grep -v "SingBox-Server-" | iptables-restore
    rm -rf "$JSON_DIR"
}

reload_service() {
    stop_service
    start_service
}
EOF

# 6. 生成 UCI 默认配置
cat << 'EOF' > root/etc/config/singbox_server
config server 'default'
    option enable '0'
    option remarks 'My VLESS Reality Server'
    option protocol 'vless'
    option port '443'
    option tls '1'
    option reality '1'
    option flow 'xtls-rprx-vision'
EOF

# 7. 生成基础中文翻译包 (i18n)
cat << 'EOF' > po/zh-cn/singbox_server.po
msgid "Sing-Box Server"
msgstr "Sing-Box 服务端"

msgid "Standalone Sing-Box Server configuration based on Passwall2 logic."
msgstr "基于 Passwall2 逻辑构建的独立 Sing-Box 服务端。"

msgid "Server Instances"
msgstr "服务实例"

msgid "Enable"
msgstr "启用"

msgid "Remarks"
msgstr "备注"

msgid "Protocol"
msgstr "协议"

msgid "Listen Port"
msgstr "监听端口"

msgid "Auth"
msgstr "身份认证"

msgid "Username"
msgstr "用户名"

msgid "Password"
msgstr "密码"

msgid "Encrypt Method"
msgstr "加密方式"

msgid "ID/Password"
msgstr "ID/密码"

msgid "Flow"
msgstr "流控(Flow)"

msgid "Disable"
msgstr "禁用"

msgid "TLS"
msgstr "TLS"

msgid "Public key absolute path"
msgstr "公钥绝对路径"

msgid "Private key absolute path"
msgstr "私钥绝对路径"

msgid "ALPN"
msgstr "ALPN"

msgid "Default"
msgstr "默认"

msgid "REALITY"
msgstr "REALITY"

msgid "Private Key"
msgstr "私钥(Private Key)"

msgid "Short Id"
msgstr "Short Id"

msgid "Handshake Server"
msgstr "握手服务器(SNI)"

msgid "Transport"
msgstr "传输协议"

msgid "WebSocket Path"
msgstr "WebSocket 路径"

msgid "gRPC ServiceName"
msgstr "gRPC ServiceName"

msgid "Max upload Mbps"
msgstr "最大上传 Mbps"

msgid "Max download Mbps"
msgstr "最大下载 Mbps"
EOF

# 8. 赋予脚本执行权限
chmod +x root/usr/share/singbox_server/gen_config.lua
chmod +x root/etc/init.d/singbox_server

echo "=========================================================="
echo "源码打包完成！已在当前目录生成 luci-app-singbox-server 文件夹。"
echo "您可以将其复制到 OpenWrt 源码的 package 目录下进行编译。"
echo "=========================================================="