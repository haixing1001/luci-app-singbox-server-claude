#!/bin/bash

# 创建主目录和子目录
mkdir -p luci-app-singbox-server/{root/etc/config,root/etc/init.d,root/usr/share/singbox_server,luasrc/controller,luasrc/model/cbi/singbox_server,po/zh-cn}

cd luci-app-singbox-server

# 1. 生成 Makefile
cat << 'EOF' > Makefile
include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-singbox-server
PKG_VERSION:=2.0.0
PKG_RELEASE:=0

LUCI_TITLE:=LuCI for Standalone Sing-Box Server (PassWall2 UI Replica)
LUCI_PKGARCH:=all
LUCI_DEPENDS:=+luci-base +luci-compat +luci-lib-jsonc

define Package/$(PKG_NAME)/conffiles
/etc/config/singbox_server
endef

include $(TOPDIR)/feeds/luci/luci.mk
EOF

# 2. 生成 Controller
cat << 'EOF' > luasrc/controller/singbox_server.lua
module("luci.controller.singbox_server", package.seeall)

function index()
    if not nixio.fs.access("/etc/config/singbox_server") then return end
    entry({"admin", "services", "singbox_server"}, cbi("singbox_server/server"), _("Sing-Box Server"), 99).dependent = true
end
EOF

# 3. 100% 复刻 PassWall2 服务端选项界面的 CBI Model
cat << 'EOF' > luasrc/model/cbi/singbox_server/server.lua
local m, s, o
local sys = require "luci.sys"
local fs = require "nixio.fs"
local jsonc = require "luci.jsonc"

local singbox_bin = sys.exec("command -v sing-box"):gsub("\n", "")
if singbox_bin == "" then singbox_bin = "/usr/bin/sing-box" end
local singbox_tags = sys.exec(singbox_bin .. " version | grep 'Tags:' | awk '{print $2}'")

m = Map("singbox_server", translate("Sing-Box Server"), translate("100% Modeled after PassWall2 Sing-Box Server page."))

s = m:section(TypedSection, "server", translate("Server Instances"))
s.anonymous = true
s.addremove = true

o = s:option(Flag, "enable", translate("Enable"))
o.default = 0
o.rmempty = false

o = s:option(Value, "remarks", translate("Remarks"))
o.default = "Sing-Box Node"

o = s:option(Flag, "custom", translate("Use Custom Config"))
o.default = 0
o.rmempty = false

o = s:option(ListValue, "protocol", translate("Protocol"))
o:value("mixed", "Mixed")
o:value("socks", "Socks")
o:value("http", "HTTP")
o:value("shadowsocks", "Shadowsocks")
o:value("vmess", "Vmess")
o:value("vless", "VLESS")
o:value("trojan", "Trojan")
o:value("naive", "Naive")
if singbox_tags:find("with_quic") then
    o:value("hysteria", "Hysteria")
    o:value("tuic", "TUIC")
    o:value("hysteria2", "Hysteria2")
end
o:value("anytls", "AnyTLS")
o:value("direct", "Direct")
o:depends("custom", "0")

o = s:option(Value, "port", translate("Listen Port"))
o.datatype = "port"
o:depends("custom", "0")

o = s:option(Flag, "auth", translate("Auth"))
o.default = 0
o.rmempty = false
o:depends("protocol", "mixed")
o:depends("protocol", "socks")
o:depends("protocol", "http")

o = s:option(Value, "username", translate("Username"))
o:depends("auth", "1")
o:depends("protocol", "naive")
o:depends("protocol", "anytls")

o = s:option(Value, "password", translate("Password"))
o.password = true
o:depends("auth", "1")
o:depends("protocol", "shadowsocks")
o:depends("protocol", "naive")
o:depends("protocol", "tuic")
o:depends("protocol", "anytls")

