#
# Copyright (C) 2026 The Android Open Source Project
# Copyright (C) 2026 SebaUbuntu's TWRP device tree generator
#
# SPDX-License-Identifier: Apache-2.0
#

# Inherit from those products. Most specific first.
$(call inherit-product, $(SRC_TARGET_DIR)/product/full_base_telephony.mk)

# Inherit some common twrp stuff.
$(call inherit-product, vendor/omni/config/common.mk)

# Inherit from P021 device
$(call inherit-product, device/asus/P021/device.mk)

PRODUCT_DEVICE := P021
PRODUCT_NAME := omni_P021
PRODUCT_BRAND := asus
PRODUCT_MODEL := P021
PRODUCT_MANUFACTURER := asus



