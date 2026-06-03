#!/usr/bin/lua

local uci = require "luci.model.uci".cursor()
local jsonc = require "luci.jsonc"

local section = arg[1]
if not section then os.exit(1) end

local function get(opt, default)
	local v = uci:get("singbox_server", section, opt)
	if v == nil or v == "" then return default end
	return v
end

local function get_bool(opt, default)
	local v = uci:get("singbox_server", section, opt)
	if v == nil then return default end
	return v == "1" or v == "true"
end

local function num(opt, default)
	return tonumber(get(opt, tostring(default))) or default
end

local protocol = get("protocol", "vless")
local transport = get("transport", "tcp")
local loglevel = uci:get("singbox_server", "global", "loglevel") or "info"

local inbound = {
	type = protocol,
	tag = "in-" .. section,
	listen = get("listen", "::"),
	listen_port = num("port", 443),
	sniff = get_bool("sniff", true)
}

if protocol == "vless" then
	local user = { uuid = get("uuid", "") }
	local flow = get("flow", "")
	if flow ~= "" then user.flow = flow end
	inbound.users = { user }
elseif protocol == "vmess" then
	inbound.users = { { uuid = get("uuid", "") } }
elseif protocol == "trojan" then
	inbound.users = { { password = get("password", get("uuid", "")) } }
elseif protocol == "shadowsocks" then
	inbound.method = get("method", "2022-blake3-aes-128-gcm")
	inbound.password = get("password", get("uuid", ""))
elseif protocol == "hysteria2" then
	inbound.users = { { password = get("password", get("uuid", "")) } }
else
	inbound.users = { { uuid = get("uuid", "") } }
end

if transport ~= "tcp" then
	inbound.transport = { type = transport }
	if transport == "ws" then
		inbound.transport.path = get("ws_path", "/")
	elseif transport == "grpc" then
		inbound.transport.service_name = get("grpc_service_name", "singbox")
	elseif transport == "http" then
		inbound.transport.host = { get("http_host", "") }
		inbound.transport.path = get("http_path", "/")
	end
end

if get_bool("tls", false) then
	inbound.tls = {
		enabled = true,
		server_name = get("server_name", "")
	}
	local cert = get("cert_file", "")
	local key = get("key_file", "")
	if cert ~= "" then inbound.tls.certificate_path = cert end
	if key ~= "" then inbound.tls.key_path = key end

	if get_bool("reality", false) then
		inbound.tls.reality = {
			enabled = true,
			handshake = {
				server = get("reality_dest", "www.cloudflare.com"),
				server_port = num("reality_dest_port", 443)
			},
			private_key = get("reality_private_key", ""),
			short_id = { get("reality_short_id", "") }
		}
	end
end

local config = {
	log = { level = loglevel, timestamp = true },
	inbounds = { inbound },
	outbounds = { { type = "direct", tag = "direct" } }
}

print(jsonc.stringify(config, true))
