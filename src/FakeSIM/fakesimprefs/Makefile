export THEOS_PACKAGE_SCHEME = rootless
ARCHS = arm64 arm64e
include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = FakeSIMPrefs
FakeSIMPrefs_FILES = FSPRootListController.m
FakeSIMPrefs_FRAMEWORKS = UIKit
FakeSIMPrefs_PRIVATE_FRAMEWORKS = Preferences
FakeSIMPrefs_INSTALL_PATH = /Library/PreferenceBundles
FakeSIMPrefs_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/bundle.mk