if singbox_tags:find("with_quic") then
    o = s:option(Value, "hysteria_up_mbps", translate("Max upload Mbps"))
    o.default = "100"
    o:depends("protocol", "hysteria")

    o = s:option(Value, "hysteria_down_mbps", translate("Max download Mbps"))
    o.default = "100"
    o:depends("protocol", "hysteria")

    o = s:option(Value, "hysteria_obfs", translate("Obfs Password"))
    o:depends("protocol", "hysteria")

    o = s:option(ListValue, "hysteria_auth_type", translate("Auth Type"))
    o:value("disable", translate("Disable"))
    o:value("string", translate("STRING"))
    o:value("base64", translate("BASE64"))
    o:depends("protocol", "hysteria")

    o = s:option(Value, "hysteria_auth_password", translate("Auth Password"))
    o.password = true
    o:depends({ protocol = "hysteria", hysteria_auth_type = "string" })
    o:depends({ protocol = "hysteria", hysteria_auth_type = "base64" })

    o = s:option(Value, "hysteria_recv_window_conn", translate("QUIC stream receive window"))
    o:depends("protocol", "hysteria")

    o = s:option(Value, "hysteria_recv_window_client", translate("QUIC connection receive window"))
    o:depends("protocol", "hysteria")

    o = s:option(Value, "hysteria_max_conn_client", translate("QUIC concurrent bidirectional streams"))
    o.default = "1024"
    o:depends("protocol", "hysteria")

    o = s:option(Flag, "hysteria_disable_mtu_discovery", translate("Disable MTU detection"))
    o.default = 0
    o:depends("protocol", "hysteria")

    -- TUIC
    o = s:option(ListValue, "tuic_congestion_control", translate("Congestion control algorithm"))
    o.default = "cubic"
    o:value("bbr", translate("BBR"))
    o:value("cubic", translate("CUBIC"))
    o:value("new_reno", translate("New Reno"))
    o:depends("protocol", "tuic")

    o = s:option(Flag, "tuic_zero_rtt_handshake", translate("Enable 0-RTT QUIC handshake"))
    o.default = 0
    o:depends("protocol", "tuic")

    o = s:option(Value, "tuic_heartbeat", translate("Heartbeat interval(second)"))
    o.datatype = "uinteger"
    o.default = "3"
    o:depends("protocol", "tuic")

    o = s:option(ListValue, "tuic_alpn", translate("QUIC TLS ALPN"))
    o.default = "default"
    o:value("default", translate("Default"))
    o:value("h3")
    o:value("h2")
    o:value("h3,h2")
    o:value("http/1.1")
    o:depends("protocol", "tuic")

    -- Hysteria2
    o = s:option(Flag, "hysteria2_realms", translate("Realms"))
    o.default = "0"
    o.rmempty = false
    o:depends("protocol", "hysteria2")

    o = s:option(Value, "hysteria2_realm_url", translate("Realm URL"))
    o:depends("hysteria2_realms", "1")

    o = s:option(DynamicList, "hysteria2_realm_stun", translate("Realm STUN"))
    o.default = { "stun.sip.us:3478", "stun.nextcloud.com:3478" }
    o:depends("hysteria2_realms", "1")

    o = s:option(Value, "hysteria2_auth_password", translate("Auth Password"))
    o.password = true
    o:depends("protocol", "hysteria2")

    o = s:option(ListValue, "hysteria2_obfs_type", translate("Obfs Type"))
    o:value("", translate("Disable"))
    o:value("salamander")
    o:value("gecko")
    o:depends("protocol", "hysteria2")

    o = s:option(Value, "hysteria2_obfs_password", translate("Obfs Password"))
    o:depends("hysteria2_obfs_type", "salamander")
    o:depends("hysteria2_obfs_type", "gecko")

    o = s:option(Flag, "hysteria2_ignore_client_bandwidth", translate("Client BBR Flow Control"))
    o.default = 0
    o.rmempty = false
    o:depends("protocol", "hysteria2")

    o = s:option(Value, "hysteria2_up_mbps", translate("Max upload Mbps"))
    o:depends({ protocol = "hysteria2", hysteria2_ignore_client_bandwidth = "0" })

    o = s:option(Value, "hysteria2_down_mbps", translate("Max download Mbps"))
    o:depends({ protocol = "hysteria2", hysteria2_ignore_client_bandwidth = "0" })
