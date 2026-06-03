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
	entry({"admin", "services", appname, "server"}, cbi(appname .. "/server/index"), _("Server-Side"), 99).leaf = true
	entry({"admin", "services", appname, "server_user"}, cbi(appname .. "/server/user")).leaf = true

	entry({"admin", "services", appname, "server_user_update"}, call("server_user_update")).leaf = true
	entry({"admin", "services", appname, "server_user_status"}, call("server_user_status")).leaf = true
	entry({"admin", "services", appname, "server_user_log"}, call("server_user_log")).leaf = true
	entry({"admin", "services", appname, "server_get_log"}, call("server_get_log")).leaf = true
	entry({"admin", "services", appname, "server_clear_log"}, call("server_clear_log")).leaf = true
	entry({"admin", "services", appname, "restart"}, call("restart")).leaf = true
end

local function http_write_json(content)
	http.prepare_content("application/json")
	http.write(jsonc.stringify(content or { code = 1 }))
end

local function shellquote(s)
	return "'" .. tostring(s or ""):gsub("'", "'\\''") .. "'"
end

function restart()
	sys.call("/etc/init.d/singbox_server restart >/dev/null 2>&1 &")
	http_write_json({ code = 1 })
end

function server_user_update()
	restart()
end

function server_user_status()
	local result = {}
	local id = http.formvalue("id")
	if id and id ~= "" then
		result[id] = sys.call("pgrep -f " .. shellquote("/tmp/etc/singbox_server/" .. id .. ".json") .. " >/dev/null") == 0
	else
		uci:foreach(appname, "user", function(s)
			local sid = s[".name"]
			result[sid] = sys.call("pgrep -f " .. shellquote("/tmp/etc/singbox_server/" .. sid .. ".json") .. " >/dev/null") == 0
		end)
	end
	http_write_json(result)
end

function server_user_log()
	local id = http.formvalue("id") or ""
	local path = "/tmp/etc/singbox_server/" .. id .. ".log"
	http.prepare_content("text/plain; charset=utf-8")
	http.write(fs.readfile(path) or "")
end

function server_get_log()
	http.prepare_content("text/plain; charset=utf-8")
	http.write(fs.readfile("/tmp/log/singbox_server.log") or "")
end

function server_clear_log()
	sys.call("echo '' > /tmp/log/singbox_server.log")
	http_write_json({ code = 1 })
end
