#
# SPDX-FileCopyrightText: The LineageOS Project
# SPDX-License-Identifier: Apache-2.0
#

# Onyx Boox Go 7 on the mainline-based 6.18 kernel (no QTI vendor blobs). The Onyx-kernel port is
# device/onyx/Go7; this tree only shares its overlays and the onyx hardware/ repos.

$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit_only.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/full_base.mk)

PRODUCT_COPY_FILES += \
    frameworks/native/data/etc/tablet_core_hardware.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/tablet_core_hardware.xml

$(call inherit-product, device/onyx/Go7ml/device.mk)

# must be set before the inherit below, Lineage reads it while parsing common_mobile_full.mk
PRODUCT_NO_CAMERA := true

$(call inherit-product, vendor/lineage/config/common_full_tablet_wifionly.mk)

# Boot animation
TARGET_SCREEN_HEIGHT := 1680
TARGET_SCREEN_WIDTH := 1264

PRODUCT_NAME := lineage_Go7ml
PRODUCT_DEVICE := Go7ml
PRODUCT_BRAND := Onyx
PRODUCT_MODEL := Go7
PRODUCT_MANUFACTURER := ONYX

PRODUCT_CHARACTERISTICS := tablet,nosdcard

PRODUCT_BUILD_PROP_OVERRIDES += \
    DeviceProduct=Go7