end

o = s:option(ListValue, "d_protocol", translate("Destination protocol"))
o:value("tcp", "TCP")
o:value("udp", "UDP")
o:value("tcp,udp", "TCP,UDP")
o:depends("protocol", "direct")

o = s:option(Value, "d_address", translate("Destination address"))
o:depends("protocol", "direct")

o = s:option(Value, "d_port", translate("Destination port"))
o.datatype = "port"
o:depends("protocol", "direct")

o = s:option(Value, "decryption", translate("Encrypt Method (VLESS)"))
o.default = "none"
o:depends("protocol", "vless")

o = s:option(ListValue, "ss_method", translate("Encrypt Method"))
o:value("none")
o:value("aes-128-gcm")
o:value("aes-256-gcm")
o:value("chacha20-ietf-poly1305")
o:value("2022-blake3-aes-128-gcm")
o:value("2022-blake3-aes-256-gcm")
o:depends("protocol", "shadowsocks")

o = s:option(DynamicList, "uuid", translate("ID/Password"))
for i = 1, 3 do o:value(sys.exec("echo -n $(cat /proc/sys/kernel/random/uuid)")) end
o:depends("protocol", "vmess")
o:depends("protocol", "vless")
o:depends("protocol", "trojan")
o:depends("protocol", "tuic")

o = s:option(ListValue, "flow", translate("Flow"))
o.default = ""
o:value("", translate("Disable"))
o:value("xtls-rprx-vision")
o:depends({ protocol = "vless", tls = "1" })

o = s:option(Flag, "tls", translate("TLS"))
o.default = 0
o.rmempty = false
o:depends("protocol", "http")
o:depends("protocol", "vmess")
o:depends("protocol", "vless")
o:depends("protocol", "trojan")
o:depends("protocol", "anytls")

if singbox_tags:find("with_utls") then
    o = s:option(Flag, "reality", translate("REALITY"))
    o.default = 0
    o.rmempty = false
    o:depends({ protocol = "http", tls = "1" })
    o:depends({ protocol = "vmess", tls = "1" })
    o:depends({ protocol = "vless", tls = "1" })
    o:depends({ protocol = "trojan", tls = "1" })
    o:depends({ protocol = "anytls", tls = "1" })
    
    o = s:option(Value, "reality_private_key", translate("Private Key"))
    o:depends("reality", "1")
    
    o = s:option(Value, "reality_shortId", translate("Short Id"))
    o:depends("reality", "1")

    o = s:option(Value, "reality_handshake_server", translate("Handshake Server"))
    o.default = "google.com"
    o:depends("reality", "1")

    o = s:option(Value, "reality_handshake_server_port", translate("Handshake Server Port"))
    o.datatype = "port"
    o.default = "443"
    o:depends("reality", "1")
end

o = s:option(ListValue, "alpn", translate("ALPN"))
o.default = "default"
o:value("default", translate("Default"))
o:value("h3")
o:value("h2")
o:value("h3,h2")
o:value("http/1.1")
o:value("h2,http/1.1")
o:value("h3,h2,http/1.1")
o:depends({ tls = "1", reality = "0" })
o:depends("protocol", "hysteria")

o = s:option(FileUpload, "tls_certificateFile", translate("Public key absolute path"))
o:depends({ tls = "1", reality = "0" })
o:depends("protocol", "naive")
o:depends("protocol", "hysteria")
o:depends("protocol", "tuic")
o:depends("protocol", "hysteria2")

o = s:option(FileUpload, "tls_keyFile", translate("Private key absolute path"))
o:depends({ tls = "1", reality = "0" })
o:depends("protocol", "naive")
o:depends("protocol", "hysteria")
o:depends("protocol", "tuic")
o:depends("protocol", "hysteria2")

