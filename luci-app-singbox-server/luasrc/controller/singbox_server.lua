module("luci.controller.singbox_server", package.seeall)

local fs = require "nixio.fs"
local sys = require "luci.sys"
local http = require "luci.http"
local jsonc = require "luci.jsonc"
local uci = require "luci.model.uci".cursor()

local appname = "singbox_server"

function index()
	if not fs.access("/etc/config/" .. appname) then
		return
	end

	entry({"admin", "services", appname}, alias("admin", "services", appname, "server"), _("Sing-box Server"), 60).dependent = true
	entry({"admin", "services", appname, "server"}, cbi(appname .. "/server/index"), _("Server-Side"), 10).leaf = true
	entry({"admin", "services", appname, "server_user"}, cbi(appname .. "/server/user"), nil).leaf = true

	entry({"admin", "services", appname, "restart"}, call("restart"), nil).leaf = true
	entry({"admin", "services", appname, "user_status"}, call("user_status"), nil).leaf = true
	entry({"admin", "services", appname, "users_status"}, call("users_status"), nil).leaf = true
	entry({"admin", "services", appname, "get_log"}, call("get_log"), nil).leaf = true
	entry({"admin", "services", appname, "clear_log"}, call("clear_log"), nil).leaf = true
	entry({"admin", "services", appname, "user_log"}, call("user_log"), nil).leaf = true
end

local function write_json(data)
	http.prepare_content("application/json")
	http.write(jsonc.stringify(data or {}))
end

local function shellquote(s)
	return "'" .. tostring(s or ""):gsub("'", "'\\''") .. "'"
end

function restart()
	sys.call("/etc/init.d/singbox_server restart >/dev/null 2>&1 &")
	write_json({code = 1})
end

function user_status()
	local id = http.formvalue("id") or ""
	local running = false
	if id ~= "" then
		running = sys.call("pgrep -f " .. shellquote("/tmp/etc/singbox_server/" .. id .. ".json") .. " >/dev/null") == 0
	end
	write_json({status = running})
end

function users_status()
	local result = {}
	uci:foreach(appname, "user", function(s)
		local id = s[".name"]
		local running = sys.call("pgrep -f " .. shellquote("/tmp/etc/singbox_server/" .. id .. ".json") .. " >/dev/null") == 0
		result[id] = running
	end)
	write_json(result)
end

function get_log()
	http.prepare_content("text/plain; charset=utf-8")
	http.write(fs.readfile("/tmp/log/singbox_server.log") or "")
end

function clear_log()
	sys.call("echo '' > /tmp/log/singbox_server.log")
	write_json({code = 1})
end

function user_log()
	local id = http.formvalue("id") or ""
	local path = "/tmp/etc/singbox_server/" .. id .. ".log"
	http.prepare_content("text/plain; charset=utf-8")
	http.write(fs.readfile(path) or "")
end
