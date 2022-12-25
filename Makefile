DEBUG = 0
GO_EASY_ON_ME = 1
FINALPACKAGE = 1
PACKAGE_VERSION = $(THEOS_PACKAGE_BASE_VERSION)
ARCHS = arm64 arm64e

TARGET = iphone:13.0:11.0
export PREFIX = $(THEOS)/toolchain/Xcode11.xctoolchain/usr/bin/

THEOS_DEVICE_IP = 0.0.0.0 -p 2222

TWEAK_NAME = IconOrder
$(TWEAK_NAME)_FILES = Tweak.xm
$(TWEAK_NAME)_CFLAGS = -fobjc-arc

include $(THEOS)/makefiles/common.mk
include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "sbreload"