o = s:option(Flag, "ech", translate("ECH"))
o.default = "0"
o.rmempty = false
o:depends({ tls = "1", flow = "", reality = "0" })
o:depends("protocol", "naive")
o:depends("protocol", "hysteria")
o:depends("protocol", "tuic")
o:depends({ protocol = "hysteria2", hysteria2_realms = "0" })

o = s:option(TextValue, "ech_key", translate("ECH Key"))
o.rows = 5
o.wrap = "off"
o:depends("ech", "1")

o = s:option(ListValue, "transport", translate("Transport"))
o:value("tcp", "TCP")
o:value("http", "HTTP")
o:value("ws", "WebSocket")
o:value("httpupgrade", "HTTPUpgrade")
o:value("quic", "QUIC")
o:value("grpc", "gRPC")
o:depends("protocol", "shadowsocks")
o:depends("protocol", "vmess")
o:depends("protocol", "vless")
o:depends("protocol", "trojan")

o = s:option(DynamicList, "http_host", translate("HTTP Host"))
o:depends("transport", "http")

o = s:option(Value, "http_path", translate("HTTP Path"))
o:depends("transport", "http")

o = s:option(Value, "ws_host", translate("WebSocket Host"))
o:depends("transport", "ws")

o = s:option(Value, "ws_path", translate("WebSocket Path"))
o:depends("transport", "ws")

o = s:option(Value, "httpupgrade_host", translate("HTTPUpgrade Host"))
o:depends("transport", "httpupgrade")

o = s:option(Value, "httpupgrade_path", translate("HTTPUpgrade Path"))
o:depends("transport", "httpupgrade")

o = s:option(Value, "grpc_serviceName", translate("gRPC ServiceName"))
o:depends("transport", "grpc")

o = s:option(Flag, "mux", translate("Mux"))
o.default = 0
o.rmempty = false
o:depends("protocol", "vmess")
o:depends({ protocol = "vless", flow = "" })
o:depends("protocol", "shadowsocks")
o:depends("protocol", "trojan")

o = s:option(Flag, "tcpbrutal", translate("TCP Brutal"))
o.default = 0
o.rmempty = false
o:depends("mux", "1")

o = s:option(Value, "tcpbrutal_up_mbps", translate("Max upload Mbps"))
o.default = "10"
o:depends("tcpbrutal", "1")

o = s:option(Value, "tcpbrutal_down_mbps", translate("Max download Mbps"))
o.default = "50"
o:depends("tcpbrutal", "1")

o = s:option(Flag, "bind_local", translate("Bind Local"))
o.default = 0
o.rmempty = false
o:depends("custom", "0")

o = s:option(Flag, "accept_lan", translate("Accept LAN Access"))
o.default = 0
o.rmempty = false
o:depends("custom", "0")

o = s:option(ListValue, "outbound_node_iface", translate("Bind Interface"))
o:value("", translate("Disable"))
for dev in sys.exec("ls /sys/class/net/"):gmatch("[%w%_%.%-]+") do
    if dev ~= "lo" then o:value(dev, dev) end
end
o:depends("custom", "0")

o = s:option(TextValue, "custom_config", translate("Custom Config (JSON)"))
o.rows = 15
o.wrap = "off"
o:depends("custom", "1")

o = s:option(Flag, "log", translate("Log"))
o.default = 1
o.rmempty = false

o = s:option(ListValue, "loglevel", translate("Log Level"))
o.default = "info"
o:value("debug")
o:value("info")
o:value("warn")
o:value("error")
o:depends("log", "1")

return m
EOF

# 4. 100% 复刻 PassWall2 JSON 构造逻辑
cat << 'EOF' > root/usr/share/singbox_server/gen_config.lua
#!/usr/bin/lua

local uci = require "luci.model.uci".cursor()
local jsonc = require "luci.jsonc"
local sys = require "luci.sys"

local section_id = arg[1]
local out_file = arg[2]
if not section_id or not out_file then os.exit(1) end

local node = uci:get_all("singbox_server", section_id)
if not node or node.enable ~= "1" then os.exit(0) end

