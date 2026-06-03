/**
 * luci-app-singbox-server — main.js
 * LuCI view for Sing-Box server-side proxy management (OpenWrt 25.12)
 *
 * Mirrors the Passwall2-style UI:
 *   • Server list table with status indicators and per-row actions
 *   • Full configuration modal (protocol, transport, TLS, etc.)
 *   • Real-time log viewer with per-server and global view
 */
'use strict';
'require view';
'require form';
'require uci';
'require rpc';
'require ui';
'require dom';
'require poll';
'require fs';

/* ── RPC helpers ─────────────────────────────────────────────────────── */

var callServiceList = rpc.declare({
	object: 'service',
	method: 'list',
	params: ['name'],
	expect: { '': {} }
});

var callServiceSet = rpc.declare({
	object: 'service',
	method: 'set',
	params: ['name', 'instances']
});

var callServiceStart = rpc.declare({
	object: 'rc',
	method: 'start',
	params: ['name']
});

var callServiceStop = rpc.declare({
	object: 'rc',
	method: 'stop',
	params: ['name']
});

/* ── Helpers ─────────────────────────────────────────────────────────── */

function isServiceRunning(data) {
	try {
		var svc = data['singbox_server'];
		return svc && svc.instances &&
		       Object.keys(svc.instances).length > 0;
	} catch(e) { return false; }
}

function badge(ok) {
	return E('span', {
		'class': 'label ' + (ok ? 'label-success' : 'label-danger'),
		'style': 'font-size:1em;padding:2px 8px;border-radius:3px;' +
		         'color:#fff;background:' + (ok ? '#4caf50' : '#e53935')
	}, ok ? '✔ 运行中' : '✖ 未运行');
}

/* ── View ────────────────────────────────────────────────────────────── */

