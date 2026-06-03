#!/bin/sh

CONFIG=singbox_server
LOGDIR=/tmp/log

json_escape() {
	printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\r//g; :a;N;$!ba;s/\n/\\n/g'
}

rand_uuid() {
	if command -v sing-box >/dev/null 2>&1; then
		sing-box generate uuid 2>/dev/null && return
	fi
	cat /proc/sys/kernel/random/uuid 2>/dev/null
}

rand_pass() {
	tr -dc 'A-Za-z0-9' </dev/urandom 2>/dev/null | head -c 24
}

ensure_secret() {
	local section="$1" proto="$2" uuid password
	config_get uuid "$section" uuid ""
	config_get password "$section" password ""
	case "$proto" in
		vmess|vless)
			[ -n "$uuid" ] || { uuid="$(rand_uuid)"; uci set ${CONFIG}.${section}.uuid="$uuid"; uci commit ${CONFIG}; }
			;;
		tuic)
			[ -n "$uuid" ] || { uuid="$(rand_uuid)"; uci set ${CONFIG}.${section}.uuid="$uuid"; }
			[ -n "$password" ] || { password="$(rand_pass)"; uci set ${CONFIG}.${section}.password="$password"; }
			uci commit ${CONFIG}
			;;
		trojan|hysteria2)
			[ -n "$password" ] || { password="$(rand_pass)"; uci set ${CONFIG}.${section}.password="$password"; uci commit ${CONFIG}; }
			;;
	esac
}

make_tls_json() {
	local section="$1" tls reality server_name cert_path key_path reality_private_key reality_short_id
	config_get_bool tls "$section" tls 0
	config_get_bool reality "$section" reality 0
	[ "$tls" = "1" ] || [ "$reality" = "1" ] || return 0
	config_get server_name "$section" server_name ""
	config_get cert_path "$section" cert_path ""
	config_get key_path "$section" key_path ""
	config_get reality_private_key "$section" reality_private_key ""
	config_get reality_short_id "$section" reality_short_id ""
	server_name="$(json_escape "$server_name")"
	cert_path="$(json_escape "$cert_path")"
	key_path="$(json_escape "$key_path")"
	reality_private_key="$(json_escape "$reality_private_key")"
	reality_short_id="$(json_escape "$reality_short_id")"
	if [ "$reality" = "1" ]; then
		printf ',"tls":{"enabled":true,"server_name":"%s","reality":{"enabled":true,"handshake":{"server":"%s","server_port":443},"private_key":"%s","short_id":["%s"]}}' "$server_name" "$server_name" "$reality_private_key" "$reality_short_id"
	else
		printf ',"tls":{"enabled":true,"server_name":"%s","certificate_path":"%s","key_path":"%s"}' "$server_name" "$cert_path" "$key_path"
	fi
}

make_transport_json() {
	local section="$1" protocol="$2" transport ws_host ws_path grpc_service_name
	config_get transport "$section" transport "tcp"
	[ "$protocol" = "hysteria2" ] || [ "$protocol" = "tuic" ] && return 0
	case "$transport" in
		ws)
			config_get ws_host "$section" ws_host ""
			config_get ws_path "$section" ws_path "/"
			ws_host="$(json_escape "$ws_host")"
			ws_path="$(json_escape "$ws_path")"
			if [ -n "$ws_host" ]; then
				printf ',"transport":{"type":"ws","path":"%s","headers":{"Host":"%s"}}' "$ws_path" "$ws_host"
			else
				printf ',"transport":{"type":"ws","path":"%s"}' "$ws_path"
			fi
			;;
		grpc)
			config_get grpc_service_name "$section" grpc_service_name "grpc"
			grpc_service_name="$(json_escape "$grpc_service_name")"
			printf ',"transport":{"type":"grpc","service_name":"%s"}' "$grpc_service_name"
			;;
	esac
}

gen_config() {
	local section="$1" out="$2"
	config_load "$CONFIG"
	local protocol listen_port listen log custom_config custom_json uuid password remarks
	config_get protocol "$section" protocol "vmess"
	config_get listen_port "$section" listen_port "4566"
	config_get_bool local_listen "$section" local_listen 0
	config_get_bool log "$section" log 0
	config_get_bool custom_config "$section" custom_config 0
	config_get custom_json "$section" custom_json ""
	config_get remarks "$section" remarks "$section"

	mkdir -p "$(dirname "$out")" "$LOGDIR"
	if [ "$custom_config" = "1" ] && [ -n "$custom_json" ]; then
		printf '%s\n' "$custom_json" > "$out"
		return $?
	fi

	ensure_secret "$section" "$protocol"
	config_load "$CONFIG"
	config_get uuid "$section" uuid ""
	config_get password "$section" password ""
	[ "$local_listen" = "1" ] && listen="127.0.0.1" || listen="::"
	uuid="$(json_escape "$uuid")"
	password="$(json_escape "$password")"
	remarks="$(json_escape "$remarks")"

	{
		printf '{\n'
		if [ "$log" = "1" ]; then
			printf '  "log":{"level":"info","output":"/tmp/log/singbox_server_%s.log","timestamp":true},\n' "$section"
		else
			printf '  "log":{"disabled":true},\n'
		fi
		printf '  "inbounds":[{'
		case "$protocol" in
			vmess)
				printf '"type":"vmess","tag":"%s","listen":"%s","listen_port":%s,"users":[{"uuid":"%s","alterId":0}]' "$remarks" "$listen" "$listen_port" "$uuid"
				;;
			vless)
				printf '"type":"vless","tag":"%s","listen":"%s","listen_port":%s,"users":[{"uuid":"%s"}]' "$remarks" "$listen" "$listen_port" "$uuid"
				;;
			trojan)
				printf '"type":"trojan","tag":"%s","listen":"%s","listen_port":%s,"users":[{"password":"%s"}]' "$remarks" "$listen" "$listen_port" "$password"
				;;
			hysteria2)
				printf '"type":"hysteria2","tag":"%s","listen":"%s","listen_port":%s,"users":[{"password":"%s"}]' "$remarks" "$listen" "$listen_port" "$password"
				;;
			tuic)
				printf '"type":"tuic","tag":"%s","listen":"%s","listen_port":%s,"users":[{"uuid":"%s","password":"%s"}]' "$remarks" "$listen" "$listen_port" "$uuid" "$password"
				;;
			esac
		make_tls_json "$section"
		make_transport_json "$section" "$protocol"
		printf '}],\n'
		printf '  "outbounds":[{"type":"direct","tag":"direct"}],\n'
		printf '  "route":{"final":"direct"}\n'
		printf '}\n'
	} > "$out"
}

case "$1" in
	gen)
		gen_config "$2" "$3"
		;;
	*)
		echo "Usage: $0 gen <section> <output>" >&2
		exit 1
		;;
esac
