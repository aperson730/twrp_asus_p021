#
# Copyright (C) 2026 The Android Open Source Project
# Copyright (C) 2026 SebaUbuntu's TWRP device tree generator
#
# SPDX-License-Identifier: Apache-2.0
#

# Inherit from those products. Most specific first.
$(call inherit-product, $(SRC_TARGET_DIR)/product/full_base_telephony.mk)

# Inherit some common Omni stuff.
$(call inherit-product, vendor/omni/config/common.mk)

# Inherit from P021 device
$(call inherit-product, device/asus/P021/device.mk)

PRODUCT_DEVICE := P021
PRODUCT_NAME := omni_P021
PRODUCT_BRAND := asus
PRODUCT_MODEL := P021
PRODUCT_MANUFACTURER := asus

PRODUCT_GMS_CLIENTID_BASE := android-asus

PRODUCT_BUILD_PROP_OVERRIDES += \
    PRIVATE_BUILD_DESC="WW_P021-user 5.0.2 LRX22G WW_P021-V4.6.5-20160419 release-keys"

BUILD_FINGERPRINT := asus/WW_P021/P021:5.0.2/LRX22G/WW_P021-V4.6.5-20160419:user/release-keys