return view.extend({

	/* polling handle stored per instance */
	_logPoll: null,

	/* ---- data load --------------------------------------------------- */
	load: function() {
		return Promise.all([
			uci.load('singbox_server'),
			L.resolveDefault(callServiceList('singbox_server'), {})
		]);
	},

	/* ---- service control buttons ------------------------------------- */
	handleServiceAction: function(action) {
		var cmds = {
			start:   ['/etc/init.d/singbox_server', 'start'],
			stop:    ['/etc/init.d/singbox_server', 'stop'],
			restart: ['/etc/init.d/singbox_server', 'restart']
		};
		var labels = { start:'启动', stop:'停止', restart:'重启' };

		return fs.exec(cmds[action][0], [cmds[action][1]])
			.then(function() {
				ui.addNotification(null,
					E('p', _('Sing-Box 服务已' + labels[action])), 'info');
			})
			.catch(function(err) {
				ui.addNotification(null,
					E('p', _('操作失败: ') + err.message), 'error');
			});
	},

	/* ---- per-server log modal ---------------------------------------- */
	handleServerLog: function(section_id) {
		var remarks = uci.get('singbox_server', section_id, 'remarks') || section_id;
		var pre = E('pre', {
			'style': 'max-height:400px;overflow:auto;background:#111;' +
			         'color:#0f0;padding:10px;font-size:12px;line-height:1.4'
		}, [ _('加载日志中…') ]);

		ui.showModal(_('节点日志：') + remarks, [
			pre,
			E('div', { 'class': 'right' }, [
				E('button', {
					'class': 'btn',
					'click': function() {
						fs.read('/var/log/singbox_server.log')
							.then(function(data) {
								var tag = 'in-.*-' + section_id;
								var lines = (data || '').split('\n')
									.filter(function(l) {
										return l.indexOf(section_id) !== -1;
									});
								pre.textContent = lines.length
									? lines.join('\n')
									: _('该节点暂无日志记录');
							});
					}
				}, _('刷新')),
				E('button', {
					'class': 'btn cbi-button',
					'click': ui.hideModal
				}, _('关闭'))
			])
		]);

		/* initial load */
		fs.read('/var/log/singbox_server.log')
			.then(function(data) {
				var lines = (data || '').split('\n')
					.filter(function(l) { return l.indexOf(section_id) !== -1; });
				pre.textContent = lines.length
					? lines.join('\n')
					: _('该节点暂无日志记录');
			})
			.catch(function() {
				pre.textContent = _('无法读取日志文件');
			});
	},

	/* ---- log section renderer ---------------------------------------- */
	renderLogSection: function() {
		var self = this;

		var textarea = E('textarea', {
			'id': 'sbsrv_log_view',
			'readonly': true,
			'spellcheck': 'false',
			'style': [
				'width:100%', 'height:280px',
				'font-family:monospace', 'font-size:12px',
				'background:#0e0e0e', 'color:#39ff14',
				'border:1px solid #444', 'padding:8px',
				'resize:vertical', 'line-height:1.45'
			].join(';')
		}, [ _('日志加载中…') ]);

		var clearBtn = E('button', {
			'class': 'btn cbi-button-negative',
			'style': 'margin-bottom:6px',
			'click': function() {
				return fs.write('/var/log/singbox_server.log', '')
					.then(function() { textarea.value = ''; });
			}
		}, _('清空日志'));

		/* auto-refresh */
		if (self._logPoll) poll.remove(self._logPoll);
		self._logPoll = poll.add(function() {
			return L.resolveDefault(fs.read('/var/log/singbox_server.log'), '')
				.then(function(content) {
					var el = document.getElementById('sbsrv_log_view');
					if (!el) return;
					var atBottom = el.scrollTop + el.clientHeight >= el.scrollHeight - 5;
					el.value = content || _('暂无日志');
					if (atBottom) el.scrollTop = el.scrollHeight;
				});
		}, 3);

		return E('div', { 'class': 'cbi-section' }, [
			E('h3', {}, _('日志')),
			E('div', { 'class': 'cbi-section-node' }, [ clearBtn, textarea ])
		]);
	},

	/* ---- status bar -------------------------------------------------- */
	renderStatusBar: function(running) {
		var self = this;

		var statusWrap = E('span', { 'id': 'sbsrv_status_badge' }, [ badge(running) ]);

		/* refresh badge every 5 s */
		poll.add(function() {
			return L.resolveDefault(callServiceList('singbox_server'), {})
				.then(function(d) {
					var el = document.getElementById('sbsrv_status_badge');
					if (!el) return;
					dom.content(el, [ badge(isServiceRunning(d)) ]);
				});
		}, 5);

		return E('div', {
			'style': 'display:flex;align-items:center;gap:10px;margin-bottom:12px'
		}, [
			E('strong', {}, _('服务状态：')),
			statusWrap,
			E('button', {
				'class': 'btn cbi-button-action',
				'click': function() { return self.handleServiceAction('start'); }
			}, _('启动')),
			E('button', {
				'class': 'btn cbi-button-negative',
				'click': function() { return self.handleServiceAction('stop'); }
			}, _('停止')),
			E('button', {
				'class': 'btn',
				'click': function() { return self.handleServiceAction('restart'); }
			}, _('重启'))
		]);
	},

	/* ================================================================== */
	/* render                                                              */
	/* ================================================================== */
	render: function(data) {
		var self    = this;
		var svcData = data[1] || {};
		var running = isServiceRunning(svcData);

		var m, s, o;

		m = new form.Map('singbox_server', _('Sing-Box 服务端'),
			_('Sing-Box 代理服务端管理 — 支持 VMess / VLESS / Shadowsocks / Trojan / Hysteria2 / TUIC'));

		/* ── Global section ──────────────────────────────────────────── */
		s = m.section(form.NamedSection, 'global', 'global', _('全局设置'));
		s.anonymous  = true;
		s.addremove  = false;

		o = s.option(form.Flag, 'enabled', _('启用'));
		o.rmempty = false;

		o = s.option(form.ListValue, 'log_level', _('日志级别'));
		o.value('trace',   'trace');
		o.value('debug',   'debug');
		o.value('info',    'info');
		o.value('warn',    'warn');
		o.value('error',   'error');
		o.value('fatal',   'fatal');
		o.value('panic',   'panic');
		o.default = 'warn';

		o = s.option(form.Value, 'log_output', _('日志文件'));
		o.placeholder = '/var/log/singbox_server.log';
		o.datatype    = 'string';

		/* ── Servers / User Management ───────────────────────────────── */
		s = m.section(form.GridSection, 'server', _('用户管理'));
		s.addremove     = true;
		s.sortable      = true;
		s.anonymous     = true;
		s.nodescriptions = false;
		s.addbtntitle   = _('添加');
		s.extedit       = false;

		s.modaltitle = function(section_id) {
			var r = uci.get('singbox_server', section_id, 'remarks');
			return _('服务器配置') + (r ? ' — ' + r : '');
		};

		/* Add custom "日志" button before the standard Edit/Delete */
		s.renderRowActions = function(section_id) {
			/* call parent to get standard buttons (Edit, Delete, Up, Down) */
			var tdEl = this.super('renderRowActions', [section_id]);

			var logBtn = E('button', {
				'class': 'btn cbi-button cbi-button-action',
				'style': 'margin-right:4px',
				'click': ui.createHandlerFn(self, 'handleServerLog', section_id)
			}, _('日志'));

			tdEl.insertBefore(logBtn, tdEl.firstChild);
			return tdEl;
		};

		/* ════ Table columns (visible in list view) ════ */

		o = s.option(form.Flag, 'enabled', _('启用'));
		o.default  = '1';
		o.editable = true;
		o.rmempty  = false;

		/* Status indicator (read-only, not in modal) */
		o = s.option(form.DummyValue, '_status', _('状态'));
		o.rawhtml    = true;
		o.modalonly  = false;
		o.cfgvalue   = function(section_id) {
			var en = uci.get('singbox_server', section_id, 'enabled');
			if (en === '1' && running) {
				return '<span style="color:#4caf50;font-weight:bold;font-size:1.1em">✓</span>';
			}
			return '<span style="color:#e53935;font-weight:bold;font-size:1.1em">✗</span>';
		};

		o = s.option(form.Value, 'remarks', _('备注'));
		o.placeholder = _('备注');

		/* Type label (read-only, not in modal) */
		o = s.option(form.DummyValue, '_type', _('类型'));
		o.rawhtml   = false;
		o.modalonly = false;
		o.cfgvalue  = function(sid) {
			var p = uci.get('singbox_server', sid, 'protocol') || 'vmess';
			var map = {
				vmess:'VMess', vless:'VLESS', shadowsocks:'Shadowsocks',
				trojan:'Trojan', hysteria2:'Hysteria2', tuic:'TUIC'
			};
			return 'Sing-Box ' + (map[p] || p.charAt(0).toUpperCase() + p.slice(1));
		};

		o = s.option(form.Value, 'port', _('端口'));
		o.datatype    = 'port';
		o.placeholder = '10086';

		/* Log-enable checkbox (editable inline in table) */
		o = s.option(form.Flag, 'log', _('日志'));
		o.rmempty  = false;
		o.editable = true;

		/* ════ Modal-only configuration fields ════ */

		/* Use custom raw JSON config */
		o = s.option(form.Flag, 'custom_config', _('使用自定义配置'));
		o.rmempty   = false;
		o.modalonly = true;

		o = s.option(form.TextValue, 'custom_config_content', _('自定义配置 (JSON)'));
		o.modalonly   = true;
		o.rows        = 12;
		o.placeholder = '{\n  "type": "vmess",\n  "tag": "in-vmess",\n  "listen": "::",\n  "listen_port": 10086,\n  ...\n}';
		o.depends('custom_config', '1');

		/* ---- Core settings (hidden when custom_config = 1) ----------- */

		o = s.option(form.ListValue, 'protocol', _('协议'));
		o.modalonly = true;
		o.depends('custom_config', '0');
		o.depends('custom_config', '');
		o.value('vmess',       'VMess');
		o.value('vless',       'VLESS');
		o.value('shadowsocks', 'Shadowsocks');
		o.value('trojan',      'Trojan');
		o.value('hysteria2',   'Hysteria2');
		o.value('tuic',        'TUIC v5');
		o.default = 'vmess';

		o = s.option(form.Value, 'uuid', _('ID / 密码'));
		o.modalonly   = true;
		o.placeholder = _('UUID（VMess/VLESS/TUIC）或密码（Shadowsocks/Trojan/Hysteria2）');
		o.depends('custom_config', '0');
		o.depends('custom_config', '');

		/* Shadowsocks cipher */
		o = s.option(form.ListValue, 'ss_method', _('加密方式'));
		o.modalonly = true;
		o.depends({ 'protocol': 'shadowsocks', 'custom_config': '0' });
		o.depends({ 'protocol': 'shadowsocks', 'custom_config': '' });
		o.value('2022-blake3-aes-128-gcm',          '2022-blake3-aes-128-gcm');
		o.value('2022-blake3-aes-256-gcm',          '2022-blake3-aes-256-gcm');
		o.value('2022-blake3-chacha20-poly1305',    '2022-blake3-chacha20-poly1305');
		o.value('aes-128-gcm',                       'aes-128-gcm');
		o.value('aes-256-gcm',                       'aes-256-gcm');
		o.value('chacha20-ietf-poly1305',            'chacha20-ietf-poly1305');
		o.default = 'aes-256-gcm';

		/* TLS */
		o = s.option(form.Flag, 'tls', _('TLS'));
		o.rmempty   = false;
		o.modalonly = true;
		o.depends('custom_config', '0');
		o.depends('custom_config', '');

		o = s.option(form.Value, 'tls_cert', _('TLS 证书路径'));
		o.modalonly   = true;
		o.placeholder = '/etc/ssl/certs/fullchain.pem';
		o.depends({ 'tls': '1', 'custom_config': '0' });
		o.depends({ 'tls': '1', 'custom_config': '' });

		o = s.option(form.Value, 'tls_key', _('TLS 私钥路径'));
		o.modalonly   = true;
		o.placeholder = '/etc/ssl/private/privkey.pem';
		o.depends({ 'tls': '1', 'custom_config': '0' });
		o.depends({ 'tls': '1', 'custom_config': '' });

		o = s.option(form.Value, 'tls_sni', _('域名 (SNI)'));
		o.modalonly   = true;
		o.placeholder = 'example.com';
		o.depends({ 'tls': '1', 'custom_config': '0' });
		o.depends({ 'tls': '1', 'custom_config': '' });

		/* Transport */
		o = s.option(form.ListValue, 'transport', _('传输方式'));
		o.modalonly = true;
		o.depends('custom_config', '0');
		o.depends('custom_config', '');
		o.value('tcp',  'TCP');
		o.value('ws',   'WebSocket');
		o.value('grpc', 'gRPC');
		o.value('http', 'HTTP/2');
		o.default = 'tcp';

		o = s.option(form.Value, 'ws_host', _('WebSocket Host'));
		o.modalonly   = true;
		o.placeholder = 'example.com';
		o.depends({ 'transport': 'ws', 'custom_config': '0' });
		o.depends({ 'transport': 'ws', 'custom_config': '' });

		o = s.option(form.Value, 'ws_path', _('WebSocket Path'));
		o.modalonly   = true;
		o.placeholder = '/';
		o.depends({ 'transport': 'ws', 'custom_config': '0' });
		o.depends({ 'transport': 'ws', 'custom_config': '' });

		o = s.option(form.Value, 'grpc_service_name', _('gRPC 服务名'));
		o.modalonly   = true;
		o.placeholder = 'GunService';
		o.depends({ 'transport': 'grpc', 'custom_config': '0' });
		o.depends({ 'transport': 'grpc', 'custom_config': '' });

		/* Advanced flags */
		o = s.option(form.Flag, 'final_mask', _('FinalMask'));
		o.rmempty   = false;
		o.modalonly = true;
		o.depends('custom_config', '0');
		o.depends('custom_config', '');

		o = s.option(form.Flag, 'accept_proxy_protocol', _('acceptProxyProtocol'));
		o.rmempty     = false;
		o.modalonly   = true;
		o.description = _('是否接收 PROXY protocol，当该节点要被回落或被代理转发时，必须启用，否则不能使用。');
		o.depends('custom_config', '0');
		o.depends('custom_config', '');

		o = s.option(form.Flag, 'tcp_fast_open', _('TCP 快速打开'));
		o.rmempty   = false;
		o.modalonly = true;
		o.depends('custom_config', '0');
		o.depends('custom_config', '');

		o = s.option(form.Flag, 'local_only', _('本机监听'));
		o.rmempty     = false;
		o.modalonly   = true;
		o.description = _('当勾选时，只能本机访问。');
		o.depends('custom_config', '0');
		o.depends('custom_config', '');

		/* ── Render everything ───────────────────────────────────────── */
		return m.render().then(function(mapEl) {
			return E('div', {}, [
				self.renderStatusBar(running),
				mapEl,
				self.renderLogSection()
			]);
		});
	},

	/* cleanup polls when navigating away */
	handleSaveApply: function(mode) {
		return this.super('handleSaveApply', [mode])
			.then(function() {
				/* trigger config regen + service reload */
				return fs.exec('/etc/init.d/singbox_server', ['reload'])
					.catch(function() {});
			});
	}
});
