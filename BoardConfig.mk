#
# SPDX-FileCopyrightText: The LineageOS Project
# SPDX-License-Identifier: Apache-2.0
#

# Go 7 on the 6.18 kernel (android17-6.18 ACK + kernel/mainline/patches), open userspace stack modelled on
# AOSP's device/linaro/dragonboard (db845c / linaro_swr). Draft: not built yet.

DEVICE_PATH := device/onyx/Go7ml

# A/B: same partitions as the stock GPT and device/onyx/Go7 (no vendor_boot / init_boot on this unit)
AB_OTA_UPDATER := true
AB_OTA_PARTITIONS += \
    boot \
    dtbo \
    product \
    system \
    system_ext \
    vbmeta \
    vbmeta_system \
    vendor

# Architecture (A55 + A77)
TARGET_ARCH := arm64
TARGET_ARCH_VARIANT := armv8-2a-dotprod
TARGET_CPU_ABI := arm64-v8a
TARGET_CPU_VARIANT := cortex-a76

TARGET_BOOTLOADER_BOARD_NAME := Go7
TARGET_BOARD_PLATFORM := sm7225
TARGET_NO_BOOTLOADER := true

# Kernel: built from source
TARGET_KERNEL_SOURCE := kernel/onyx/sm7225-6.18
TARGET_KERNEL_CONFIG := \
    gki_defconfig \
    vendor/onyx/go7-android.config \
    vendor/onyx/go7-drivers.config \
    vendor/onyx/go7-eink.config \
    vendor/onyx/go7-charger.config \
    vendor/onyx/go7-audio.config
# Lineage builds kernels with clang and LLVM=1 by default (vendor/lineage/config/BoardConfigKernel.mk).
# Uncompressed like stock: the ABL path the stock kernel takes (ABL can also gunzip, untested here).
BOARD_KERNEL_IMAGE_NAME := Image
TARGET_KERNEL_EXT_MODULE_ROOT := hardware/onyx/eink
TARGET_KERNEL_EXT_MODULES := kernel:kbuild
TARGET_KERNEL_ADDITIONAL_FLAGS := MO=$(abspath $(PRODUCT_OUT))/obj/KERNEL_EXT_OBJ
EINK_KERNEL_MODULES := onyx-go7-tcon.ko panel-onyx-go7-eink.ko onyx-epd.ko
BOARD_VENDOR_KERNEL_MODULES_LOAD := $(EINK_KERNEL_MODULES)
RECOVERY_KERNEL_MODULES := $(EINK_KERNEL_MODULES)
BOARD_RECOVERY_KERNEL_MODULES_LOAD := $(EINK_KERNEL_MODULES)

# Boot image as stock's: header v2, kernel + ramdisk + our single DTB (built with -@, see
# kernel/mainline/README.md "Boot image rules": Onyx's ABL always applies the DTBO)
BOARD_BOOT_HEADER_VERSION := 2
BOARD_KERNEL_BASE := 0x00000000
BOARD_KERNEL_PAGESIZE := 4096
BOARD_MKBOOTIMG_ARGS += --header_version $(BOARD_BOOT_HEADER_VERSION)
BOARD_MKBOOTIMG_ARGS += --kernel_offset 0x00008000 --ramdisk_offset 0x01000000 --tags_offset 0x00000100
BOARD_MKBOOTIMG_ARGS += --dtb_offset 0x01f00000
BOARD_INCLUDE_DTB_IN_BOOTIMG := true
TARGET_KERNEL_DTB := qcom/sm7225-onyx-go7.dtb
TARGET_DTB_LIST_WILDCARD := qcom/sm7225-onyx-go7

# Zeroed DTBO header: ABL then boots the boot image's single DTB as-is (no DT matching, no overlay). Shown on the
# device 2026-11-03; empty overlays (dtbo-neutral.img) and the stock DTBO both made ABL drop to fastboot.
# dtb.img must hold exactly one DTB for this path (TARGET_DTB_LIST_WILDCARD above).
BOARD_PREBUILT_DTBOIMAGE := $(DEVICE_PATH)/prebuilts/dtbo-zero.img

# ABL appends androidboot.* (slot, serialno, verifiedbootstate), fp9931:vcom and pcb_version itself.
# No earlycon: nothing is wired to the debug UART and stock never initialises it.
# msm.separate_gpu_kms: display without the GPU in the same DRM device (a GPU bind failure took the display
# down with it on the device, 2026-11-05). TE: the DTS sets qcom,te-source = "none" (the TCON has no TE).
# androidboot.serialconsole=0: no debug shell on the (null) console; while that shell runs, Android shows
# "Serial console enabled".
BOARD_KERNEL_CMDLINE := \
    androidboot.hardware=go7ml \
    msm.separate_gpu_kms=1 \
    androidboot.boot_devices=soc@0/7c4000.mmc \
    console=null \
    androidboot.serialconsole=0 \
    firmware_class.path=/vendor/firmware \
    printk.devkmsg=on \
    deferred_probe_timeout=30 \
    clk_ignore_unused \
    pd_ignore_unused

