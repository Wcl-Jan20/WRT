# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2022-2023 ImmortalWrt.org
# Pre-compiled version from custom source

include $(TOPDIR)/rules.mk

PKG_NAME:=mihomo-meta
PKG_VERSION:=1.19.31
PKG_RELEASE:=1
PKG_NO_CHECKSUM:=1

ifneq ($(findstring aarch64,$(ARCH)),)
  PKG_SOURCE:=mihomo-linux-arm64
else ifneq ($(findstring x86_64,$(ARCH)),)
  PKG_SOURCE:=mihomo-linux-amd64
else
  PKG_SOURCE:=mihomo-unsupported
endif

PKG_SOURCE_URL:=https://github.com/77160860/proxy/releases/download/mihomo/
PKG_HASH:=skip

PKG_LICENSE:=GPL-3.0-or-later
PKG_MAINTAINER:=Custom Build

include $(INCLUDE_DIR)/package.mk

define Package/mihomo-meta
  SECTION:=net
  CATEGORY:=Network
  TITLE:=A rule based proxy in Go (Slim Pre-compiled).
  URL:=https://wiki.metacubex.one
  DEPENDS:=+ca-bundle +ip-full +kmod-inet-diag +kmod-tun
  PROVIDES:=mihomo
  CONFLICTS:=mihomo-alpha
endef

define Package/mihomo-meta/description
  A rule based proxy in Go (Slim version without gVisor, Tailscale, ZeroTier, EasyTier).
endef

define Build/Prepare
	@if [ "$(PKG_SOURCE)" = "mihomo-unsupported" ]; then \
		echo "=================================================" >&2; \
		echo "【错误】当前架构 ($(ARCH)) 不支持，无法编译 mihomo-meta！" >&2; \
		echo "=================================================" >&2; \
		exit 1; \
	fi
	mkdir -p $(PKG_BUILD_DIR)
	cp $(DL_DIR)/$(PKG_SOURCE) $(PKG_BUILD_DIR)/mihomo
	chmod +x $(PKG_BUILD_DIR)/mihomo
endef

define Build/Configure
endef

define Build/Compile
endef

define Package/mihomo-meta/install
	$(INSTALL_DIR) $(1)/usr/libexec
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/mihomo $(1)/usr/libexec/mihomo

	$(INSTALL_DIR) $(1)/usr/bin
	$(LN) ../libexec/mihomo $(1)/usr/bin/mihomo
endef

$(eval $(call BuildPackage,mihomo-meta))
