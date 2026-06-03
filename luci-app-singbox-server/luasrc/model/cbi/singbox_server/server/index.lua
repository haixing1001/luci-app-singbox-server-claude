local appname = "singbox_server"

m = Map(appname, translate("Server-Side"))

-- 参照 PassWall2：global 使用 NamedSection，字段名使用 enable。
t = m:section(NamedSection, "global", "global")
t.anonymous = true
t.addremove = false

e = t:option(Flag, "enable", translate("Enable"))
e.rmempty = false

e = t:option(Value, "bin_path", translate("Sing-box Binary Path"))
e.default = "/usr/bin/sing-box"
e.rmempty = false

e = t:option(ListValue, "loglevel", translate("Log Level"))
e:value("debug", "debug")
e:value("info", "info")
e:value("warn", "warn")
e:value("error", "error")
e.default = "info"

-- 参照 PassWall2：用户管理表 section 名称为 user，模板为 cbi/tblsection。
t = m:section(TypedSection, "user", translate("Users Manager"))
t.anonymous = true
t.addremove = true
t.sortable = true
t.template = "cbi/tblsection"
t.extedit = luci.dispatcher.build_url("admin", "services", appname, "server_user", "%s")

function t.create(e, tname)
	local uuid = luci.sys.exec("cat /proc/sys/kernel/random/uuid 2>/dev/null"):gsub("%s+", "")
	if uuid == "" then
		uuid = tostring(os.time()) .. tostring(math.random(1000, 9999))
	end
	tname = uuid
	TypedSection.create(e, tname)
	e.map:set(tname, "enable", "1")
	e.map:set(tname, "type", "sing-box")
	e.map:set(tname, "protocol", "vless")
	e.map:set(tname, "transport", "tcp")
	e.map:set(tname, "listen", "::")
	e.map:set(tname, "port", "443")
	e.map:set(tname, "uuid", uuid)
	e.map:set(tname, "sniff", "1")
	e.map:set(tname, "log", "1")
	luci.http.redirect(e.extedit:format(tname))
end

function t.remove(e, tname)
	e.map.proceed = true
	e.map:del(tname)
	luci.http.redirect(luci.dispatcher.build_url("admin", "services", appname, "server"))
end

e = t:option(Flag, "enable", translate("Enable"))
e.width = "5%"
e.rmempty = false

e = t:option(DummyValue, "status", translate("Status"))
e.rawhtml = true
e.cfgvalue = function(t, n)
	return string.format('<span class="singbox-server-status" data-id="%s">%s</span>', n, translate("Collecting data..."))
end

e = t:option(DummyValue, "remarks", translate("Remarks"))
e.width = "15%"
e.cfgvalue = function(t, n)
	return m:get(n, "remarks") or n
end

e = t:option(DummyValue, "type", translate("Type"))
e.width = "20%"
e.rawhtml = true
e.cfgvalue = function(t, n)
	local type = m:get(n, "type") or "sing-box"
	local protocol = m:get(n, "protocol") or ""
	if protocol == "vmess" then
		protocol = "VMess"
	elseif protocol == "vless" then
		protocol = "VLESS"
	elseif protocol == "shadowsocks" then
		protocol = "SS"
	elseif protocol == "hysteria2" then
		protocol = "HY2"
	elseif protocol == "trojan" then
		protocol = "Trojan"
	else
		protocol = protocol:gsub("^%l", string.upper)
	end
	if type == "sing-box" then type = "Sing-Box" end
	return translate(type .. " " .. protocol)
end

e = t:option(DummyValue, "port", translate("Port"))
e.cfgvalue = function(t, n)
	return m:get(n, "port") or m:get(n, "listen_port") or "-"
end

e = t:option(Flag, "log", translate("Log"))
e.default = "1"
e.rmempty = false

-- 顺序参照 PassWall2：日志模板，再追加用户状态轮询模板。
m:append(Template(appname .. "/server/log"))
m:append(Template(appname .. "/server/users_list_status"))

return m
