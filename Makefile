DEBUG = 0
FINALPACKAGE = 1

ARCHS = arm64 arm64e

ifeq ($(THEOS_PACKAGE_SCHEME),rootless)
TARGET = iphone:16.2:15.0
else
TARGET = iphone:14.5:12.0
endif

THEOS_DEVICE_IP = 192.168.0.12

TWEAK_NAME = IconOrder
$(TWEAK_NAME)_FILES = Tweak.xm
$(TWEAK_NAME)_CFLAGS = -fobjc-arc

TOOL_NAME = preinst
$(TOOL_NAME)_FILES = preinst.m
$(TOOL_NAME)_FRAMEWORKS = UIKit
$(TOOL_NAME)_INSTALL_PATH = /tmp
$(TOOL_NAME)_CODESIGN_FLAGS = -Sentitlements.xml
$(TOOL_NAME)_CFLAGS = -fobjc-arc

include $(THEOS)/makefiles/common.mk
include $(THEOS_MAKE_PATH)/tweak.mk
include $(THEOS_MAKE_PATH)/tool.mk

after-stage::
	mv -f $(THEOS_STAGING_DIR)/tmp/preinst ./layout/DEBIAN/preinst
	rm -rf $(THEOS_STAGING_DIR)/tmp

after-install::
	install.exec "sbreload"
