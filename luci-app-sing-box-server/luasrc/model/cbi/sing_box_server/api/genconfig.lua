#!/usr/bin/env lua
-- genconfig.lua  –  Generate a sing-box inbound JSON for one UCI user section.
-- Usage: lua genconfig.lua <section_id>
-- Prints the JSON to stdout; called by the init.d script.

local ucursor      = require "luci.model.uci".cursor()
local json         = require "luci.jsonc"
local section_id   = arg[1]

if not section_id or section_id == "" then
	io.stderr:write("Usage: genconfig.lua <uci_section_id>\n")
	os.exit(1)
end

local s = ucursor:get_all("sing_box_server", section_id)
if not s then
	io.stderr:write("Section not found: " .. section_id .. "\n")
	os.exit(1)
end

-- ── Helpers ──────────────────────────────────────────────────────────────────

local function trim(str)
	return str and str:match("^%s*(.-)%s*$") or ""
end

--- Normalise a UCI list-or-string to a plain Lua array.
local function to_list(val)
	if val == nil then return {} end
	if type(val) == "table" then return val end
	return {val}
end

--- Build the transport object (returns nil for plain TCP).
local function build_transport(s)
	local t = s.transport or "tcp"
	if t == "tcp" then return nil end

	if t == "ws" then
		local cfg = {type = "ws"}
		local path = trim(s.ws_path)
		if path ~= "" then cfg.path = path end
		local host = trim(s.ws_host)
		if host ~= "" then cfg.headers = {Host = host} end
		return cfg

	elseif t == "http" then
		local cfg = {type = "http"}
		local path = trim(s.h2_path)
		if path ~= "" then cfg.path = path end
		local host = trim(s.h2_host)
		if host ~= "" then cfg.host = {host} end
		return cfg

	elseif t == "grpc" then
		local cfg = {type = "grpc"}
		local svc = trim(s.grpc_service)
		if svc ~= "" then cfg.service_name = svc end
		return cfg

	elseif t == "httpupgrade" then
		local cfg = {type = "httpupgrade"}
		local path = trim(s.httpupgrade_path)
		if path ~= "" then cfg.path = path end
		local host = trim(s.httpupgrade_host)
		if host ~= "" then cfg.host = host end
		return cfg
	end

	return nil
end

--- Build the TLS object.
--- @param s           UCI section table
--- @param required    boolean – force enabled even if tls_enable is not set
local function build_tls(s, required)
	if s.tls_enable ~= "1" and not required then return nil end

	-- REALITY (VLESS only)
	if s.protocol == "vless" and s.reality_enable == "1" then
		local short_ids = {}
		local sid = trim(s.reality_short_id)
		short_ids[1] = (sid ~= "") and sid or ""

		return {
			enabled = true,
			reality = {
				enabled   = true,
				handshake = {
					server      = trim(s.reality_server) ~= "" and trim(s.reality_server) or "www.microsoft.com",
					server_port = tonumber(s.reality_server_port) or 443,
				},
				private_key = trim(s.reality_private_key),
				short_id    = short_ids,
			},
		}
	end

	-- Standard TLS
	local tls = {enabled = true}
	local cert = trim(s.tls_cert_file)
	local key  = trim(s.tls_key_file)
	if cert ~= "" then tls.certificate_path = cert end
	if key  ~= "" then tls.key_path         = key  end
	return tls
end

-- ── Build inbound ─────────────────────────────────────────────────────────────

local inbound = {
	tag         = "in-" .. section_id,
	listen      = (s.bind_local == "1") and "127.0.0.1" or "::",
	listen_port = tonumber(s.port),
}

local proto = s.protocol or "vmess"

-- ┌─ VMess ─────────────────────────────────────────────────────────────────┐
if proto == "vmess" then
	inbound.type = "vmess"
	local users = {}
	local uuids = to_list(s.vmess_uuid)
	for i, uuid in ipairs(uuids) do
		uuid = trim(uuid)
		if uuid ~= "" then
			users[#users + 1] = {
				name    = "user" .. i,
				uuid    = uuid,
				alterId = tonumber(s.vmess_alter_id) or 0,
			}
		end
	end
	inbound.users     = users
	inbound.transport = build_transport(s)
	inbound.tls       = build_tls(s)