if node.custom == "1" and node.custom_config then
    local custom_cfg = jsonc.parse(node.custom_config)
    if custom_cfg then
        local f = io.open(out_file, "w")
        f:write(jsonc.stringify(custom_cfg, 1))
        f:close()
        os.exit(0)
    end
end

local outbounds = { { type = "direct", tag = "direct" } }

local tls = {
    enabled = true,
    certificate_path = node.tls_certificateFile,
    key_path = node.tls_keyFile,
    alpn = (node.alpn and node.alpn ~= "default") and (function()
        local alpn = {}
        string.gsub(node.alpn, '[^,]+', function(w) table.insert(alpn, w) end)
        return #alpn > 0 and alpn or nil
    end)() or nil
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
            server_port = tonumber(node.reality_handshake_server_port) or 443
        }
    }
end

if node.tls == "1" and node.ech == "1" then
    tls.ech = {
        enabled = true,
        key = node.ech_key and { node.ech_key } or nil
    }
end

local mux = nil
if node.mux == "1" then
    mux = {
        enabled = true,
        padding = false,
        brutal = {
            enabled = (node.tcpbrutal == "1"),
            up_mbps = tonumber(node.tcpbrutal_up_mbps) or 10,
            down_mbps = tonumber(node.tcpbrutal_down_mbps) or 50,
        },
    }
end

local v2ray_transport = nil
if node.transport == "http" then
    v2ray_transport = { type = "http", host = node.http_host or {}, path = node.http_path or "/" }
elseif node.transport == "ws" then
    v2ray_transport = { type = "ws", path = node.ws_path or "/", headers = node.ws_host and { Host = node.ws_host } or nil }
elseif node.transport == "httpupgrade" then
    v2ray_transport = { type = "httpupgrade", host = node.httpupgrade_host, path = node.httpupgrade_path or "/" }
elseif node.transport == "quic" then
    v2ray_transport = { type = "quic" }
elseif node.transport == "grpc" then
    v2ray_transport = { type = "grpc", service_name = node.grpc_serviceName }
end

local inbound = {
    type = node.protocol,
    tag = "inbound",
    listen = (node.bind_local == "1") and "127.0.0.1" or "::",
    listen_port = tonumber(node.port),
}

if node.protocol == "mixed" then
    inbound.users = (node.auth == "1") and { { username = node.username, password = node.password } } or nil
    inbound.set_system_proxy = false
elseif node.protocol == "socks" then
    inbound.users = (node.auth == "1") and { { username = node.username, password = node.password } } or nil
elseif node.protocol == "http" then
    inbound.users = (node.auth == "1") and { { username = node.username, password = node.password } } or nil
    inbound.tls = (node.tls == "1") and tls or nil
elseif node.protocol == "shadowsocks" then
    inbound.method = node.ss_method
    inbound.password = node.password
    inbound.multiplex = mux
elseif node.protocol == "vmess" or node.protocol == "vless" or node.protocol == "trojan" then
    if node.uuid then
        local users = {}
        for _, v in ipairs(type(node.uuid) == "table" and node.uuid or {node.uuid}) do
            if node.protocol == "vmess" then
                table.insert(users, { name = v, uuid = v, alterId = 0 })
            elseif node.protocol == "vless" then
                table.insert(users, { name = v, uuid = v, flow = (node.flow and node.flow ~= "") and node.flow or nil })
            else
                table.insert(users, { name = v, password = v })
            end
        end
        inbound.users = users
        inbound.tls = (node.tls == "1") and tls or nil
        inbound.multiplex = mux
        inbound.transport = v2ray_transport
    end
elseif node.protocol == "naive" then
    inbound.users = { { username = node.username, password = node.password } }
    inbound.tls = tls
