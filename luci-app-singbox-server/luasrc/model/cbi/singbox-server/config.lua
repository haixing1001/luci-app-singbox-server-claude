local m, s, o

m = Map("singbox-server", translate("Sing-box Server Configuration"),
	translate("Manage multiple Sing-box server instances. Each instance runs independently with its own configuration file and log."))

s = m:section(TypedSection, "server", translate("Server Instances"))
s.addremove = true
s.anonymous = false
s.template = "cbi/tblsection"

function s.create(self, section)
	if not section or section == "" then
		return nil
	end
	section = section:gsub("[^A-Za-z0-9_%-]", "_")
	TypedSection.create(self, section)
	m.uci:set("singbox-server", section, "enabled", "0")
	m.uci:set("singbox-server", section, "config_file", "/etc/sing-box/server/" .. section .. ".json")
	m.uci:set("singbox-server", section, "log_file", "/var/log/singbox-server_" .. section .. ".log")
	m.uci:set("singbox-server", section, "log_level", "info")
	return section
end

o = s:option(Flag, "enabled", translate("Enable"))
o.rmempty = false
o.default = "0"

o = s:option(Value, "config_file", translate("Config File"))
o.rmempty = false
o.datatype = "file"
o.placeholder = "/etc/sing-box/server/instance_name.json"

o = s:option(Value, "log_file", translate("Log File"))
o.rmempty = false
o.datatype = "file"
o.placeholder = "/var/log/singbox-server_instance.log"

o = s:option(ListValue, "log_level", translate("Log Level"))
o:value("debug", "debug")
o:value("info", "info")
o:value("warning", "warning")
o:value("error", "error")
o.default = "info"
o.rmempty = false

return m
