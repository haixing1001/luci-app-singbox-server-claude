include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-singbox-server
PKG_VERSION:=1.0.4
PKG_RELEASE:=0

LUCI_TITLE:=LuCI support for Standalone Sing-Box Server
LUCI_PKGARCH:=all
LUCI_DEPENDS:=+luci-base +luci-compat +luci-lib-jsonc

define Package/$(PKG_NAME)/conffiles
/etc/config/singbox_server
endef

include $(TOPDIR)/feeds/luci/luci.mk

# call BuildPackage - OpenWrt buildroot signature
