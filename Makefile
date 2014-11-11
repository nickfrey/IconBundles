TWEAK_NAME = IconBundles
IconBundles_FILES = Tweak.xm
IconBundles_FRAMEWORKS = UIKit
TARGET = iphone:8.1:5.0
ARCHS = armv7 arm64

include theos/makefiles/common.mk
include $(THEOS_MAKE_PATH)/tweak.mk
