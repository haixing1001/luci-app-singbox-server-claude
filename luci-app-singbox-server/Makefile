include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-singbox-server
PKG_VERSION:=2.0.0
PKG_RELEASE:=0

LUCI_TITLE:=LuCI for Standalone Sing-Box Server (PassWall2 UI Replica)
LUCI_PKGARCH:=all
LUCI_DEPENDS:=+luci-base +luci-compat +luci-lib-jsonc

define Package/$(PKG_NAME)/conffiles
/etc/config/singbox_server
endef

include $(TOPDIR)/feeds/luci/luci.mk
