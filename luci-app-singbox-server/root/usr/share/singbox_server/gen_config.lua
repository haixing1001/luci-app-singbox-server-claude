#!/usr/bin/lua

local uci = require "luci.model.uci".cursor()
local jsonc = require "luci.jsonc"

local section_id = arg[1]
local out_file = arg[2]

if not section_id or not out_file then
    os.exit(1)
end

local node = uci:get_all("singbox_server", section_id)
if not node or node.enable ~= "1" then
    os.exit(0)
end

local function split(str, reps)
    local resultStrList = {}
    string.gsub(str, '[^' .. reps .. ']+', function(w)
        table.insert(resultStrList, w)
    end)
    return resultStrList
end

local tls = {
    enabled = true,
    certificate_path = node.tls_certificateFile,
    key_path = node.tls_keyFile,
    alpn = (node.alpn and node.alpn ~= "default") and split(node.alpn, ',') or nil
}

if node.tls == "1" and node.reality == "1" then
    tls.certificate_path = nil
    tls.key_path = nil
    tls.server_name = node.reality_handshake_server
    tls.reality = {
        enabled = true,
        private_key = node.reality_private_key,
        short_id = { node.reality_shortId },
        handshake = {
            server = node.reality_handshake_server,
            server_port = 443
        }
    }
end

local transport = nil
if node.transport == "ws" then
    transport = { type = "ws", path = node.ws_path or "/" }
elseif node.transport == "grpc" then
    transport = { type = "grpc", service_name = node.grpc_serviceName }
end

local inbound = {
    type = node.protocol,
    tag = "inbound-" .. section_id,
    listen = "::",
    listen_port = tonumber(node.port)
}

local function get_users(is_vless)
    local users = {}
    if node.uuid then
        for _, v in ipairs(type(node.uuid) == "table" and node.uuid or {node.uuid}) do
            if is_vless then
                table.insert(users, { name = v, uuid = v, flow = (node.flow ~= "") and node.flow or nil })
            else
                table.insert(users, { name = v, uuid = v })
            end
        end
    end
    return #users > 0 and users or nil
end

if node.protocol == "shadowsocks" then
    inbound.method = node.ss_method
    inbound.password = node.password
elseif node.protocol == "vless" then
    inbound.users = get_users(true)
    inbound.tls = (node.tls == "1") and tls or nil
    inbound.transport = transport
elseif node.protocol == "vmess" then
    inbound.users = get_users(false)
    inbound.tls = (node.tls == "1") and tls or nil
    inbound.transport = transport
elseif node.protocol == "trojan" then
    local users = {}
    if node.uuid then
        for _, v in ipairs(type(node.uuid) == "table" and node.uuid or {node.uuid}) do
            table.insert(users, { name = v, password = v })
        end
    end
    inbound.users = users
    inbound.tls = (node.tls == "1") and tls or nil
    inbound.transport = transport
elseif node.protocol == "hysteria2" then
    inbound.up_mbps = tonumber(node.hysteria2_up_mbps)
    inbound.down_mbps = tonumber(node.hysteria2_down_mbps)
    inbound.users = {{ name = "user1", password = node.password }}
    inbound.tls = tls
end

local config = {
    log = { level = "info", timestamp = true },
    inbounds = { inbound },
    outbounds = { { type = "direct", tag = "direct" } }
}

local f = io.open(out_file, "w")
if f then
    f:write(jsonc.stringify(config, 1))
    f:close()
end
