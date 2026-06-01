-- luci/model/cbi/sing_box_server/api/singbox.lua
-- Helper utilities for the sing-box server LuCI plugin.

local sys = require "luci.sys"
local M   = {}

--- Return the installed sing-box version string (or empty string).
function M.get_version()
	-- Try the binary first
	local v = sys.exec("/usr/bin/sing-box version 2>/dev/null | head -1")
	if v and v ~= "" then
		local ver = v:match("sing%-box%s+version%s+([%d%.%a%-]+)")
			     or v:match("([%d]+%.[%d]+%.[%d]+[%a%-]*[%d]*)")
		if ver then return ver end
	end
	-- Fall back to opkg metadata
	v = sys.exec("opkg info sing-box 2>/dev/null | grep '^Version' | awk '{print $2}' | head -1")
	if v then v = v:match("^(.-)%s*$") end
	return (v and v ~= "") and v or "unknown"
end

--- Return true if at least one sing-box server instance is running.
function M.is_running()
	return sys.call(
		"ps -w 2>/dev/null | grep -v grep | grep 'sing-box run -c /var/etc/sing_box_server/' >/dev/null"
	) == 0
end

return M
