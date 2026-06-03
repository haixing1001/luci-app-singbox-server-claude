local m, s, o

m = Map("singbox-server", translate("Sing-box Server Configuration"),
	translate("Manage multiple Sing-box server instances. Each instance runs independently with its own configuration file and log."))

s = m:section(TypedSection, "server", translate("Server Instances"))
s.addremove = true
s.anonymous = false
s.template = "cbi/tblsection"

o = s:option(Flag, "enabled", translate("Enable"))
o.rmempty = false
o.default = "0"

o = s:option(Value, "config_file", translate("Config File"))
o.rmempty = false
o.datatype = "file"
o.placeholder = "/etc/sing-box/server/instance_name.json"

o = s:option(Value, "log_file", translate("Log File"))
o.default = "/var/log/singbox-server_instance.log"
o.datatype = "file"

o = s:option(ListValue, "log_level", translate("Log Level"))
o:value("debug", "debug")
o:value("info", "info")
o:value("warning", "warning")
o:value("error", "error")
o.default = "info"

return m
