TWEAK_NAME = IconBundles

IconBundles_FILES = Tweak.xm
IconBundles_FRAMEWORKS = UIKit
IconBundles_LDFLAGS += -Wl,-segalign,4000

TARGET = iphone:8.1:5.0
ARCHS = armv7 arm64
PACKAGE_VERSION = $(THEOS_PACKAGE_BASE_VERSION).$(VERSION.INC_BUILD_NUMBER)

include theos/makefiles/common.mk
include $(THEOS_MAKE_PATH)/tweak.mk
