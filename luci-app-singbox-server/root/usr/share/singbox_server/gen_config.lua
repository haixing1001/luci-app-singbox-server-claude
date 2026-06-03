#!/usr/bin/lua

local uci = require "luci.model.uci".cursor()
local jsonc = require "luci.jsonc"
local sys = require "luci.sys"

local section_id = arg[1]
local out_file = arg[2]
if not section_id or not out_file then os.exit(1) end

local node = uci:get_all("singbox_server", section_id)
if not node or node.enable ~= "1" then os.exit(0) end

if node.custom == "1" and node.custom_config then
    local custom_cfg = jsonc.parse(node.custom_config)
    if custom_cfg then
        local f = io.open(out_file, "w")
        f:write(jsonc.stringify(custom_cfg, 1))
        f:close()
        os.exit(0)
    end
end

local outbounds = { { type = "direct", tag = "direct" } }

local tls = {
    enabled = true,
    certificate_path = node.tls_certificateFile,
    key_path = node.tls_keyFile,
    alpn = (node.alpn and node.alpn ~= "default") and (function()
        local alpn = {}
        string.gsub(node.alpn, '[^,]+', function(w) table.insert(alpn, w) end)
        return #alpn > 0 and alpn or nil
    end)() or nil
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
            server_port = tonumber(node.reality_handshake_server_port) or 443
        }
    }
end

if node.tls == "1" and node.ech == "1" then
    tls.ech = {
        enabled = true,
        key = node.ech_key and { node.ech_key } or nil
    }
end

local mux = nil
if node.mux == "1" then
    mux = {
        enabled = true,
        padding = false,
        brutal = {
            enabled = (node.tcpbrutal == "1"),
            up_mbps = tonumber(node.tcpbrutal_up_mbps) or 10,
            down_mbps = tonumber(node.tcpbrutal_down_mbps) or 50,
        },
    }
end

local v2ray_transport = nil
if node.transport == "http" then
    v2ray_transport = { type = "http", host = node.http_host or {}, path = node.http_path or "/" }
elseif node.transport == "ws" then
    v2ray_transport = { type = "ws", path = node.ws_path or "/", headers = node.ws_host and { Host = node.ws_host } or nil }
elseif node.transport == "httpupgrade" then
    v2ray_transport = { type = "httpupgrade", host = node.httpupgrade_host, path = node.httpupgrade_path or "/" }
elseif node.transport == "quic" then
    v2ray_transport = { type = "quic" }
elseif node.transport == "grpc" then
    v2ray_transport = { type = "grpc", service_name = node.grpc_serviceName }
end

local inbound = {
    type = node.protocol,
    tag = "inbound",
    listen = (node.bind_local == "1") and "127.0.0.1" or "::",
    listen_port = tonumber(node.port),
}

if node.protocol == "mixed" then
    inbound.users = (node.auth == "1") and { { username = node.username, password = node.password } } or nil
    inbound.set_system_proxy = false
elseif node.protocol == "socks" then
    inbound.users = (node.auth == "1") and { { username = node.username, password = node.password } } or nil
elseif node.protocol == "http" then
    inbound.users = (node.auth == "1") and { { username = node.username, password = node.password } } or nil
    inbound.tls = (node.tls == "1") and tls or nil
elseif node.protocol == "shadowsocks" then
    inbound.method = node.ss_method
    inbound.password = node.password
    inbound.multiplex = mux
elseif node.protocol == "vmess" or node.protocol == "vless" or node.protocol == "trojan" then
    if node.uuid then
        local users = {}
        for _, v in ipairs(type(node.uuid) == "table" and node.uuid or {node.uuid}) do
            if node.protocol == "vmess" then
                table.insert(users, { name = v, uuid = v, alterId = 0 })
            elseif node.protocol == "vless" then
                table.insert(users, { name = v, uuid = v, flow = (node.flow and node.flow ~= "") and node.flow or nil })
            else
                table.insert(users, { name = v, password = v })
            end
        end
        inbound.users = users
        inbound.tls = (node.tls == "1") and tls or nil
        inbound.multiplex = mux
        inbound.transport = v2ray_transport
    end
