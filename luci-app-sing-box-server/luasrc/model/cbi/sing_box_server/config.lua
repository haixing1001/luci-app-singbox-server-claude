local app_name = "sing_box_server"
local d = require "luci.dispatcher"

map = Map(app_name, "sing-box " .. translate("Server Config"))
map.redirect = d.build_url("admin", "vpn", app_name)

t = map:section(NamedSection, arg[1], "user", "")
t.addremove = false
t.dynamic   = false

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- Basic settings
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
enable = t:option(Flag, "enable", translate("Enable"))
enable.default  = "1"
enable.rmempty  = false

remarks = t:option(Value, "remarks", translate("Remarks"))
remarks.default = translate("Remarks")
remarks.rmempty = false

bind_local = t:option(Flag, "bind_local", translate("Bind Local"),
	translate("When selected, only local connections are accepted. Recommended when used behind a reverse proxy."))
bind_local.default = "0"
bind_local.rmempty = false

port = t:option(Value, "port", translate("Port"))
port.datatype = "port"
port.rmempty  = false

protocol = t:option(ListValue, "protocol", translate("Protocol"))
protocol:value("vmess",       "VMess")
protocol:value("vless",       "VLESS")
protocol:value("shadowsocks", "Shadowsocks")
protocol:value("trojan",      "Trojan")
protocol:value("hysteria2",   "Hysteria2")
protocol:value("tuic",        "TUIC v5")
protocol:value("socks",       translate("SOCKS5"))
protocol:value("http",        translate("HTTP"))

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- VMess
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
vmess_uuid = t:option(DynamicList, "vmess_uuid", translate("UUID"),
	translate("Add one or more UUIDs for multi-user support."))
for _ = 1, 3 do
	vmess_uuid:value(luci.sys.exec("cat /proc/sys/kernel/random/uuid"):match("^(.-)%s*$"))
end
vmess_uuid:depends("protocol", "vmess")

vmess_alter_id = t:option(Value, "vmess_alter_id", translate("Alter ID"),
	translate("Keep at 0 for AEAD encryption (recommended)."))
vmess_alter_id.default  = "0"
vmess_alter_id.datatype = "uinteger"
vmess_alter_id:depends("protocol", "vmess")

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- VLESS
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
vless_uuid = t:option(DynamicList, "vless_uuid", translate("UUID"))
for _ = 1, 3 do
	vless_uuid:value(luci.sys.exec("cat /proc/sys/kernel/random/uuid"):match("^(.-)%s*$"))
end
vless_uuid:depends("protocol", "vless")

vless_flow = t:option(ListValue, "vless_flow", translate("Flow"))
vless_flow:value("",                  translate("None"))
vless_flow:value("xtls-rprx-vision",  "XTLS Vision")
vless_flow:depends("protocol", "vless")

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- Shadowsocks
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
ss_method = t:option(ListValue, "ss_method", translate("Encrypt Method"))
ss_method:value("aes-128-gcm",                    "AES-128-GCM")
ss_method:value("aes-256-gcm",                    "AES-256-GCM")
ss_method:value("chacha20-ietf-poly1305",          "ChaCha20-IETF-Poly1305")
ss_method:value("2022-blake3-aes-128-gcm",         "2022-Blake3-AES-128-GCM")
ss_method:value("2022-blake3-aes-256-gcm",         "2022-Blake3-AES-256-GCM")
ss_method:value("2022-blake3-chacha20-poly1305",   "2022-Blake3-ChaCha20-Poly1305")
ss_method:depends("protocol", "shadowsocks")

ss_password = t:option(Value, "ss_password", translate("Password"))
ss_password.password = true
ss_password:depends("protocol", "shadowsocks")

ss_network = t:option(ListValue, "ss_network", translate("Network"))
ss_network.default = "tcp,udp"
ss_network:value("tcp",     "TCP")
ss_network:value("udp",     "UDP")
ss_network:value("tcp,udp", "TCP + UDP")
ss_network:depends("protocol", "shadowsocks")

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- Trojan
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
trojan_password = t:option(DynamicList, "trojan_password", translate("Password"),
	translate("One password per user."))
