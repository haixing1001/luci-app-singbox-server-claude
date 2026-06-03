module("luci.controller.singbox-server", package.seeall)

local fs = require "nixio.fs"
local sys = require "luci.sys"
local http = require "luci.http"
local dispatcher = require "luci.dispatcher"
local uci = require "luci.model.uci".cursor()

local function shellquote(s)
	return "'" .. tostring(s or ""):gsub("'", "'\\''") .. "'"
end

local function valid_section(name)
	return name and name:match("^[A-Za-z0-9_%-]+$") ~= nil
end

local function redirect_status()
	http.redirect(dispatcher.build_url("admin/services/singbox-server/status"))
end

function index()
	if not fs.access("/etc/config/singbox-server") then
		return
	end

	entry({"admin", "services", "singbox-server"}, alias("admin", "services", "singbox-server", "status"), translate("Sing-box Server"), 30).dependent = true
	entry({"admin", "services", "singbox-server", "status"}, call("action_status"), translate("Status"), 1).leaf = true
	entry({"admin", "services", "singbox-server", "config"}, cbi("singbox-server/config"), translate("Configuration"), 2).leaf = true
	entry({"admin", "services", "singbox-server", "start"}, call("action_start")).leaf = true
	entry({"admin", "services", "singbox-server", "stop"}, call("action_stop")).leaf = true
	entry({"admin", "services", "singbox-server", "restart"}, call("action_restart")).leaf = true
	entry({"admin", "services", "singbox-server", "enable"}, call("action_enable")).leaf = true
	entry({"admin", "services", "singbox-server", "disable"}, call("action_disable")).leaf = true
	entry({"admin", "services", "singbox-server", "log"}, call("action_log")).leaf = true
end

local function instance_running(config_file)
	if not config_file or config_file == "" then
		return false
	end
	local cmd = "pgrep -f " .. shellquote("sing-box run -c " .. config_file) .. " >/dev/null 2>&1"
	return sys.call(cmd) == 0
end

local function get_instance(name)
	if not valid_section(name) then
		return nil
	end
	local t = uci:get_all("singbox-server", name)
	if not t or t[".type"] ~= "server" then
		return nil
	end
	return t
end

local function get_instances()
	local instances = {}
	uci:foreach("singbox-server", "server", function(s)
		local name = s[".name"]
		local config_file = s.config_file or ("/etc/sing-box/server/" .. name .. ".json")
		instances[#instances + 1] = {
			name = name,
			enabled = s.enabled or "0",
			config_file = config_file,
			log_file = s.log_file or ("/var/log/singbox-server_" .. name .. ".log"),
			log_level = s.log_level or "info",
			running = instance_running(config_file)
		}
	end)
	return instances
end

local function set_enabled(name, enabled)
	local s = get_instance(name)
	if not s then
		return false
	end
	uci:set("singbox-server", name, "enabled", enabled)
	uci:commit("singbox-server")
	return true
end

function action_status()
	luci.template.render("singbox-server/status", { instances = get_instances() })
end

function action_log()
	local name = http.formvalue("name")
	local s = get_instance(name)
	local log_file = s and s.log_file or nil
	local log = translate("No log available")

	if log_file and fs.access(log_file) then
		log = sys.exec("tail -n 200 " .. shellquote(log_file) .. " 2>/dev/null")
	end

	luci.template.render("singbox-server/log", { log = log, name = name or "" })
end

function action_start()
	local name = http.formvalue("name")
	if valid_section(name) then
		set_enabled(name, "1")
		sys.call("/etc/init.d/singbox-server restart >/dev/null 2>&1")
	else
		sys.call("/etc/init.d/singbox-server start >/dev/null 2>&1")
	end
	redirect_status()
end

function action_stop()
	local name = http.formvalue("name")
	if valid_section(name) then
		set_enabled(name, "0")
		sys.call("/etc/init.d/singbox-server restart >/dev/null 2>&1")
	else
		sys.call("/etc/init.d/singbox-server stop >/dev/null 2>&1")
	end
	redirect_status()
end

function action_restart()
	local name = http.formvalue("name")
	if valid_section(name) then
		-- procd does not expose a simple per-instance restart through rc.common here;
		-- restart the service after keeping the selected instance enabled.
		set_enabled(name, "1")
	end
	sys.call("/etc/init.d/singbox-server restart >/dev/null 2>&1")
	redirect_status()
end

function action_enable()
	local name = http.formvalue("name")
	if valid_section(name) then
		set_enabled(name, "1")
	end
	redirect_status()
end

function action_disable()
	local name = http.formvalue("name")
	if valid_section(name) then
		set_enabled(name, "0")
	end
	redirect_status()
end
