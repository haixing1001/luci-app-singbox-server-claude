local appname = "singbox_server"
local uci = luci.model.uci.cursor()

m = Map(appname, translate("Sing-box Server"))
m.description = translate("Sing-box server-side management, designed similar to PassWall2 server page.")

-- 确保全局配置段一定存在。否则 NamedSection/TypedSection 在某些 LuCI 版本不会显示。
function m.on_init(self)
	if not self.uci:get(appname, "global") then
		self.uci:section(appname, "global", "global", {
			enabled = "0",
			loglevel = "info",
			bin_path = "/usr/bin/sing-box"
		})
		self.uci:save(appname)
		self.uci:commit(appname)
	end
end

-- 全局设置：改用 TypedSection，兼容性比 NamedSection 更好，确保页面顶部显示全局开关。
s = m:section(TypedSection, "global", translate("Global Settings"))
s.anonymous = true
s.addremove = false
s.optional = false

function s.filter(self, section)
	return section == "global"
end

o = s:option(Flag, "enabled", translate("Enable"))
o.rmempty = false
o.default = "0"

o = s:option(Value, "bin_path", translate("Sing-box Binary Path"))
o.default = "/usr/bin/sing-box"
o.rmempty = false

o = s:option(ListValue, "loglevel", translate("Log Level"))
o:value("debug", "debug")
o:value("info", "info")
o:value("warn", "warn")
o:value("error", "error")
o.default = "info"

s = m:section(TypedSection, "user", translate("Users Manager"))
s.anonymous = true
s.addremove = true
s.sortable = true
s.template = "cbi/tblsection"
s.extedit = luci.dispatcher.build_url("admin", "services", appname, "server_user", "%s")

function s.create(self, section)
	local sid = TypedSection.create(self, section)
	m.uci:set(appname, sid, "enabled", "0")
	m.uci:set(appname, sid, "type", "sing-box")
	m.uci:set(appname, sid, "protocol", "vless")
	m.uci:set(appname, sid, "transport", "tcp")
	m.uci:set(appname, sid, "listen", "::")
	m.uci:set(appname, sid, "listen_port", "443")
	m.uci:set(appname, sid, "sniff", "1")
	m.uci:set(appname, sid, "log", "1")
	return sid
end

o = s:option(Flag, "enabled", translate("Enable"))
o.rmempty = false

o = s:option(DummyValue, "_status", translate("Status"))
o.rawhtml = true
function o.cfgvalue(self, section)
	return string.format('<span class="singbox-server-status" data-id="%s">%s</span>', section, translate("Collecting data..."))
end

o = s:option(DummyValue, "remarks", translate("Remarks"))
function o.cfgvalue(self, section)
	return m.uci:get(appname, section, "remarks") or section
end

o = s:option(DummyValue, "type", translate("Type"))
function o.cfgvalue(self, section)
	return "sing-box"
end

o = s:option(DummyValue, "protocol", translate("Protocol"))
function o.cfgvalue(self, section)
	return m.uci:get(appname, section, "protocol") or "-"
end

o = s:option(DummyValue, "listen_port", translate("Port"))
function o.cfgvalue(self, section)
	return m.uci:get(appname, section, "listen_port") or "-"
end

o = s:option(Flag, "log", translate("Log"))
o.rmempty = false

m:append(Template(appname .. "/server/users_list_status"))
m:append(Template(appname .. "/server/log"))

return m
