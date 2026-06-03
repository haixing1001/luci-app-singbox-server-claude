#!/bin/sh

. /lib/functions.sh

CONFIG="singbox_server"
TMP_DIR="/tmp/etc/singbox_server"
RUN_DIR="/var/run/singbox_server"
MAIN_LOG="/tmp/log/singbox_server.log"
GEN="/usr/share/singbox-server/gen_config.lua"

log() {
	mkdir -p /tmp/log
	echo "$(date '+%Y-%m-%d %H:%M:%S') $*" >> "$MAIN_LOG"
}

get_bin() {
	local bin
	config_get bin global bin_path "/usr/bin/sing-box"
	echo "$bin"
}

start_user() {
	local section="$1"
	local enabled remarks port json logfile bin pidfile

	config_get_bool enabled "$section" enabled 0
	[ "$enabled" = "1" ] || return 0

	config_get remarks "$section" remarks "$section"
	config_get port "$section" listen_port

	bin="$(get_bin)"
	json="$TMP_DIR/${section}.json"
	logfile="$TMP_DIR/${section}.log"
	pidfile="$RUN_DIR/${section}.pid"

	lua "$GEN" "$section" > "$json"
	if [ ! -s "$json" ]; then
		log "[$remarks] 配置生成失败"
		return 1
	fi

	"$bin" check -c "$json" >> "$MAIN_LOG" 2>&1
	if [ "$?" != "0" ]; then
		log "[$remarks] 配置检查失败，请查看主日志"
		return 1
	fi

	procd_open_instance "$section"
	procd_set_param command "$bin" run -c "$json"
	procd_set_param stdout 1
	procd_set_param stderr 1
	procd_set_param respawn
	procd_set_param pidfile "$pidfile"
	procd_set_param file "$json"
	procd_close_instance

	: > "$logfile"
	log "[$remarks] 已启动，端口：$port，配置：$json"
}

start() {
	local enabled bin
	mkdir -p "$TMP_DIR" "$RUN_DIR" /tmp/log
	: > "$MAIN_LOG"

	config_load "$CONFIG"
	config_get_bool enabled global enabled 0
	[ "$enabled" = "1" ] || {
		log "全局开关未启用"
		return 0
	}

	bin="$(get_bin)"
	[ -x "$bin" ] || {
		log "未找到 sing-box：$bin"
		return 1
	}

	config_foreach start_user user
}

stop() {
	local pidfile pid
	for pidfile in "$RUN_DIR"/*.pid; do
		[ -f "$pidfile" ] || continue
		pid="$(cat "$pidfile" 2>/dev/null)"
		[ -n "$pid" ] && kill "$pid" 2>/dev/null
	done
	rm -rf "$TMP_DIR" "$RUN_DIR"
	log "已停止所有 sing-box 服务端实例"
}

restart() {
	stop
	sleep 1
	start
}

case "$1" in
	start) start ;;
	stop) stop ;;
	restart) restart ;;
	*) echo "Usage: $0 {start|stop|restart}" ;;
esac
