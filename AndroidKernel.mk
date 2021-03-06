#Android makefile to build kernel as a part of Android Build
PERL		= perl

ifeq ($(TARGET_PREBUILT_KERNEL),)

KERNEL_DEFCONFIG := fuji_aoba_defconfig
KERNEL_DIR := $(ANDROID_BUILD_TOP)/kernel/sony/msm8x60
KERNEL_OUT := $(ANDROID_PRODUCT_OUT)/obj/KERNEL_OBJ
KERNEL_CONFIG := $(KERNEL_OUT)/.config
TARGET_PREBUILT_INT_KERNEL := $(KERNEL_OUT)/arch/arm/boot/zImage
KERNEL_HEADERS_INSTALL := $(KERNEL_OUT)/usr
KERNEL_MODULES_INSTALL := system
KERNEL_MODULES_OUT := $(TARGET_OUT)/lib/modules
KERNEL_IMG=$(KERNEL_OUT)/arch/arm/boot/Image
KERNEL_TOOLS_PREFIX := $(ANDROID_BUILD_TOP)/prebuilts/gcc/$(HOST_PREBUILT_TAG)/arm/arm-eabi-4.7/bin/arm-eabi-

MSM_ARCH ?= $(shell $(PERL) -e 'while (<>) {$$a = $$1 if /CONFIG_ARCH_((?:MSM|QSD)[a-zA-Z0-9]+)=y/; $$r = $$1 if /CONFIG_MSM_SOC_REV_(?!NONE)(\w+)=y/;} print lc("$$a$$r\n");' $(KERNEL_CONFIG))
KERNEL_USE_OF ?= $(shell $(PERL) -e '$$of = "n"; while (<>) { if (/CONFIG_USE_OF=y/) { $$of = "y"; break; } } print $$of;' $(KERNEL_DIR)/arch/arm/configs/$(KERNEL_DEFCONFIG))

ifeq "$(KERNEL_USE_OF)" "y"
DTS_NAME ?= $(MSM_ARCH)
DTS_FILES = $(wildcard $(KERNEL_DIR)/arch/arm/boot/dts/$(DTS_NAME)*.dts)
DTS_FILE = $(lastword $(subst /, ,$(1)))
DTB_FILE = $(addprefix $(KERNEL_OUT)/arch/arm/boot/,$(patsubst %.dts,%.dtb,$(call DTS_FILE,$(1))))
ZIMG_FILE = $(addprefix $(KERNEL_OUT)/arch/arm/boot/,$(patsubst %.dts,%-zImage,$(call DTS_FILE,$(1))))
KERNEL_ZIMG = $(KERNEL_OUT)/arch/arm/boot/zImage
DTC = $(KERNEL_OUT)/scripts/dtc/dtc

define append-dtb
mkdir -p $(KERNEL_OUT)/arch/arm/boot;\
$(foreach d, $(DTS_FILES), \
   $(DTC) -p 1024 -O dtb -o $(call DTB_FILE,$(d)) $(d); \
   cat $(KERNEL_ZIMG) $(call DTB_FILE,$(d)) > $(call ZIMG_FILE,$(d));)
endef
else

define append-dtb
endef
endif

ifeq ($(TARGET_USES_UNCOMPRESSED_KERNEL),true)
$(info Using uncompressed kernel)
TARGET_PREBUILT_KERNEL := $(KERNEL_OUT)/piggy
else
TARGET_PREBUILT_KERNEL := $(TARGET_PREBUILT_INT_KERNEL)
endif

define mv-modules
mdpath=`find $(KERNEL_MODULES_OUT) -type f -name modules.dep`;\
if [ "$$mdpath" != "" ];then\
mpath=`dirname $$mdpath`;\
ko=`find $$mpath/kernel -type f -name *.ko`;\
for i in $$ko; do mv $$i $(KERNEL_MODULES_OUT)/; done;\
fi
endef

define clean-module-folder
mdpath=`find $(KERNEL_MODULES_OUT) -type f -name modules.dep`;\
if [ "$$mdpath" != "" ];then\
mpath=`dirname $$mdpath`; rm -rf $$mpath;\
fi
endef

$(KERNEL_OUT):
	mkdir -p $(KERNEL_OUT)

$(PRODUCT_OUT)/kernel: $(TARGET_PREBUILT_KERNEL)
	cp $(TARGET_PREBUILT_KERNEL) $(ANDROID_PRODUCT_OUT)/kernel
	mkdir -p $(ANDROID_PRODUCT_OUT)/obj/KERNEL_OBJ/kernel_intermediates
	cp $(TARGET_PREBUILT_KERNEL) $(ANDROID_PRODUCT_OUT)/obj/KERNEL_OBJ/kernel_intermediates/kernel

$(KERNEL_CONFIG): $(KERNEL_OUT)
	$(MAKE) -C $(KERNEL_DIR) O=$(KERNEL_OUT) ARCH=arm CROSS_COMPILE=$(KERNEL_TOOLS_PREFIX) $(KERNEL_DEFCONFIG)