trojan_password:depends("protocol", "trojan")

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- Hysteria2
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
hysteria2_password = t:option(DynamicList, "hysteria2_password", translate("Password"),
	translate("One password per user. Hysteria2 always requires TLS."))
hysteria2_password:depends("protocol", "hysteria2")

hysteria2_obfs = t:option(Value, "hysteria2_obfs",
	translate("Obfs Password"),
	translate("Optional Salamander obfuscation password."))
hysteria2_obfs.rmempty = true
hysteria2_obfs:depends("protocol", "hysteria2")

hysteria2_up_mbps = t:option(Value, "hysteria2_up_mbps",
	translate("Upload Bandwidth (Mbps)"),
	translate("Server-side upload limit. Leave empty for unlimited."))
hysteria2_up_mbps.datatype = "uinteger"
hysteria2_up_mbps.rmempty  = true
hysteria2_up_mbps:depends("protocol", "hysteria2")

hysteria2_down_mbps = t:option(Value, "hysteria2_down_mbps",
	translate("Download Bandwidth (Mbps)"),
	translate("Server-side download limit. Leave empty for unlimited."))
hysteria2_down_mbps.datatype = "uinteger"
hysteria2_down_mbps.rmempty  = true
hysteria2_down_mbps:depends("protocol", "hysteria2")

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- TUIC v5
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
tuic_uuid = t:option(DynamicList, "tuic_uuid", translate("UUID"),
	translate("Each UUID must be paired with a password at the same position."))
for _ = 1, 2 do
	tuic_uuid:value(luci.sys.exec("cat /proc/sys/kernel/random/uuid"):match("^(.-)%s*$"))
end
tuic_uuid:depends("protocol", "tuic")

tuic_password = t:option(DynamicList, "tuic_password", translate("Password (per UUID)"),
	translate("Must correspond to the UUID list above. TUIC always requires TLS."))
tuic_password:depends("protocol", "tuic")

tuic_congestion = t:option(ListValue, "tuic_congestion", translate("Congestion Control"))
tuic_congestion.default = "bbr"
tuic_congestion:value("bbr",      "BBR")
tuic_congestion:value("cubic",    "CUBIC")
tuic_congestion:value("new_reno", "New Reno")
tuic_congestion:depends("protocol", "tuic")

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- SOCKS5
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
socks_username = t:option(Value, "socks_username", translate("Username"),
	translate("Leave empty for no authentication."))
socks_username.rmempty = true
socks_username:depends("protocol", "socks")

socks_password = t:option(Value, "socks_password", translate("Password"))
socks_password.password = true
socks_password.rmempty  = true
socks_password:depends("protocol", "socks")

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- HTTP
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
http_username = t:option(Value, "http_username", translate("Username"),
	translate("Leave empty for no authentication."))
http_username.rmempty = true
http_username:depends("protocol", "http")

http_password = t:option(Value, "http_password", translate("Password"))
http_password.password = true
http_password.rmempty  = true
http_password:depends("protocol", "http")

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- Transport layer (VMess / VLESS / Trojan)
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
transport = t:option(ListValue, "transport", translate("Transport"))
transport.default = "tcp"
transport:value("tcp",         "TCP")
transport:value("ws",          "WebSocket")
transport:value("http",        "HTTP/2")
transport:value("grpc",        "gRPC")
transport:value("httpupgrade", "HTTP Upgrade")
transport:depends("protocol", "vmess")
transport:depends("protocol", "vless")
transport:depends("protocol", "trojan")

-- WebSocket
ws_path = t:option(Value, "ws_path", translate("WebSocket Path"))
ws_path.default = "/"
ws_path.rmempty = true
ws_path:depends("transport", "ws")

ws_host = t:option(Value, "ws_host", translate("WebSocket Host"),
	translate("Overrides the Host header. Leave empty to use the client value."))
ws_host.rmempty = true
ws_host:depends("transport", "ws")

-- HTTP/2
h2_path = t:option(Value, "h2_path", translate("HTTP/2 Path"))
h2_path.default = "/"
h2_path.rmempty = true
h2_path:depends("transport", "http")

