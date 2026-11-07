DEVICE_PATH := device/asus/P021

ALLOW_MISSING_DEPENDENCIES := true

# Architecture
TARGET_ARCH := x86
TARGET_ARCH_VARIANT := x86
TARGET_CPU_ABI := x86
TARGET_CPU_ABI2 :=
TARGET_CPU_VARIANT := generic

# Bootloader
TARGET_BOOTLOADER_BOARD_NAME := EeePad
TARGET_NO_BOOTLOADER := true
TARGET_BOARD_PLATFORM := sofia3g

# Kernel (prebuilt)
BOARD_KERNEL_BASE := 0x007f8000
BOARD_KERNEL_PAGESIZE := 4096
BOARD_KERNEL_CMDLINE := androidboot.selinux=permissive idle=halt androidboot.hardware=sofia3g nolapic_pm firmware_class.path=/system/vendor/firmware nolapic_timer x86_intel_xgold_timer=soctimer_only vmalloc=256M slub_max_order=0 build_version=3 debug notsc
BOARD_MKBOOTIMG_ARGS := --ramdisk_offset 0xffc08000 --tags_offset 0xff808100 --second_offset 0xfff08000 --second $(DEVICE_PATH)/prebuilt/second
TARGET_PREBUILT_KERNEL := $(DEVICE_PATH)/prebuilt/kernel

# Partitions (measured: 17408 KiB each)
BOARD_BOOTIMAGE_PARTITION_SIZE := 17825792
BOARD_RECOVERYIMAGE_PARTITION_SIZE := 17825792
BOARD_FLASH_BLOCK_SIZE := 4096
BOARD_SYSTEMIMAGE_PARTITION_TYPE := ext4
BOARD_USERDATAIMAGE_FILE_SYSTEM_TYPE := ext4
TARGET_USERIMAGES_USE_EXT4 := true

# Recovery
TARGET_RECOVERY_FSTAB := $(DEVICE_PATH)/recovery.fstab
TARGET_RECOVERY_PIXEL_FORMAT := "RGBX_8888"
RECOVERY_SDCARD_ON_DATA := true

# TWRP
TW_THEME := portrait_hdpi
TW_NO_USB_STORAGE := true
TW_EXCLUDE_DEFAULT_USB_INIT := true
TW_BRIGHTNESS_PATH := "/sys/class/leds/lcd-backlight/brightness"
TW_MAX_BRIGHTNESS := 255
TW_DEFAULT_BRIGHTNESS := 150
TW_USE_TOOLBOX := true

# Diagnostics for the touch-death bug (remove once solved)
TW_NO_SCREEN_TIMEOUT := true
TW_EXCLUDE_MTP := true