$(KERNEL_OUT)/piggy : $(TARGET_PREBUILT_INT_KERNEL)
	$(hide) gunzip -c $(KERNEL_OUT)/arch/arm/boot/compressed/piggy.gzip > $(KERNEL_OUT)/piggy

$(TARGET_PREBUILT_INT_KERNEL): $(KERNEL_OUT) $(KERNEL_CONFIG) $(KERNEL_HEADERS_INSTALL)
	$(MAKE) -C $(KERNEL_DIR) O=$(KERNEL_OUT) ARCH=arm CROSS_COMPILE=$(KERNEL_TOOLS_PREFIX) -j8
#	$(MAKE) -C $(KERNEL_DIR) O=$(KERNEL_OUT) ARCH=arm CROSS_COMPILE=$(KERNEL_TOOLS_PREFIX) modules
#	$(MAKE) -C $(KERNEL_DIR) O=$(KERNEL_OUT) INSTALL_MOD_PATH=../../$(KERNEL_MODULES_INSTALL) ARCH=arm CROSS_COMPILE=$(KERNEL_TOOLS_PREFIX) modules_install
#	$(mv-modules)
#	$(clean-module-folder)
	$(append-dtb)

$(KERNEL_HEADERS_INSTALL): $(KERNEL_OUT) $(KERNEL_CONFIG)
	$(MAKE) -C $(KERNEL_DIR) O=$(KERNEL_OUT) ARCH=arm CROSS_COMPILE=$(KERNEL_TOOLS_PREFIX) headers_install
#	cp -R $(KERNEL_HEADERS_INSTALL)/include/* $(TARGET_DEVICE_DIR)/kernel-headers/

kerneltags: $(KERNEL_OUT) $(KERNEL_CONFIG)
	$(MAKE) -C $(KERNEL_DIR) O=$(KERNEL_OUT) ARCH=arm CROSS_COMPILE=$(KERNEL_TOOLS_PREFIX) tags

kernelconfig: $(KERNEL_OUT) $(KERNEL_CONFIG)
	env KCONFIG_NOTIMESTAMP=true \
	     $(MAKE) -C $(KERNEL_DIR) O=$(KERNEL_OUT) ARCH=arm CROSS_COMPILE=$(KERNEL_TOOLS_PREFIX) menuconfig
	env KCONFIG_NOTIMESTAMP=true \
	     $(MAKE) -C $(KERNEL_DIR) O=$(KERNEL_OUT) ARCH=arm CROSS_COMPILE=$(KERNEL_TOOLS_PREFIX) savedefconfig
	cp $(KERNEL_OUT)/defconfig $(KERNEL_DIR)/arch/arm/configs/$(KERNEL_DEFCONFIG)
endif

#
# Rules for packing kernel into elf and sin
#
#$(PRODUCT_OUT)/cmdline.txt: device/semc/$(TARGET_PRODUCT)/BoardConfig.mk
#	$(hide) echo -n '$(BOARD_KERNEL_CMDLINE)' > $@

#$(PRODUCT_OUT)/kernel-unsigned.elf: $(TARGET_PREBUILT_KERNEL) $(PRODUCT_OUT)/ramdisk.img $(PRODUCT_OUT)/RPM.bin $(PRODUCT_OUT)/cmdline.txt | sin-tools
#	$(hide) $(HOST_OUT_EXECUTABLES)/mkelf.py -o $@ \
#		$(TARGET_PREBUILT_KERNEL)@$(BOARD_KERNEL_ADDR) \
#		$(PRODUCT_OUT)/ramdisk.img@$(BOARD_RAMDISK_ADDR),ramdisk \
#		$(PRODUCT_OUT)/RPM.bin@$(BOARD_RPM_ADDR),rpm

#$(PRODUCT_OUT)/kernel-signed.elf: $(PRODUCT_OUT)/kernel-unsigned.elf $(PRODUCT_PARTITION_CONFIG) | sin-tools
#	$(hide) $(SEMCSC) -c $(PRODUCT_PARTITION_CONFIG) -p Kernel -t internal -i $< -o $@

#$(PRODUCT_OUT)/kernel.si_: $(PRODUCT_OUT)/kernel-signed.elf | sin-tools
#	$(hide) $(HOST_OUT_EXECUTABLES)/create_sin_header Kernel $(PRODUCT_PARTITION_CONFIG) $@
#	$(hide) cat $< >> $@

#$(PRODUCT_OUT)/kernel.sin: $(PRODUCT_OUT)/kernel.si_ $(PRODUCT_PARTITION_CONFIG) | sin-tools
#	@echo target SIN: $(notdir $@)
#	$(hide) $(SEMCSC) -c $(PRODUCT_PARTITION_CONFIG) -p Kernel -t external -i $< -o $@

#
# Add kernel to system wide PHONY target sin
#
#.PHONY: sin

#sin: $(PRODUCT_OUT)/kernel.sin

