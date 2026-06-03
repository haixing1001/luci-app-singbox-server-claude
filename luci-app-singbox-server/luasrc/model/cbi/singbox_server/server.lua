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
