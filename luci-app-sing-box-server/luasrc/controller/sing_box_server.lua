module("luci.controller.sing_box_server", package.seeall)

local http  = require "luci.http"
local sys   = require "luci.sys"
local nixio = require "nixio"

function index()
	if not nixio.fs.access("/etc/config/sing_box_server") then return end

	entry({"admin", "vpn"}, firstchild(), "VPN", 45).dependent = false

	entry({"admin", "vpn", "sing_box_server"},
	      cbi("sing_box_server/index"),
	      _("sing-box Server"), 4).dependent = true

	entry({"admin", "vpn", "sing_box_server", "config"},
	      cbi("sing_box_server/config")).leaf = true

	entry({"admin", "vpn", "sing_box_server", "users_status"},
	      call("users_status")).leaf = true

	entry({"admin", "vpn", "sing_box_server", "get_log"},
	      call("get_log")).leaf = true

	entry({"admin", "vpn", "sing_box_server", "clear_log"},
	      call("clear_log")).leaf = true

	entry({"admin", "vpn", "sing_box_server", "restart"},
	      call("service_restart")).leaf = true
end

local function http_write_json(content)
	http.prepare_content("application/json")
	http.write_json(content or {code = 1})
end

-- Poll running status for one user section
function users_status()
	local e = {}
	e.index = http.formvalue("index")
	local id = http.formvalue("id")
	e.status = sys.call(
		"ps -w 2>/dev/null | grep -v grep | grep '/var/etc/sing_box_server/" ..
		id .. ".json' >/dev/null") == 0
	http_write_json(e)
end

function get_log()
	http.write(sys.exec(
		"[ -f '/var/log/sing_box_server/app.log' ] && cat /var/log/sing_box_server/app.log || echo '(no log)'"))
end

function clear_log()
	sys.call(": > /var/log/sing_box_server/app.log")
end

function service_restart()
	sys.call("/etc/init.d/sing_box_server restart >/dev/null 2>&1 &")
	http_write_json({code = 0})
end
