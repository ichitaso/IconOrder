DEBUG = 0
GO_EASY_ON_ME = 1
PACKAGE_VERSION = $(THEOS_PACKAGE_BASE_VERSION)
ARCHS = arm64 arm64e

TARGET = iphone:13.0:11.0

THEOS_DEVICE_IP = 0.0.0.0 -p 2222

TWEAK_NAME = IconOrder
$(TWEAK_NAME)_FILES = Tweak.xm
$(TWEAK_NAME)_CFLAGS = -fobjc-arc

include $(THEOS)/makefiles/common.mk
include $(THEOS_MAKE_PATH)/tweak.mk

before-package::
	sudo chown -R root:wheel $(THEOS_STAGING_DIR)
	sudo chmod -R 755 $(THEOS_STAGING_DIR)
	sudo chmod 666 $(THEOS_STAGING_DIR)/DEBIAN/control

after-package::
	make clean
	sudo rm -rf .theos/_

after-install::
	install.exec "killall -9 backboardd"