# Firmware files are ELF (DSP/GPU images) copied with PRODUCT_COPY_FILES (as db845c)
BUILD_BROKEN_ELF_PREBUILT_PRODUCT_COPY_FILES := true

# Partitions
BOARD_FLASH_BLOCK_SIZE := 262144
BOARD_BOOTIMAGE_PARTITION_SIZE := 100663296
BOARD_DTBOIMG_PARTITION_SIZE := 25165824
BOARD_USES_METADATA_PARTITION := true

BOARD_SUPER_PARTITION_SIZE := 6442450944
BOARD_SUPER_PARTITION_GROUPS := go7_dynamic_partitions
BOARD_GO7_DYNAMIC_PARTITIONS_PARTITION_LIST := product system system_ext vendor
BOARD_GO7_DYNAMIC_PARTITIONS_SIZE := 6438256640

BOARD_SYSTEMIMAGE_FILE_SYSTEM_TYPE := erofs
BOARD_SYSTEM_EXTIMAGE_FILE_SYSTEM_TYPE := erofs
BOARD_PRODUCTIMAGE_FILE_SYSTEM_TYPE := erofs
BOARD_VENDORIMAGE_FILE_SYSTEM_TYPE := erofs
TARGET_COPY_OUT_PRODUCT := product
TARGET_COPY_OUT_SYSTEM_EXT := system_ext
TARGET_COPY_OUT_VENDOR := vendor
TARGET_USERIMAGES_USE_F2FS := true
BOARD_USERDATAIMAGE_FILE_SYSTEM_TYPE := f2fs

# Recovery in its own partition (recovery_a/_b in the GPT)
BOARD_RECOVERYIMAGE_PARTITION_SIZE := 100663296
BOARD_INCLUDE_RECOVERY_DTBO := true
TARGET_RECOVERY_FSTAB := $(DEVICE_PATH)/init/fstab.go7ml
TARGET_RECOVERY_PIXEL_FORMAT := RGBX_8888

# Graphics: drm_hwcomposer on the e-ink card (onyx-epd, see init.eink_shim.drm.sh), minigbm, Mesa
include device/linaro/dragonboard/shared/graphics/drm_hwcomposer/BoardConfig.mk
BOARD_VENDOR_SEPOLICY_DIRS += \
    device/linaro/dragonboard/shared/graphics/minigbm_msm/sepolicy

# Wi-Fi: ath10k-snoc + nl80211
BOARD_HOSTAPD_DRIVER := NL80211
BOARD_WPA_SUPPLICANT_DRIVER := NL80211
WPA_SUPPLICANT_VERSION := VER_0_8_X
WIFI_HIDL_UNIFIED_SUPPLICANT_SERVICE_RC_ENTRY := true

BOARD_HAVE_BLUETOOTH := true

# SEPolicy: dragonboard's (qrtr, rmtfs, pd-mapper, tqftpserv, drm_hwcomposer, ...) + ours
BOARD_VENDOR_SEPOLICY_DIRS += \
    device/linaro/dragonboard/sepolicy \
    $(DEVICE_PATH)/sepolicy/vendor \
    hardware/onyx/eink/sepolicy \
    vendor/onyx/sensors/sepolicy

DEVICE_MANIFEST_FILE := $(DEVICE_PATH)/manifest.xml

# Verified boot (unlocked device; test keys unless a custom key is set, as device/onyx/Go7)
BOARD_AVB_ENABLE := true
ifneq (,$(AVB_CUSTOM_KEY_PATH))
BOARD_AVB_ALGORITHM := $(AVB_CUSTOM_ALGORITHM)
BOARD_AVB_KEY_PATH := $(AVB_CUSTOM_KEY_PATH)
else
AVB_CUSTOM_ALGORITHM := SHA256_RSA2048
AVB_CUSTOM_KEY_PATH := external/avb/test/data/testkey_rsa2048.pem
endif
ifneq ($(WITH_AVB),true)
BOARD_AVB_MAKE_VBMETA_IMAGE_ARGS += --flags 3
endif
BOARD_AVB_VBMETA_SYSTEM := system system_ext product
BOARD_AVB_VBMETA_SYSTEM_ALGORITHM := $(AVB_CUSTOM_ALGORITHM)
BOARD_AVB_VBMETA_SYSTEM_KEY_PATH := $(AVB_CUSTOM_KEY_PATH)
BOARD_AVB_VBMETA_SYSTEM_ROLLBACK_INDEX := 0
BOARD_AVB_VBMETA_SYSTEM_ROLLBACK_INDEX_LOCATION := 2
