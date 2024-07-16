# SPDX-License-Identifier: Apache-2.0
#
################################################################################
##
## Copyright 2018-2019 Missing Link Electronics, Inc.
##
## Licensed under the Apache License, Version 2.0 (the "License");
## you may not use this file except in compliance with the License.
## You may obtain a copy of the License at
##
##     http://www.apache.org/licenses/LICENSE-2.0
##
## Unless required by applicable law or agreed to in writing, software
## distributed under the License is distributed on an "AS IS" BASIS,
## WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
## See the License for the specific language governing permissions and
## limitations under the License.
##
################################################################################
##
##  File Name      : Makefile
##  Initial Author : Joachim Foerster
##                   <joachim.foerster@missinglinkelectronics.com>
##
################################################################################
##
##  File Summary   : petalinux-* convenience wrapper
##
##                   Based on Makefile for PetaLinux by Stefan Wiehler.
##
################################################################################

ifeq ($(PETALINUX_VER),)
$(error PETALINUX_VER is unset. This Makefile must be invoked from within a PetaLinux environment)
endif

PSMAKE_DIR = $(dir $(realpath $(firstword $(MAKEFILE_LIST))))

# default target
all: build

# include Makefile snippet local to project, if one exists
-include local.mk

# tools
ifeq ($(shell expr $(subst .,,$(PETALINUX_VER)) ">" 20232),1)
XSDB ?= $(PETALINUX)/components/xsct/bin/xsdb
else
ifeq ($(shell expr $(subst .,,$(PETALINUX_VER)) ">" 20191),1)
XSDB ?= $(PETALINUX)/tools/xsct/bin/xsdb
else
ifeq ($(shell expr $(subst .,,$(PETALINUX_VER)) "<" 20183),1)
XSDB ?= $(PETALINUX)/tools/hsm/bin/xsdb
else
# for v2018.3 and v2019.1, xsdb is automatically found via $PATH
XSDB ?= xsdb
endif
endif
endif

ifeq ($(shell expr $(subst .,,$(PETALINUX_VER)) ">" 20183),1)
SILENTCONFIG = --silentconfig
else
SILENTCONFIG = --oldconfig
endif

PLATFORM = $(shell cat project-spec/configs/config | \
		grep -E '^CONFIG_SYSTEM_(MICROBLAZE|ZYNQ|ZYNQMP|VERSAL)=y$$' | \
		sed -e 's/^CONFIG_SYSTEM_\(.*\)=y$$/\1/' | \
		tr [:upper:] [:lower:])

# defaults
PETALINUX_CONFIG = project-spec/configs/config
LOCAL_CONF = build/conf/local.conf
SOURCE_DOWNLOADS = build/downloads
SOURCE_MIRROR = $(shell awk 'BEGIN { FS = "file://" } /PREMIRRORS =/ { gsub(/ \\n \\/, "", $$2); print $$2 }' build/conf/plnxtool.conf)
MANIFEST_PATH = $(lastword $(wildcard build/tmp/deploy/licenses/petalinux-image-minimal-*))

# backwards compatibility of renamed parameters
MAKEFILE_PATH = $(PSMAKE_DIR)
ifneq ($(FSBL_ELF),)
FSBL ?= $(FSBL_ELF)
endif
ifneq ($(KERNEL_IMG),)
IMAGE ?= $(KERNEL_IMG)
endif
ifneq ($(KERNEL_IMG_OFF),)
IMAGE_OFF ?= $(KERNEL_IMG_OFF)
endif

# default values for user arguments
IMAGE_DIR = images/linux/
DEF_BIT ?= $(IMAGE_DIR)/system.bit
DEF_FSBL ?= $(IMAGE_DIR)/zynqmp_fsbl.elf
DEF_ATF ?= $(IMAGE_DIR)/bl31.elf
DEF_PMUFW ?= $(IMAGE_DIR)/pmufw.elf
DEF_UBOOT ?= $(IMAGE_DIR)/u-boot.elf
DEF_IMAGE ?= $(IMAGE_DIR)/image.ub
SYSTEM_DTB ?= $(IMAGE_DIR)/system.dtb
SYSTEM_DTS ?= $(IMAGE_DIR)/system.dts

