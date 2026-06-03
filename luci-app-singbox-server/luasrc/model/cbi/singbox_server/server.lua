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