elseif node.protocol == "hysteria" then
    inbound.up_mbps = tonumber(node.hysteria_up_mbps)
    inbound.down_mbps = tonumber(node.hysteria_down_mbps)
    inbound.obfs = node.hysteria_obfs
    inbound.users = { { name = "user1", auth = (node.hysteria_auth_type == "base64") and node.hysteria_auth_password or nil, auth_str = (node.hysteria_auth_type == "string") and node.hysteria_auth_password or nil } }
    inbound.recv_window_conn = tonumber(node.hysteria_recv_window_conn)
    inbound.recv_window_client = tonumber(node.hysteria_recv_window_client)
    inbound.max_conn_client = tonumber(node.hysteria_max_conn_client)
    inbound.disable_mtu_discovery = (node.hysteria_disable_mtu_discovery == "1")
    inbound.tls = tls
elseif node.protocol == "tuic" then
    tls.alpn = (node.tuic_alpn and node.tuic_alpn ~= "default") and (function()
        local alpn = {}
        string.gsub(node.tuic_alpn, '[^,]+', function(w) table.insert(alpn, w) end)
        return #alpn > 0 and alpn or nil
    end)() or nil
    inbound.users = { { name = "user1", uuid = type(node.uuid) == "table" and node.uuid[1] or node.uuid, password = node.password } }
    inbound.congestion_control = node.tuic_congestion_control or "cubic"
    inbound.zero_rtt_handshake = (node.tuic_zero_rtt_handshake == "1")
    inbound.heartbeat = (tonumber(node.tuic_heartbeat) or 3) .. "s"
    inbound.tls = tls
elseif node.protocol == "hysteria2" then
    inbound.up_mbps = (node.hysteria2_ignore_client_bandwidth ~= "1") and tonumber(node.hysteria2_up_mbps) or nil
    inbound.down_mbps = (node.hysteria2_ignore_client_bandwidth ~= "1") and tonumber(node.hysteria2_down_mbps) or nil
    inbound.obfs = (node.hysteria2_obfs_type and node.hysteria2_obfs_type ~= "") and { type = node.hysteria2_obfs_type, password = node.hysteria2_obfs_password } or nil
    inbound.users = { { name = "user1", password = node.hysteria2_auth_password } }
    inbound.ignore_client_bandwidth = (node.hysteria2_ignore_client_bandwidth == "1")
    inbound.tls = tls
    if node.hysteria2_realms == "1" then
        inbound.realm = {
            server_url = node.hysteria2_realm_url and "https://" .. node.hysteria2_realm_url or nil,
            stun_servers = type(node.hysteria2_realm_stun) == "table" and node.hysteria2_realm_stun or {node.hysteria2_realm_stun},
            stun_domain_resolver = "direct"
        }
    end
elseif node.protocol == "anytls" then
    inbound.users = { { name = (node.username and node.username ~= "") and node.username or "sekai", password = node.password } }
    inbound.tls = tls
elseif node.protocol == "direct" then
    inbound.network = (node.d_protocol ~= "TCP,UDP") and node.d_protocol or nil
    inbound.override_address = node.d_address
    inbound.override_port = tonumber(node.d_port)
end

local route = {
    rules = {
        { ip_is_private = true, action = (node.accept_lan == "1") and "route" or "reject", outbound = (node.accept_lan == "1") and "direct" or nil }
    }
}

if node.outbound_node_iface and node.outbound_node_iface ~= "" then
    local outbound = { type = "direct", tag = "outbound", bind_interface = node.outbound_node_iface, routing_mark = 255 }
    route.final = outbound.tag
    table.insert(outbounds, 1, outbound)
end

local config = {
    log = { disabled = (node.log == "0"), level = node.loglevel or "info", timestamp = true },
    dns = { servers = { { type = "local", tag = "local" } } },
    inbounds = { inbound },
    outbounds = outbounds,
    route = route
}

local f = io.open(out_file, "w")
if f then
    f:write(jsonc.stringify(config, 1))
    f:close()
end
EOF

