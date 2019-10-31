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

MAKEFILE_PATH = $(dir $(realpath $(firstword $(MAKEFILE_LIST))))

# default target
all: build

# include Makefile snippet local to project, if one exists
-include local.mk

# tools
ifeq ($(shell expr $(subst .,,$(PETALINUX_VER)) "<" 20183),1)
XSDB ?= $(PETALINUX)/tools/hsm/bin/xsdb
else
XSDB ?= xsdb
endif

PLATFORM = $(shell cat project-spec/configs/config | \
		grep -E '^CONFIG_SYSTEM_(MICROBLAZE|ZYNQ|ZYNQMP)=y$$' | \
		sed -e 's/^CONFIG_SYSTEM_\(.*\)=y$$/\1/' | \
		tr [:upper:] [:lower:])

# defaults
DEF_IMAGEUB = images/linux/image.ub
SYSTEM_DTB ?= images/linux/system.dtb
SYSTEM_DTS ?= images/linux/system.dts

PRJ_HDF = project-spec/hw-description/system.hdf

# defaults for flash-* targets
FLASH_TYPE ?= qspi_single
FSBL_ELF ?= images/linux/zynqmp_fsbl.elf
BOOT_BIN ?= images/linux/BOOT.BIN
BOOT_BIN_OFF ?= 0
KERNEL_IMG ?= $(DEF_IMAGEUB)
KERNEL_IMG_OFF ?= $(shell echo $$((16 * 1024 * 1024)))

# user arguments
HDF ?=
BIT ?=
FSBL ?=
ATF ?=
PMUFW ?=
UBOOT ?=
BOOT ?=
BSP ?=
BOOT_ARG_EXTRA ?=

# petalinux-* generic arguments
ifeq ($(V),1)
GEN_ARGS = -v
endif
# petalinux-package --boot arguments
BOOT_ARG_FPGA = --fpga
ifneq ($(BIT),)
BOOT_ARG_FPGA += $(BIT)
endif
#  no need to specify --fsbl if default is to be used
BOOT_ARG_FSBL =
ifneq ($(FSBL),)
BOOT_ARG_FSBL += --fsbl $(FSBL)
endif
#  no need to specify --atf if default is to be used
BOOT_ARG_ATF =
ifneq ($(ATF),)
BOOT_ARG_ATF += --atf $(ATF)
endif
#  no need to specify --pmufw if default is to be used
BOOT_ARG_PMUFW =
ifneq ($(PMUFW),)
BOOT_ARG_PMUFW += --pmufw $(PMUFW)
endif
BOOT_ARG_UBOOT = --u-boot
ifneq ($(UBOOT),)
BOOT_ARG_UBOOT += $(UBOOT)
endif
ifneq ($(BOOT),)
BOOT_ARG_OUT = -o $(BOOT)
endif


###############################################################################


FORCE:


# force only if "gethdf" is one of the targets
$(PRJ_HDF): $(HDF) $(subst gethdf,FORCE,$(findstring gethdf,$(MAKECMDGOALS)))
ifeq ($(HDF),)
	@echo "error: missing HDF, run with argument HDF=<path-to-.hdf-file>"
	@false
else
	petalinux-config $(GEN_ARGS) --get-hw-description $(dir $(HDF)) --oldconfig
endif

gethdf: $(PRJ_HDF)

.PHONY: gethdf


config: $(PRJ_HDF)
	petalinux-config $(GEN_ARGS)

config-kernel: $(PRJ_HDF)
	DISPLAY= petalinux-config $(GEN_ARGS) -c kernel

config-rootfs: $(PRJ_HDF)
	petalinux-config $(GEN_ARGS) -c rootfs

build: $(PRJ_HDF)
	petalinux-build $(GEN_ARGS)

sdk: $(PRJ_HDF)
	petalinux-build $(GEN_ARGS) -s

.PHONY: config config-kernel config-rootfs build sdk


package-boot: $(PRJ_HDF)
	petalinux-package --boot --force \
		$(BOOT_ARG_FPGA) $(BOOT_ARG_FSBL) $(BOOT_ARG_ATF) \
		$(BOOT_ARG_PMUFW) $(BOOT_ARG_UBOOT) $(BOOT_ARG_EXTRA) \
		$(BOOT_ARG_OUT)
package-boot: $(BOOT)

package-prebuilt: $(PRJ_HDF)
	petalinux-package --prebuilt --force -a $(DEF_IMAGEUB):images

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
	$(XSDB) $(MAKEFILE_PATH)xsdb/$(PLATFORM)-reset.tcl

boot-jtag-u-boot: reset-jtag
	petalinux-boot --jtag --u-boot -v --fpga --hw_server-url $(HW_SERVER_URL)

boot-jtag-kernel: reset-jtag
	petalinux-boot --jtag --kernel -v --fpga --hw_server-url $(HW_SERVER_URL)

boot-jtag-psinit-uboot: reset-jtag
	$(XSDB) $(MAKEFILE_PATH)xsdb/$(PLATFORM)-boot-psinit-uboot.tcl

boot-qemu: $(PRJ_HDF)
	petalinux-boot --qemu --kernel

# IMPORTANT: program_flash can be found in Xilinx Vivado toolchain, only
#            (<= v2018.2)!
flash-boot: reset-jtag
	program_flash \
		-flash_type $(FLASH_TYPE) \
		-fsbl $(FSBL_ELF) \
		-f $(BOOT_BIN) -offset $(BOOT_BIN_OFF) \
		-verify \
		-cable type xilinx_tcf url $(HW_SERVER_URL)

flash-kernel: reset-jtag
	program_flash \
		-flash_type $(FLASH_TYPE) \
		-fsbl $(FSBL_ELF) \
		-f $(KERNEL_IMG) -offset $(KERNEL_IMG_OFF) \
		-verify \
		-cable type xilinx_tcf url $(HW_SERVER_URL)

flash: flash-boot flash-kernel

.PHONY: $(BOOT) $(BSP) package-boot package-prebuilt package-bsp dts \
	reset-jtag boot-jtag-u-boot boot-jtag-kernel boot-jtag-psinit-uboot \
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
