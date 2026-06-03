include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-singbox-server
PKG_VERSION:=1.0.0
PKG_RELEASE:=0

LUCI_TITLE:=LuCI support for sing-box server
LUCI_DEPENDS:=+sing-box +luci-compat +luci-lib-jsonc
LUCI_PKGARCH:=all

include $(TOPDIR)/feeds/luci/luci.mk

# call BuildPackage - OpenWrt buildroot signature
