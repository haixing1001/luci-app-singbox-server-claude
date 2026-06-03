local appname = "singbox_server"
local sid = arg[1]

m = Map(appname, translate("Server Config"))
m.redirect = luci.dispatcher.build_url("admin", "services", appname, "server")

if not sid or not m:get(sid) then
	luci.http.redirect(m.redirect)
end

local header = Template(appname .. "/server/config_header")
header.config = m.config
header.section = sid
m:append(header)

s = m:section(NamedSection, sid, "user", "")
s.addremove = false
s.dynamic = false
s.val = m:get(sid) or {}

o = s:option(Flag, "enable", translate("Enable"))
o.default = "1"
o.rmempty = false

o = s:option(Value, "remarks", translate("Remarks"))
o.default = translate("Remarks")
o.rmempty = false

o = s:option(ListValue, "type", translate("Type"))
o:value("sing-box", "Sing-Box")
o.default = "sing-box"
o.rmempty = false

o = s:option(ListValue, "protocol", translate("Protocol"))
o:value("vless", "VLESS")
o:value("vmess", "VMess")
o:value("trojan", "Trojan")
o:value("shadowsocks", "Shadowsocks")
o:value("hysteria2", "Hysteria2")
o.default = "vless"
o.rmempty = false

o = s:option(Value, "listen", translate("Listen Address"))
o.default = "::"
o.rmempty = false

o = s:option(Value, "port", translate("Port"))
o.datatype = "port"
o.default = "443"
o.rmempty = false

o = s:option(Value, "uuid", translate("UUID"))
o.placeholder = "11111111-1111-1111-1111-111111111111"
o:depends("protocol", "vless")
o:depends("protocol", "vmess")

o = s:option(Value, "password", translate("Password"))
o.password = true
o:depends("protocol", "trojan")
o:depends("protocol", "shadowsocks")
o:depends("protocol", "hysteria2")

o = s:option(Value, "flow", translate("Flow"))
o.placeholder = "xtls-rprx-vision"
o:depends("protocol", "vless")

o = s:option(ListValue, "method", translate("Encrypt Method"))
o:value("2022-blake3-aes-128-gcm")
o:value("2022-blake3-aes-256-gcm")
o:value("aes-128-gcm")
o:value("aes-256-gcm")
o:value("chacha20-ietf-poly1305")
o.default = "2022-blake3-aes-128-gcm"
o:depends("protocol", "shadowsocks")

o = s:option(ListValue, "transport", translate("Transport"))
o:value("tcp", "TCP")
o:value("ws", "WebSocket")
o:value("grpc", "gRPC")
o:value("http", "HTTP")
o.default = "tcp"
o.rmempty = false

o = s:option(Value, "ws_path", translate("WebSocket Path"))
o.default = "/"
o:depends("transport", "ws")

o = s:option(Value, "grpc_service_name", translate("gRPC Service Name"))
o.default = "singbox"
o:depends("transport", "grpc")

o = s:option(Value, "http_host", translate("HTTP Host"))
o:depends("transport", "http")

o = s:option(Value, "http_path", translate("HTTP Path"))
o.default = "/"
o:depends("transport", "http")

o = s:option(Flag, "tls", translate("TLS"))
o.rmempty = false

o = s:option(Value, "server_name", translate("Server Name"))
o:depends("tls", "1")

o = s:option(Value, "cert_file", translate("Certificate Path"))
o.placeholder = "/etc/ssl/fullchain.pem"
o:depends("tls", "1")

o = s:option(Value, "key_file", translate("Private Key Path"))
o.placeholder = "/etc/ssl/private.key"
o.password = true
o:depends("tls", "1")

o = s:option(Flag, "reality", translate("Reality"))
o.rmempty = false
o:depends("tls", "1")
o:depends("protocol", "vless")

o = s:option(Value, "reality_dest", translate("Reality Dest"))
o.default = "www.cloudflare.com"
o:depends("reality", "1")

o = s:option(Value, "reality_dest_port", translate("Reality Dest Port"))
o.datatype = "port"
o.default = "443"
o:depends("reality", "1")

o = s:option(Value, "reality_private_key", translate("Reality Private Key"))
o.password = true
o:depends("reality", "1")

o = s:option(Value, "reality_short_id", translate("Reality Short ID"))
o:depends("reality", "1")

o = s:option(Flag, "sniff", translate("Sniff"))
o.default = "1"
o.rmempty = false

o = s:option(Flag, "log", translate("Log"))
o.default = "1"
o.rmempty = false

local footer = Template(appname .. "/server/config_footer")
footer.config = m.config
footer.section = sid
m:append(footer)

return m