-- ┌─ VLESS ─────────────────────────────────────────────────────────────────┐
elseif proto == "vless" then
	inbound.type = "vless"
	local users = {}
	local uuids = to_list(s.vless_uuid)
	for i, uuid in ipairs(uuids) do
		uuid = trim(uuid)
		if uuid ~= "" then
			local user = {name = "user" .. i, uuid = uuid}
			local flow = trim(s.vless_flow or "")
			if flow ~= "" and flow ~= "none" then user.flow = flow end
			users[#users + 1] = user
		end
	end
	inbound.users     = users
	inbound.transport = build_transport(s)
	inbound.tls       = build_tls(s)

-- ┌─ Shadowsocks ───────────────────────────────────────────────────────────┐
elseif proto == "shadowsocks" then
	inbound.type     = "shadowsocks"
	inbound.method   = s.ss_method   or "chacha20-ietf-poly1305"
	inbound.password = s.ss_password or ""
	-- Only set network when it's not the default tcp+udp
	local net = s.ss_network or "tcp,udp"
	if net ~= "tcp,udp" then inbound.network = net end

-- ┌─ Trojan ────────────────────────────────────────────────────────────────┐
elseif proto == "trojan" then
	inbound.type = "trojan"
	local users = {}
	local pwds  = to_list(s.trojan_password)
	for i, pwd in ipairs(pwds) do
		pwd = trim(pwd)
		if pwd ~= "" then
			users[#users + 1] = {name = "user" .. i, password = pwd}
		end
	end
	inbound.users     = users
	inbound.transport = build_transport(s)
	-- Trojan requires TLS to be meaningful; treat tls_enable=1 OR always-on
	inbound.tls = build_tls(s, s.tls_enable == "1")

-- ┌─ Hysteria2 (QUIC, TLS required) ───────────────────────────────────────┐
elseif proto == "hysteria2" then
	inbound.type = "hysteria2"
	local users = {}
	local pwds  = to_list(s.hysteria2_password)
	for i, pwd in ipairs(pwds) do
		pwd = trim(pwd)
		if pwd ~= "" then
			users[#users + 1] = {name = "user" .. i, password = pwd}
		end
	end
	inbound.users = users

	local obfs = trim(s.hysteria2_obfs or "")
	if obfs ~= "" then
		inbound.obfs = {type = "salamander", password = obfs}
	end

	local up   = tonumber(s.hysteria2_up_mbps)
	local down = tonumber(s.hysteria2_down_mbps)
	if up   then inbound.up_mbps   = up   end
	if down then inbound.down_mbps = down end

	inbound.tls = build_tls(s, true)   -- always required

-- ┌─ TUIC v5 (QUIC, TLS required) ─────────────────────────────────────────┐
elseif proto == "tuic" then
	inbound.type = "tuic"
	local users = {}
	local uuids = to_list(s.tuic_uuid)
	local pwds  = to_list(s.tuic_password)
	for i, uuid in ipairs(uuids) do
		uuid = trim(uuid)
		if uuid ~= "" then
			users[#users + 1] = {
				name     = "user" .. i,
				uuid     = uuid,
				password = trim(pwds[i] or ""),
			}
		end
	end
	inbound.users              = users
	inbound.congestion_control = s.tuic_congestion or "bbr"
	inbound.tls                = build_tls(s, true)   -- always required

-- ┌─ SOCKS5 ────────────────────────────────────────────────────────────────┐
elseif proto == "socks" then
	inbound.type = "socks"
	local user = trim(s.socks_username or "")
	local pass = trim(s.socks_password or "")
	if user ~= "" then
		inbound.users = {{username = user, password = pass}}
	end

-- ┌─ HTTP ──────────────────────────────────────────────────────────────────┐
elseif proto == "http" then
	inbound.type = "http"
	local user = trim(s.http_username or "")
	local pass = trim(s.http_password or "")
	if user ~= "" then
		inbound.users = {{username = user, password = pass}}
	end
end

-- ── Route rules ────────────────────────────────────────────────────────────

local route = nil
if s.accept_lan ~= "1" then
	-- Block private address ranges by default (server acts only as a relay)
	route = {
		rules = {{
			ip_cidr  = {"10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16", "127.0.0.0/8"},
			outbound = "blocked",
		}},
		final = "direct",
	}
else
	route = {final = "direct"}
end

-- ── Final config ───────────────────────────────────────────────────────────

local config = {
	log = {level = "warn"},
	inbounds  = {inbound},
	outbounds = {
		{type = "direct", tag = "direct"},
		{type = "block",  tag = "blocked"},
	},
	route = route,
}

print(json.stringify(config, 1))
