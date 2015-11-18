TWEAK_NAME = IconBundles

IconBundles_FILES = Tweak.xm
IconBundles_FRAMEWORKS = UIKit
IconBundles_LDFLAGS += -Wl,-segalign,4000

export TARGET = iphone:8.1:5.0
export ARCHS = armv7 arm64
export PACKAGE_VERSION = $(THEOS_PACKAGE_BASE_VERSION)
# export PACKAGE_VERSION = $(THEOS_PACKAGE_BASE_VERSION).$(VERSION.INC_BUILD_NUMBER)
export INSTALL_TARGET_PROCESSES = SpringBoard

include theos/makefiles/common.mk
include $(THEOS_MAKE_PATH)/tweak.mk
