local dispatcher = require "luci.dispatcher"
local fs         = require "nixio.fs"
local uci        = luci.model.uci.cursor()
local app_name   = "sing_box_server"

m = Map(app_name, translate("sing-box Server"))

-- ── Global settings ───────────────────────────────────────────────────────────
gs = m:section(TypedSection, "global", translate("Global Settings"))
gs.anonymous  = true
gs.addremove  = false

en = gs:option(Flag, "enable", translate("Enable"))
en.rmempty = false

gs:append(Template("sing_box_server/status"))

-- ── User list ─────────────────────────────────────────────────────────────────
us = m:section(TypedSection, "user", translate("Users Manager"))
us.anonymous  = true
us.addremove  = true
us.template   = "cbi/tblsection"
us.extedit    = dispatcher.build_url("admin", "vpn", app_name, "config", "%s")

function us.create(self, section)
	local sid = TypedSection.create(self, section)
	luci.http.redirect(dispatcher.build_url("admin", "vpn", app_name, "config", sid))
end

function us.remove(self, sid)
	self.map.proceed = true
	self.map:del(sid)
	luci.http.redirect(dispatcher.build_url("admin", "vpn", app_name))
end

-- Enable flag
col_en = us:option(Flag, "enable", translate("Enable"))
col_en.width    = "5%"
col_en.rmempty  = false

-- Running status (polled via XHR)
col_st = us:option(DummyValue, "status", translate("Status"))
col_st.template = "sing_box_server/users_status"
col_st.value    = translate("Collecting data...")

-- Remarks
col_rm = us:option(DummyValue, "remarks", translate("Remarks"))
col_rm.width = "15%"

-- Port
col_pt = us:option(DummyValue, "port", translate("Port"))
col_pt.width = "8%"

-- Protocol
col_pr = us:option(DummyValue, "protocol", translate("Protocol"))
col_pr.width = "12%"
col_pr.cfgvalue = function(self, section)
	local p = m:get(section, "protocol") or ""
	local map = {
		vmess       = "VMess",
		vless       = "VLESS",
		shadowsocks = "Shadowsocks",
		trojan      = "Trojan",
		hysteria2   = "Hysteria2",
		tuic        = "TUIC",
		socks       = "SOCKS5",
		http        = "HTTP",
	}
	return map[p] or p
end

-- Transport
col_tr = us:option(DummyValue, "transport_info", translate("Transport"))
col_tr.width = "10%"
col_tr.cfgvalue = function(self, section)
	local proto = m:get(section, "protocol") or ""
	if proto == "hysteria2" or proto == "tuic" then
		return "QUIC"
	elseif proto == "socks" or proto == "http" then
		return "TCP"
	elseif proto == "shadowsocks" then
		local net = m:get(section, "ss_network") or "tcp,udp"
		return net:upper():gsub(",", "+")
	end
	local t = m:get(section, "transport") or "tcp"
	local map = {tcp="TCP", ws="WebSocket", http="HTTP/2", grpc="gRPC", httpupgrade="HTTPUpgrade"}
	return map[t] or t:upper()
end

-- Credential preview
col_pw = us:option(DummyValue, "credential", translate("Credential"))
col_pw.width = "30%"
col_pw.cfgvalue = function(self, section)
	local proto = m:get(section, "protocol") or ""
	if proto == "vmess" or proto == "vless" then
		local key = (proto == "vmess") and "vmess_uuid" or "vless_uuid"
		local v = m:get(section, key) or ""
		if type(v) == "table" then v = v[1] or "" end
		return v
	elseif proto == "shadowsocks" then
		return m:get(section, "ss_password") or ""
	elseif proto == "trojan" then
		local v = m:get(section, "trojan_password") or ""
		if type(v) == "table" then v = v[1] or "" end
		return v
	elseif proto == "hysteria2" then
		local v = m:get(section, "hysteria2_password") or ""
		if type(v) == "table" then v = v[1] or "" end
		return v
	elseif proto == "tuic" then
		local v = m:get(section, "tuic_uuid") or ""
		if type(v) == "table" then v = v[1] or "" end
		return v
	elseif proto == "socks" or proto == "http" then
		return m:get(section, proto .. "_username") or "(no auth)"
	end
	return ""
end

m:append(Template("sing_box_server/log"))
m:append(Template("sing_box_server/users_list_status"))

return m
