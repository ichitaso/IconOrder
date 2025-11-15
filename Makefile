ARCHS = arm64 arm64e

DEBUG = 0
FINALPACKAGE = 1

INSTALL_TARGET_PROCESSES = SpringBoard

THEOS_DEVICE_IP = 192.168.0.24

ifeq ($(THEOS_PACKAGE_SCHEME),rootless)
TARGET = iphone:16.5:15.0
else ifeq ($(THEOS_PACKAGE_SCHEME),roothide)
TARGET = iphone:16.5:15.0
else
export PREFIX = $(THEOS)/toolchain/Xcode11.xctoolchain/usr/bin/
TARGET = iphone:14.5:12.0
endif

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

after-package::
	rm -f ./layout/DEBIAN/preinst

internal-stage::
	$(ECHO_NOTHING)mv "$(THEOS_STAGING_DIR)/Library/MobileSubstrate/DynamicLibraries/IconOrder.dylib" "$(THEOS_STAGING_DIR)/Library/MobileSubstrate/DynamicLibraries/  IconOrder.dylib" $(ECHO_END)
	$(ECHO_NOTHING)mv "$(THEOS_STAGING_DIR)/Library/MobileSubstrate/DynamicLibraries/IconOrder.plist" "$(THEOS_STAGING_DIR)/Library/MobileSubstrate/DynamicLibraries/  IconOrder.plist" $(ECHO_END)