elseif node.protocol == "naive" then
    inbound.users = { { username = node.username, password = node.password } }
    inbound.tls = tls
elseif node.protocol == "hysteria" then
    inbound.up_mbps = tonumber(node.hysteria_up_mbps)
    inbound.down_mbps = tonumber(node.hysteria_down_mbps)
    inbound.obfs = node.hysteria_obfs
    inbound.users = { { name = "user1", auth = (node.hysteria_auth_type == "base64") and node.hysteria_auth_password or nil, auth_str = (node.hysteria_auth_type == "string") and node.hysteria_auth_password or nil } }
    inbound.recv_window_conn = tonumber(node.hysteria_recv_window_conn)
    inbound.recv_window_client = tonumber(node.hysteria_recv_window_client)
    inbound.max_conn_client = tonumber(node.hysteria_max_conn_client)
    inbound.disable_mtu_discovery = (node.hysteria_disable_mtu_discovery == "1")
    inbound.tls = tls
elseif node.protocol == "tuic" then
    tls.alpn = (node.tuic_alpn and node.tuic_alpn ~= "default") and (function()
        local alpn = {}
        string.gsub(node.tuic_alpn, '[^,]+', function(w) table.insert(alpn, w) end)
        return #alpn > 0 and alpn or nil
    end)() or nil
    inbound.users = { { name = "user1", uuid = type(node.uuid) == "table" and node.uuid[1] or node.uuid, password = node.password } }
    inbound.congestion_control = node.tuic_congestion_control or "cubic"
    inbound.zero_rtt_handshake = (node.tuic_zero_rtt_handshake == "1")
    inbound.heartbeat = (tonumber(node.tuic_heartbeat) or 3) .. "s"
    inbound.tls = tls
elseif node.protocol == "hysteria2" then
    inbound.up_mbps = (node.hysteria2_ignore_client_bandwidth ~= "1") and tonumber(node.hysteria2_up_mbps) or nil
    inbound.down_mbps = (node.hysteria2_ignore_client_bandwidth ~= "1") and tonumber(node.hysteria2_down_mbps) or nil
    inbound.obfs = (node.hysteria2_obfs_type and node.hysteria2_obfs_type ~= "") and { type = node.hysteria2_obfs_type, password = node.hysteria2_obfs_password } or nil
    inbound.users = { { name = "user1", password = node.hysteria2_auth_password } }
    inbound.ignore_client_bandwidth = (node.hysteria2_ignore_client_bandwidth == "1")
    inbound.tls = tls
    if node.hysteria2_realms == "1" then
        inbound.realm = {
            server_url = node.hysteria2_realm_url and "https://" .. node.hysteria2_realm_url or nil,
            stun_servers = type(node.hysteria2_realm_stun) == "table" and node.hysteria2_realm_stun or {node.hysteria2_realm_stun},
            stun_domain_resolver = "direct"
        }
    end
elseif node.protocol == "anytls" then
    inbound.users = { { name = (node.username and node.username ~= "") and node.username or "sekai", password = node.password } }
    inbound.tls = tls
elseif node.protocol == "direct" then
    inbound.network = (node.d_protocol ~= "TCP,UDP") and node.d_protocol or nil
    inbound.override_address = node.d_address
    inbound.override_port = tonumber(node.d_port)
end

local route = {
    rules = {
        { ip_is_private = true, action = (node.accept_lan == "1") and "route" or "reject", outbound = (node.accept_lan == "1") and "direct" or nil }
    }
}

if node.outbound_node_iface and node.outbound_node_iface ~= "" then
    local outbound = { type = "direct", tag = "outbound", bind_interface = node.outbound_node_iface, routing_mark = 255 }
    route.final = outbound.tag
    table.insert(outbounds, 1, outbound)
end

local config = {
    log = { disabled = (node.log == "0"), level = node.loglevel or "info", timestamp = true },
    dns = { servers = { { type = "local", tag = "local" } } },
    inbounds = { inbound },
    outbounds = outbounds,
    route = route
}

local f = io.open(out_file, "w")
if f then
    f:write(jsonc.stringify(config, 1))
    f:close()
end