# 5. 生成系统初始化脚本 init.d
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
    local enable port protocol
    config_get_bool enable "$cfg" "enable" 0
    [ "$enable" -eq 1 ] || return 1

    config_get port "$cfg" "port"
    config_get protocol "$cfg" "protocol"

    mkdir -p "$JSON_DIR"
    local json_file="$JSON_DIR/$cfg.json"

    # 生成配置文件
    lua /usr/share/singbox_server/gen_config.lua "$cfg" "$json_file"

    if [ -f "$json_file" ]; then
        procd_open_instance "$CONF-$cfg"
        procd_set_param command "$PROG" run -c "$json_file"
        procd_set_param respawn
        procd_set_param stdout 1
        procd_set_param stderr 1
        procd_close_instance
        
        # 服务端所需：自动放行入站防火墙端口
        if [ -n "$port" ]; then
            iptables -I INPUT -p tcp --dport "$port" -m comment --comment "SingBox-Server-$cfg" -j ACCEPT
            ip6tables -I INPUT -p tcp --dport "$port" -m comment --comment "SingBox-Server-$cfg" -j ACCEPT
            iptables -I INPUT -p udp --dport "$port" -m comment --comment "SingBox-Server-$cfg" -j ACCEPT
            ip6tables -I INPUT -p udp --dport "$port" -m comment --comment "SingBox-Server-$cfg" -j ACCEPT
        fi
    fi
}

stop_service() {
    # 清理所有服务端防火墙规则
    iptables-save | grep -v "SingBox-Server-" | iptables-restore
    ip6tables-save | grep -v "SingBox-Server-" | ip6tables-restore
    rm -rf "$JSON_DIR"
}

reload_service() {
    stop_service
    start_service
}
EOF

# 6. 生成完善的中文化 PO 语言包 (覆盖所有的 PassWall2 原版名称)
cat << 'EOF' > po/zh-cn/singbox_server.po
msgid "Sing-Box Server"
msgstr "Sing-Box 服务端"

msgid "100% Modeled after PassWall2 Sing-Box Server page."
msgstr "100% 仿照 PassWall2 Sing-Box 服务端页面构建。"

msgid "Server Instances"
msgstr "服务节点列表"

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
msgstr "公钥证书 (PEM) 绝对路径"

msgid "Private key absolute path"
msgstr "私钥 (Key) 绝对路径"

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

msgid "HTTPUpgrade Path"
msgstr "HTTPUpgrade 路径"

msgid "gRPC ServiceName"
msgstr "gRPC ServiceName"

msgid "Max upload Mbps"
msgstr "最大上传 Mbps"

msgid "Max download Mbps"
msgstr "最大下载 Mbps"

msgid "Mux"
msgstr "Mux 多路复用"

msgid "TCP Brutal"
msgstr "TCP Brutal 拥塞控制"

msgid "ECH"
msgstr "ECH (加密客户问候)"

msgid "Client BBR Flow Control"
msgstr "客户端 BBR 流控"

msgid "Realms"
msgstr "Realms 端口跳跃"

msgid "QUIC stream receive window"
msgstr "QUIC 流接收窗口"

msgid "QUIC connection receive window"
msgstr "QUIC 连接接收窗口"

msgid "QUIC concurrent bidirectional streams"
msgstr "QUIC 并发双向流最大数量"

msgid "Disable MTU detection"
msgstr "禁用 MTU 探测"

msgid "Use Custom Config"
msgstr "使用自定义配置"

msgid "Bind Interface"
msgstr "绑定出口网卡"

msgid "Bind Local"
msgstr "本机监听"

msgid "Accept LAN Access"
msgstr "接受局域网访问"
EOF

# 7. 生成 UCI 默认配置模板
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

# 8. 赋予所有脚本可执行权限
chmod +x root/usr/share/singbox_server/gen_config.lua
chmod +x root/etc/init.d/singbox_server

echo "=========================================================="
echo "完美复刻 PassWall2 服务端选项版的源码生成完毕！"
echo "已在当前目录生成 luci-app-singbox-server 文件夹。"
echo "复制到 OpenWrt 源码的 package 目录下即可编译。"
echo "=========================================================="