ARCHS = arm64
DEBUG = 0
FINALPACKAGE = 1
FOR_RELEASE = 1

TARGET = iphone:latest:14.5
include $(THEOS)/makefiles/common.mk

TWEAK_NAME = AWSS3

HOOK_SRC = $(wildcard hook/*.c)
IMGUI_SRC = $(wildcard imgui/*.cpp) $(wildcard imgui/*.mm)
LOAD_SRC = $(wildcard load/*.mm) $(wildcard load/*.m)

AWSS3_FRAMEWORKS = UIKit SafariServices Accelerate Foundation QuartzCore CoreGraphics AudioToolbox CoreText Metal MobileCoreServices Security SystemConfiguration IOKit CoreTelephony CoreImage CFNetwork AdSupport AVFoundation

AWSS3_LDFLAGS += -lresolv -lz -liconv hook/Ryoma.a

AWSS3_CCFLAGS = -std=c++17 -fno-rtti -fno-exceptions -DNDEBUG \
    -Wall \
    -Wno-deprecated-declarations \
    -Wno-unused-variable \
    -Wno-unused-value \
    -Wno-unused-function \
    -fvisibility=hidden \
    -fexceptions

AWSS3_CFLAGS = -fobjc-arc \
    -Wall \
    -Wno-deprecated-declarations \
    -Wno-unused-variable \
    -Wno-unused-value \
    -Wno-unused-function \
    -fvisibility=hidden

# SSZipArchive minizip: suppress old-C warnings
helper/SSZipArchive/minizip/ioapi.m_CFLAGS = -Wno-deprecated-non-prototype -Wno-error
helper/SSZipArchive/minizip/zip.m_CFLAGS   = -Wno-unused-but-set-variable -Wno-error
helper/SSZipArchive/minizip/unzip.m_CFLAGS = -Wno-error

HELPER_SRC = helper/ModFile.m \
    helper/VideoSanh.m \
    helper/SSZipArchive/SSZipArchive.m \
    $(wildcard helper/SSZipArchive/minizip/*.m)

AWSS3_FILES = ImGuiDrawView.mm \
    helper/FakeEnc.xm \
    $(HELPER_SRC) \
    $(HOOK_SRC) \
    $(LOAD_SRC) \
    $(IMGUI_SRC)

include $(THEOS_MAKE_PATH)/tweak.mk