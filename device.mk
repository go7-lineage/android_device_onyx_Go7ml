#
# SPDX-FileCopyrightText: The LineageOS Project
# SPDX-License-Identifier: Apache-2.0
#

LOCAL_PATH := device/onyx/Go7ml

PRODUCT_SOONG_NAMESPACES += \
    $(LOCAL_PATH) \
    device/linaro/dragonboard \
    hardware/qcom-caf/bootctrl

PRODUCT_SELINUX_TREBLE_LABELING_TRACKING_LIST_FILE := $(LOCAL_PATH)/sepolicy/tracking_list.yaml

# A/B
$(call inherit-product, $(SRC_TARGET_DIR)/product/virtual_ab_ota/launch.mk)
AB_OTA_POSTINSTALL_CONFIG += \
    RUN_POSTINSTALL_system=true \
    POSTINSTALL_PATH_system=system/bin/otapreopt_script \
    FILESYSTEM_TYPE_system=erofs \
    POSTINSTALL_OPTIONAL_system=true
PRODUCT_PACKAGES += \
    otapreopt_script \
    update_engine \
    update_engine_sideload \
    update_verifier

PRODUCT_USE_DYNAMIC_PARTITIONS := true
PRODUCT_BUILD_SUPER_PARTITION := true

# The board launched with Android 11 (stock); keep its shipping level
PRODUCT_SHIPPING_API_LEVEL := 30

# Boot control: QTI's (source, hardware/qcom-caf/bootctrl), as device/onyx/Go7. The stock ABL selects the
# slot from GPT attribute bits; AOSP's default HAL keeps slot state in misc, which ABL doesn't read.
PRODUCT_PACKAGES += \
    android.hardware.boot-service.qti \
    android.hardware.boot-service.qti.recovery

# Graphics (device/linaro/dragonboard): drm_hwcomposer, minigbm, SwiftShader + ANGLE. No GPU at first;
# Mesa/freedreno later (kernel/mainline/android-mainline.md, "Order").
TARGET_USES_SWR := true
$(call inherit-product, device/linaro/dragonboard/shared/graphics/drm_hwcomposer/device.mk)
$(call inherit-product, device/linaro/dragonboard/shared/graphics/minigbm_msm/device.mk)
$(call inherit-product, device/linaro/dragonboard/shared/graphics/swangle/device.mk)

# The composer uses only the onyx-epd card; init.go7ml.drm.sh sets vendor.hwc.drm.device to it at early-boot
# (with msm.separate_gpu_kms=1 there are three cards: adreno, msm = the e-ink DSI link driven by the kernel's
# own client, onyx-epd). The refresh policy runs in onyx-epd (ui_* in sepdc/debug); no composer patch.
PRODUCT_PACKAGES += \
    init.go7ml.drm.sh
PRODUCT_PRODUCT_PROPERTIES += \
    ro.sf.lcd_density=300

# E-ink: QS tile (writes persist.vendor.eink_shim.*, mapped to the driver in init.go7ml.rc)
PRODUCT_PACKAGES += \
    EinkShimTile

# Remoteprocs (the modem DSP runs Wi-Fi): rmtfs, tqftpserv from dragonboard, started in init.go7ml.rc.
# The kernel does PD mapping (CONFIG_QCOM_PD_MAPPER) and the QRTR name service, so no pd-mapper/qrtr-ns;
# dragonboard's init.utils.rc (db845c set_hw and audio) isn't used.
PRODUCT_PACKAGES += \
    qrtr-lookup \
    rmtfs \
    tqftpserv

# Wi-Fi (ath10k-snoc, no vendor Wi-Fi HAL, as db845c)
PRODUCT_PACKAGES += \
    hostapd \
    libwpa_client \
    wpa_supplicant \
    wpa_supplicant.conf \
    wificond
PRODUCT_VENDOR_PROPERTIES += \
    wifi.interface=wlan0
PRODUCT_COPY_FILES += \
    frameworks/native/data/etc/android.hardware.wifi.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.wifi.xml \
    device/linaro/dragonboard/wpa_supplicant_overlay.conf:$(TARGET_COPY_OUT_VENDOR)/etc/wifi/wpa_supplicant_overlay.conf

# Bluetooth (WCN39xx over hci_qca; AOSP's Linux HCI HAL)
PRODUCT_PACKAGES += \
    android.hardware.bluetooth-service.default
PRODUCT_COPY_FILES += \
    frameworks/native/data/etc/android.hardware.bluetooth.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.bluetooth.xml \
    frameworks/native/data/etc/android.hardware.bluetooth_le.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.bluetooth_le.xml

