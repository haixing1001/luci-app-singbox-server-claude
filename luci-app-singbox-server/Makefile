include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-singbox-server
PKG_VERSION:=1.0.0
PKG_RELEASE:=0

include $(INCLUDE_DIR)/package.mk

define Package/luci-app-singbox-server
	SECTION:=luci
	CATEGORY:=LuCI
	SUBMENU:=3. Applications
	TITLE:=LuCI App for Sing-Box Server
	DEPENDS:=+luci-base
	PKGARCH:=all
endef

define Package/luci-app-singbox-server/description
  LuCI web interface for Sing-Box server-side proxy management.
  Supports VMess, VLESS, Shadowsocks, Trojan, Hysteria2 and TUIC protocols
  with WebSocket/gRPC/HTTP2 transport, TLS, and per-node logging.
endef

define Build/Prepare
endef

define Build/Configure
endef

define Build/Compile
endef

define Package/luci-app-singbox-server/install
	$(INSTALL_DIR) $(1)/usr/share/luci/menu.d
	$(INSTALL_DATA) ./root/usr/share/luci/menu.d/luci-app-singbox-server.json \
		$(1)/usr/share/luci/menu.d/

	$(INSTALL_DIR) $(1)/usr/share/rpcd/acl.d
	$(INSTALL_DATA) ./root/usr/share/rpcd/acl.d/luci-app-singbox-server.json \
		$(1)/usr/share/rpcd/acl.d/

	$(INSTALL_DIR) $(1)/www/luci-static/resources/view/singbox_server
	$(INSTALL_DATA) ./htdocs/luci-static/resources/view/singbox_server/main.js \
		$(1)/www/luci-static/resources/view/singbox_server/

	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_CONF) ./root/etc/config/singbox_server $(1)/etc/config/

	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./root/etc/init.d/singbox_server $(1)/etc/init.d/

	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) ./root/usr/bin/singbox-server-ctl $(1)/usr/bin/
endef

$(eval $(call BuildPackage,luci-app-singbox-server))
