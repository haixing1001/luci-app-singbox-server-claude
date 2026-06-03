module("luci.controller.singbox_server", package.seeall)

function index()
    if not nixio.fs.access("/etc/config/singbox_server") then
        return
    end

    entry({"admin", "services", "singbox_server"}, cbi("singbox_server/server"), _("Sing-Box Server"), 50).dependent = true
end