# Keystore without QSEE: non-secure KeyMint and Gatekeeper (no hardware-backed keys, as any mainline Android)
PRODUCT_PACKAGES += \
    com.android.hardware.keymint.rust_nonsecure \
    com.android.hardware.gatekeeper.nonsecure

# Health from /sys/class/power_supply (qcom_qg battery, pm7250b-charger), Lineage charge limits on the charger
PRODUCT_PACKAGES += \
    android.hardware.health-service.example \
    android.hardware.health-service.example_recovery \
    vendor.lineage.health-service.default
$(call soong_config_set_bool,lineage_health,charging_control_supports_bypass,false)
$(call soong_config_set_bool,lineage_health,charging_control_supports_limit,true)
$(call soong_config_set_bool,lineage_health,charging_control_supports_toggle,false)
$(call soong_config_set,lineage_health,charging_control_limit_start_path,/sys/class/power_supply/pm7250b-charger/charge_control_start_threshold)
$(call soong_config_set,lineage_health,charging_control_limit_stop_path,/sys/class/power_supply/pm7250b-charger/charge_control_end_threshold)

# Audio: AOSP's default HAL (internal audio is groundwork only, kernel/mainline/battery-audio.md)
PRODUCT_PACKAGES += \
    com.android.hardware.audio \
    tinymix \
    tinyplay \
    tinycap
PRODUCT_COPY_FILES += \
    device/linaro/dragonboard/etc/audio_policy_configuration.xml:$(TARGET_COPY_OUT_VENDOR)/etc/audio_policy_configuration.xml \
    hardware/interfaces/audio/aidl/default/audio_effects_config.xml:$(TARGET_COPY_OUT_VENDOR)/etc/audio_effects_config.xml \
    frameworks/av/services/audiopolicy/config/audio_policy_volumes.xml:$(TARGET_COPY_OUT_VENDOR)/etc/audio_policy_volumes.xml \
    frameworks/av/services/audiopolicy/config/bluetooth_audio_policy_configuration_7_0.xml:$(TARGET_COPY_OUT_VENDOR)/etc/bluetooth_audio_policy_configuration_7_0.xml \
    frameworks/av/services/audiopolicy/config/default_volume_tables.xml:$(TARGET_COPY_OUT_VENDOR)/etc/default_volume_tables.xml \
    frameworks/av/services/audiopolicy/config/r_submix_audio_policy_configuration.xml:$(TARGET_COPY_OUT_VENDOR)/etc/r_submix_audio_policy_configuration.xml \
    frameworks/av/services/audiopolicy/config/usb_audio_policy_configuration.xml:$(TARGET_COPY_OUT_VENDOR)/etc/usb_audio_policy_configuration.xml

# Media: software codecs only, as device/onyx/Go7
PRODUCT_VENDOR_PROPERTIES += \
    media.c2.hal.selection=aidl

# USB gadget (configfs: adb, MTP), dragonboard's rc; init.go7ml.rc sets vendor.usb.controller=a600000.usb
PRODUCT_COPY_FILES += \
    device/linaro/dragonboard/init.common.usb.rc:$(TARGET_COPY_OUT_VENDOR)/etc/init/init.go7ml.usb.rc

# Init, fstab, ueventd; init.go7ml.logdump.sh is a first-boot aid (kernel log to the logdump partition)
PRODUCT_PACKAGES += \
    init.go7ml.logdump.sh \
    fstab.go7ml \
    fstab.go7ml.ramdisk \
    init.go7ml.rc \
    ueventd.go7ml.rc

# Keys: gpio-keys (page keys), onyx-go7-hall (KEY_POWER/KEY_WAKEUP, as stock) use Generic.kl
PRODUCT_COPY_FILES += \
    frameworks/native/data/etc/android.hardware.touchscreen.multitouch.jazzhand.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.touchscreen.multitouch.jazzhand.xml

# Overlays (copied from device/onyx/Go7)
PRODUCT_ENFORCE_RRO_TARGETS := *
PRODUCT_PACKAGES += \
    FrameworksResCommon \
    FrameworksResProduct \
    FrameworksResTarget \
    LineageSdkResCommon \
    SettingsProviderResCommon \
    SystemUIResCommon \
    WifiResCommon

# Firmware (GPU, DSPs, Wi-Fi board data, BT) and the panel's waveform: vendor/onyx/Go7ml (setup-firmware.sh)
$(call inherit-product, vendor/onyx/Go7ml/Go7ml-vendor.mk)