# defaults for flash-* targets
FLASH_TYPE ?= qspi_single
DEF_BOOT_BIN ?= $(IMAGE_DIR)/BOOT.BIN
BOOT_BIN ?= $(DEF_BOOT_BIN)
BOOT_BIN_OFF ?= 0
IMAGE_OFF ?= $(shell echo $$((16 * 1024 * 1024)))


# user arguments
HDF ?= 
BIT ?= $(DEF_BIT)
FSBL ?= $(DEF_FSBL)
ATF ?= $(DEF_ATF)
PMUFW ?= $(DEF_PMUFW)
UBOOT ?= $(DEF_UBOOT)
IMAGE ?= $(DEF_IMAGE)
BOOT ?=
BSP ?=
BOOT_ARG_EXTRA ?=
UPDATE_MIRROR ?= 0
SOURCE_RELEASE ?= source-release
MANIFESTS ?= manifests
V ?=


# location of imported .hdf/.xsa file
ifeq ($(HDF),)
# if user does not specify HDF, select PRJ_HDF from existing .hdf or .xsa file
PRJ_HDF = $(wildcard project-spec/hw-description/*.hdf project-spec/hw-description/*.xsa)
else
# if user specifies HDF, let PRJ_HDF depend on HDF suffix and assume "system" as prefix
PRJ_HDF = project-spec/hw-description/system$(suffix $(HDF))
endif
ifeq ($(PRJ_HDF),)
$(error missing HDF, run with argument HDF=<path-to-.hdf-or-.xsa-file>)
endif

ifneq ($(HDF),)
TMPHDF ?= build/psmake/tmphdf/$(notdir $(HDF))/$(notdir $(HDF))
endif

# petalinux-* generic arguments
ifeq ($(V),1)
GEN_ARGS = -v
endif
# petalinux-package --boot arguments
ifneq ($(BIT),no)
BOOT_ARG_FPGA = --fpga
ifneq ($(BIT),$(DEF_BIT))
BOOT_ARG_FPGA += $(BIT)
endif
endif
#  no need to specify --fsbl if default is to be used
BOOT_ARG_FSBL =
ifneq ($(FSBL),$(DEF_FSBL))
BOOT_ARG_FSBL += --fsbl $(FSBL)
endif
#  no need to specify --atf if default is to be used
BOOT_ARG_ATF =
ifneq ($(ATF),$(DEF_ATF))
BOOT_ARG_ATF += --atf $(ATF)
endif
#  no need to specify --pmufw if default is to be used
BOOT_ARG_PMUFW =
ifneq ($(PMUFW),$(DEF_PMUFW))
BOOT_ARG_PMUFW += --pmufw $(PMUFW)
endif
BOOT_ARG_UBOOT = --u-boot
ifneq ($(UBOOT),$(DEF_UBOOT))
BOOT_ARG_UBOOT += $(UBOOT)
endif
ifneq ($(BOOT),)
BOOT_ARG_OUT = -o $(BOOT)
endif
JTAG_ARG ?=
ifneq ($(HW_SERVER_BEFORE_CONNECT),)
JTAG_ARG += --before-connect '$(HW_SERVER_BEFORE_CONNECT)'
endif
ifneq ($(HW_SERVER_AFTER_CONNECT),)
JTAG_ARG += --after-connect '$(HW_SERVER_AFTER_CONNECT)'
endif

###############################################################################


define set-update-mirror
	sed -i 's/CONFIG_YOCTO_BB_NO_NETWORK=y/# CONFIG_YOCTO_BB_NO_NETWORK is not set/' $(PETALINUX_CONFIG)
	printf 'BB_GENERATE_MIRROR_TARBALLS = "1"' >> $(LOCAL_CONF)
	petalinux-config $(SILENTCONFIG)
endef

define reset-update-mirror
	sed -i 's/# CONFIG_YOCTO_BB_NO_NETWORK is not set/CONFIG_YOCTO_BB_NO_NETWORK=y/' $(PETALINUX_CONFIG)
	sed -i '/BB_GENERATE_MIRROR_TARBALLS/d' $(LOCAL_CONF)
	petalinux-config $(SILENTCONFIG)
endef

# arg1: cmd
define trap-update-mirror
sh -c "trap 'trap - SIGINT SIGTERM ERR; \
	sed -i \"s/# CONFIG_YOCTO_BB_NO_NETWORK is not set/CONFIG_YOCTO_BB_NO_NETWORK=y/\" $(PETALINUX_CONFIG); \
	sed -i \"/BB_GENERATE_MIRROR_TARBALLS/d\" $(LOCAL_CONF); \
	petalinux-config $(SILENTCONFIG); \
	exit 1' SIGINT SIGTERM ERR; $(1)"
endef


define set-source-release
	printf 'INHERIT += "archiver"\n' >> $(LOCAL_CONF)
	printf 'ARCHIVER_MODE[src] = "original"\n' >> $(LOCAL_CONF)
	petalinux-config $(SILENTCONFIG)
endef

define reset-source-release
	sed -i '/INHERIT += "archiver"/d' $(LOCAL_CONF)
	sed -i '/ARCHIVER_MODE\[src\] = "original"/d' $(LOCAL_CONF)
	petalinux-config $(SILENTCONFIG)
endef

# arg1: cmd
define trap-source-release
sh -c "trap 'trap - SIGINT SIGTERM ERR; \
	sed -i \"/INHERIT += \\\"archiver\\\"/d\" $(LOCAL_CONF); \
	sed -i \"/ARCHIVER_MODE\\\[src\\\] = \\\"original\\\"/d\" $(LOCAL_CONF); \
	petalinux-config $(SILENTCONFIG); \
	exit 1' SIGINT SIGTERM ERR; $(1)"
endef


###############################################################################


FORCE:


# force only if "gethdf" is one of the targets
$(PRJ_HDF): $(HDF) $(subst gethdf,FORCE,$(findstring gethdf,$(MAKECMDGOALS)))
	mkdir -p $(dir $(TMPHDF))
	ln -sf $(realpath $(HDF)) $(TMPHDF)
	petalinux-config $(GEN_ARGS) --get-hw-description $(dir $(TMPHDF)) $(SILENTCONFIG)

gethdf: $(PRJ_HDF)

.PHONY: gethdf


config: $(PRJ_HDF)
	petalinux-config $(GEN_ARGS)

config-kernel: $(PRJ_HDF)
	DISPLAY= petalinux-config $(GEN_ARGS) -c kernel

config-rootfs: $(PRJ_HDF)
	petalinux-config $(GEN_ARGS) -c rootfs

build: $(PRJ_HDF)
ifneq ($(shell grep CONFIG_YOCTO_BB_NO_NETWORK=y project-spec/configs/config),)
	$(call trap-update-mirror,__BLD_ARGS=\"$(GEN_ARGS)\" $(MAKE) __build)
else
	__BLD_ARGS="$(GEN_ARGS)" $(MAKE) __build
endif

sdk: $(PRJ_HDF)
ifneq ($(shell grep CONFIG_YOCTO_BB_NO_NETWORK=y project-spec/configs/config),)
	$(call trap-update-mirror,__BLD_ARGS=\"$(GEN_ARGS) -s\" $(MAKE) __build)
else
	__BLD_ARGS="$(GEN_ARGS) -s" $(MAKE) __build
endif

source-release: $(PRJ_HDF)
	$(call trap-source-release,__BLD_ARGS=\"$(GEN_ARGS)\" $(MAKE) __source-release)
	__BLD_ARGS="$(GEN_ARGS)" $(MAKE) __source-release

__build:
ifeq ($(UPDATE_MIRROR),1)
	$(call set-update-mirror)
endif
	petalinux-build $(__BLD_ARGS)
ifeq ($(UPDATE_MIRROR),1)
	mkdir -p $(SOURCE_MIRROR)
	find $(SOURCE_DOWNLOADS)/* -path '$(SOURCE_DOWNLOADS)/git2' -prune -or \
		-not -name '*.done' \
		-type f \
		-print \
		-exec cp -n {} $(SOURCE_MIRROR) \;
	$(call reset-update-mirror)
endif

__source-release:
	$(call set-source-release)
	__BLD_ARGS="$(GEN_ARGS)" $(MAKE) __build
	$(PSMAKE_DIR)/source-release.sh $(SOURCE_RELEASE)
	mkdir -p $(MANIFESTS)
	find $(MANIFEST_PATH) -name '*.manifest' -exec cp {} $(MANIFESTS) \;
	$(call reset-source-release)


.PHONY: config config-kernel config-rootfs build sdk source-release


package-boot: $(PRJ_HDF)
	petalinux-package --boot --force \
		$(BOOT_ARG_FPGA) $(BOOT_ARG_FSBL) $(BOOT_ARG_ATF) \
		$(BOOT_ARG_PMUFW) $(BOOT_ARG_UBOOT) $(BOOT_ARG_EXTRA) \
		$(BOOT_ARG_OUT)
package-boot: $(BOOT)

# package-secure-boot
include $(PSMAKE_DIR)/secure-boot.mk

package-prebuilt: $(PRJ_HDF)
	petalinux-package --prebuilt --force -a $(IMAGE):images

$(BSP): $(PRJ_HDF)
ifeq ($(BSP),)
	@echo "error: missing BSP, run with argument BSP=<path-to-.bsp-file>"
	@false
else
	petalinux-package --bsp --force -p $(PWD) -o $(BSP)
endif
package-bsp: $(BSP)

dts: $(SYSTEM_DTS)
$(SYSTEM_DTS): $(SYSTEM_DTB)
	dtc -I dtb -O dts -o $@ $<

reset-jtag: $(PRF_HDF)
	$(XSDB) $(PSMAKE_DIR)xsdb/$(PLATFORM)-reset.tcl

switch-jtag: $(PRF_HDF)
	$(XSDB) $(PSMAKE_DIR)/xsdb/$(PLATFORM)-switch.tcl -m jtag

switch-sd1_2.0 switch-sd1: $(PRF_HDF)
	$(XSDB) $(PSMAKE_DIR)/xsdb/$(PLATFORM)-switch.tcl -m sd1_2.0

boot-jtag-u-boot: reset-jtag
	petalinux-boot --jtag --u-boot -v --fpga --hw_server-url $(HW_SERVER_URL) $(JTAG_ARG)

boot-jtag-kernel: reset-jtag
	petalinux-boot --jtag --kernel -v --fpga --hw_server-url $(HW_SERVER_URL) $(JTAG_ARG)

boot-jtag-psinit-uboot: reset-jtag
	$(XSDB) $(PSMAKE_DIR)xsdb/$(PLATFORM)-boot-psinit-uboot.tcl

boot-qemu: $(PRJ_HDF)
	petalinux-boot --qemu --kernel

# IMPORTANT: program_flash can be found in Xilinx Vivado toolchain, only
#            (<= v2018.2)!
flash-boot: reset-jtag
	program_flash \
		-flash_type $(FLASH_TYPE) \
		-fsbl $(FSBL) \
		-f $(BOOT_BIN) -offset $(BOOT_BIN_OFF) \
		-verify \
		-cable type xilinx_tcf url $(HW_SERVER_URL)

flash-kernel: reset-jtag
	program_flash \
		-flash_type $(FLASH_TYPE) \
		-fsbl $(FSBL) \
		-f $(IMAGE) -offset $(IMGAGE_OFF) \
		-verify \
		-cable type xilinx_tcf url $(HW_SERVER_URL)

flash: flash-boot flash-kernel

.PHONY: $(BOOT) $(BSP) package-boot package-prebuilt package-bsp dts \
	reset-jtag switch-jtag switch-sd1_2.0 switch-sd1 boot-jtag-u-boot \
	boot-jtag-kernel boot-jtag-psinit-uboot \
	boot-qemu flash-boot flash-kernel flash

mrproper:
	petalinux-build $(GEN_ARGS) -x mrproper
ifeq ($(CLEAN_HDF),1)
	-cd project-spec/hw-description/ && \
		ls -1 | grep -v -e ^metadata$$ | xargs rm -fr
endif
	rm -rf project-spec/meta-plnx-generated/
	-find pre-built/ -type f -not -name 'pmu_rom_qemu_sha3.elf' \
		-not -name 'system.dtb' \
		-not -name 'linux-boot.*' \
		-delete
	rm -rf *.bsp

.PHONY: mrproper