h2_host = t:option(Value, "h2_host", translate("HTTP/2 Host"))
h2_host.rmempty = true
h2_host:depends("transport", "http")

-- gRPC
grpc_service = t:option(Value, "grpc_service", translate("gRPC Service Name"))
grpc_service.rmempty = true
grpc_service:depends("transport", "grpc")

-- HTTP Upgrade
httpupgrade_path = t:option(Value, "httpupgrade_path", translate("HTTP Upgrade Path"))
httpupgrade_path.default = "/"
httpupgrade_path.rmempty = true
httpupgrade_path:depends("transport", "httpupgrade")

httpupgrade_host = t:option(Value, "httpupgrade_host", translate("HTTP Upgrade Host"))
httpupgrade_host.rmempty = true
httpupgrade_host:depends("transport", "httpupgrade")

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- TLS (VMess / VLESS / Trojan toggle; Hysteria2 / TUIC always on)
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
tls_enable = t:option(Flag, "tls_enable", translate("Enable TLS"))
tls_enable.default = "0"
tls_enable.rmempty = false
tls_enable:depends("protocol", "vmess")
tls_enable:depends("protocol", "vless")
tls_enable:depends("protocol", "trojan")

tls_cert_file = t:option(Value, "tls_cert_file",
	translate("Certificate File"),
	translate("as:") .. " /etc/ssl/fullchain.pem")
tls_cert_file.rmempty = true
-- Show for vmess/vless/trojan when TLS enabled
tls_cert_file:depends({protocol = "vmess",  tls_enable = "1"})
tls_cert_file:depends({protocol = "vless",  tls_enable = "1"})
tls_cert_file:depends({protocol = "trojan", tls_enable = "1"})
-- Always show for protocols that require TLS
tls_cert_file:depends("protocol", "hysteria2")
tls_cert_file:depends("protocol", "tuic")

tls_key_file = t:option(Value, "tls_key_file",
	translate("Key File"),
	translate("as:") .. " /etc/ssl/private.key")
tls_key_file.rmempty = true
tls_key_file:depends({protocol = "vmess",  tls_enable = "1"})
tls_key_file:depends({protocol = "vless",  tls_enable = "1"})
tls_key_file:depends({protocol = "trojan", tls_enable = "1"})
tls_key_file:depends("protocol", "hysteria2")
tls_key_file:depends("protocol", "tuic")

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- REALITY (VLESS only)
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
reality_enable = t:option(Flag, "reality_enable",
	translate("Enable REALITY"),
	translate("REALITY replaces TLS. When enabled the certificate/key above are ignored."))
reality_enable.default = "0"
reality_enable.rmempty = false
reality_enable:depends("protocol", "vless")

reality_server = t:option(Value, "reality_server",
	translate("Handshake Server"),
	translate("A real TLS 1.3 server that your server will masquerade as."))
reality_server.default = "www.microsoft.com"
reality_server:depends("reality_enable", "1")

reality_server_port = t:option(Value, "reality_server_port",
	translate("Handshake Port"))
reality_server_port.datatype = "port"
reality_server_port.default  = "443"
reality_server_port:depends("reality_enable", "1")

reality_private_key = t:option(Value, "reality_private_key",
	translate("Private Key (X25519)"),
	translate("Generate with: sing-box generate reality-keypair"))
reality_private_key.password = true
reality_private_key.rmempty  = true
reality_private_key:depends("reality_enable", "1")

reality_public_key = t:option(Value, "reality_public_key",
	translate("Public Key (X25519)"),
	translate("Share this with clients."))
reality_public_key.rmempty = true
reality_public_key:depends("reality_enable", "1")

reality_short_id = t:option(Value, "reality_short_id",
	translate("Short ID"),
	translate("Hex string up to 8 bytes (0-16 hex chars). e.g. 1234abcd"))
reality_short_id.rmempty = true
reality_short_id:depends("reality_enable", "1")

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- Misc
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
accept_lan = t:option(Flag, "accept_lan",
	translate("Accept LAN Access"),
	translate("When selected, clients on the LAN can route through this server. Use with caution."))
accept_lan.default = "0"
accept_lan.rmempty = false

return map
