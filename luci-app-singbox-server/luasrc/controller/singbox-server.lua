module("luci.controller.singbox-server", package.seeall)

function index()
	if not nixio.fs.access("/etc/config/singbox-server") then
		return
	end

	entry({"admin", "services", "singbox-server"},
		alias("admin", "services", "singbox-server", "status"),
		translate("Sing-box Server"), 30).dependent = true

	entry({"admin", "services", "singbox-server", "status"},
		call("action_status"), translate("Status"), 1).leaf = true

	entry({"admin", "services", "singbox-server", "config"},
		cbi("singbox-server/config"), translate("Configuration"), 2).leaf = true

	entry({"admin", "services", "singbox-server", "start"},
		call("action_start"))
	entry({"admin", "services", "singbox-server", "stop"},
		call("action_stop"))
	entry({"admin", "services", "singbox-server", "restart"},
		call("action_restart"))
	entry({"admin", "services", "singbox-server", "enable"},
		call("action_enable"))
	entry({"admin", "services", "singbox-server", "disable"},
		call("action_disable"))
	entry({"admin", "services", "singbox-server", "log"},
		call("action_log"))
end

local function instance_running(config_file)
	if not config_file then return false end
	local cmd = string.format("pgrep -f 'sing-box run -c %s'", config_file)
	return luci.sys.call(cmd .. " >/dev/null") == 0
end

local function get_instances()
	local uci = require "luci.model.uci".cursor()
	local instances = {}
	uci:foreach("singbox-server", "server", function(s)
		local name = s[".name"]
		local enabled = s.enabled or "0"
		local config_file = s.config_file or ("/etc/sing-box/server/" .. name .. ".json")
		local log_file = s.log_file or ("/var/log/singbox-server_" .. name .. ".log")
		local log_level = s.log_level or "info"
		instances[#instances+1] = {
			name = name,
			enabled = enabled,
			config_file = config_file,
			log_file = log_file,
			log_level = log_level,
			running = instance_running(config_file)
		}
	end)
	return instances
end

function action_status()
	luci.template.render("singbox-server/status", {instances = get_instances()})
end

function action_log()
	local name = luci.http.formvalue("name")
	local uci = require "luci.model.uci".cursor()
	local log_file = uci:get("singbox-server", name, "log_file") or "/var/log/singbox-server.log"
	local log = luci.sys.exec("tail -n 200 " .. log_file .. " 2>/dev/null") or translate("No log available")
	luci.template.render("singbox-server/log", {log = log, name = name})
end

function action_start()
	luci.sys.call("/etc/init.d/singbox-server start")
	luci.http.redirect(luci.dispatcher.build_url("admin/services/singbox-server/status"))
end

function action_stop()
	local name = luci.http.formvalue("name")
	if name and name ~= "" then
		local uci = require "luci.model.uci".cursor()
		local config_file = uci:get("singbox-server", name, "config_file")
		if config_file then
			luci.sys.call("pkill -f 'sing-box run -c " .. config_file .. "'")
		end
	else
		luci.sys.call("/etc/init.d/singbox-server stop")
	end
	luci.http.redirect(luci.dispatcher.build_url("admin/services/singbox-server/status"))
end

function action_restart()
	local name = luci.http.formvalue("name")
	if name and name ~= "" then
		local uci = require "luci.model.uci".cursor()
		local config_file = uci:get("singbox-server", name, "config_file")
		local log_file = uci:get("singbox-server", name, "log_file") or "/var/log/singbox-server_" .. name .. ".log"
		if config_file then
			luci.sys.call("pkill -f 'sing-box run -c " .. config_file .. "'")
			luci.sys.call(string.format(
				"/usr/bin/sing-box run -c '%s' >> %s 2>&1 &",
				config_file, log_file
			))
		end
	else
		luci.sys.call("/etc/init.d/singbox-server restart")
	end
	luci.http.redirect(luci.dispatcher.build_url("admin/services/singbox-server/status"))
end

function action_enable()
	local name = luci.http.formvalue("name")
	if name then
		local uci = require "luci.model.uci".cursor()
		uci:set("singbox-server", name, "enabled", "1")
		uci:commit("singbox-server")
	end
	luci.http.redirect(luci.dispatcher.build_url("admin/services/singbox-server/status"))
end

function action_disable()
	local name = luci.http.formvalue("name")
	if name then
		local uci = require "luci.model.uci".cursor()
		uci:set("singbox-server", name, "enabled", "0")
		uci:commit("singbox-server")
	end
	luci.http.redirect(luci.dispatcher.build_url("admin/services/singbox-server/status"))
end
