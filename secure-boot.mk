# SPDX-License-Identifier: Apache-2.0
#
################################################################################
##
## Copyright 2024 Missing Link Electronics, Inc.
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
##  File Name      : secure-boot.mk
##  Initial Author : Cornelia Höhl
##                   <cornelia.hoehl@missinglinkelectronics.com>
##
##                   Based on earlier code by Stefan Wiehler.
##
################################################################################
##
##  File Summary   : Secure Boot support for petalinux.mk
##
################################################################################

# user arguments
KEYS ?=
INCLUDE_IMAGE ?=
AUTH_ONLY ?=

SECURE_BOOT_BIN ?= $(IMAGE_DIR)/secure-boot/BOOT.BIN
SECURE_BOOT_CFG ?= $(PSMAKE_DIR)/vitis/cfgs/secure-boot
SECURE_BOOT_WS ?= build/secure-boot


check-set-KEYS:
	$(if $(KEYS),,$(error KEYS is unset, but necessary for package-secure-boot))
.PHONY: check-set-KEYS

ifneq ($(KEYS),)
RED_KEY := $(shell cat $(KEYS)/red_key.txt)
endif


SECURE_BOOT_SCR := $(SECURE_BOOT_WS)/boot.scr
SECURE_BOOT_TXT := $(SECURE_BOOT_WS)/$(basename $(notdir $(SECURE_BOOT_SCR))).txt
# IMPORTANT: Keep load address of image.ub in sync with vitis/cfgs/secure-boot.mk!
define create-simple-bootscr
	mkdir -p $(dir $(SECURE_BOOT_SCR))
	echo "bootm 0x10000000" >$(SECURE_BOOT_TXT)
	mkimage -c none -A arm -T script -d $(SECURE_BOOT_TXT) $(SECURE_BOOT_SCR)
endef


package-secure-boot: check-set-KEYS $(PRJ_HDF) $(KEYS)/red_key.txt
	# preparation
	$(MAKE) -f $(PSMAKE_DIR)/vitis.mk -B CFG=$(SECURE_BOOT_CFG) \
		O=$(SECURE_BOOT_WS) secure_boot_distclean

	# if boot image is to be included, create a simple boot.scr
	$(if $(INCLUDE_IMAGE),$(call create-simple-bootscr),)

	# generate .nky files - pass 1
	$(MAKE) -f $(PSMAKE_DIR)/vitis.mk -B CFG=$(SECURE_BOOT_CFG) \
		O=$(SECURE_BOOT_WS) \
		KEYS=$(shell realpath --relative-to $(SECURE_BOOT_WS) $(KEYS)) \
		FSBL=$(FSBL) PMUFW=$(PMUFW) BIT=$(BIT) ATF=$(ATF) \
		UBOOT=$(UBOOT) SYSTEM_DTB=$(SYSTEM_DTB) \
		IMAGE=$(IMAGE) BOOT_SCR=$(SECURE_BOOT_SCR) \
		INCLUDE_IMAGE=$(INCLUDE_IMAGE) \
		AUTH_ONLY=$(AUTH_ONLY) \
		secure_boot

	# inject Red Key as Key 0 in any .nky file
	for idx in $$(find $(SECURE_BOOT_WS)/ -name '*.nky'); do \
		sed -i '/Key 0/s/.*/Key 0        $(RED_KEY);/' $$idx; \
	done

	# generate BOOT.BIN - pass 2
	$(MAKE) -f $(PSMAKE_DIR)/vitis.mk -B CFG=$(SECURE_BOOT_CFG) \
		O=$(SECURE_BOOT_WS) \
		KEYS=$(shell realpath --relative-to $(SECURE_BOOT_WS) $(KEYS)) \
		FSBL=$(FSBL) PMUFW=$(PMUFW) BIT=$(BIT) ATF=$(ATF) \
		UBOOT=$(UBOOT) SYSTEM_DTB=$(SYSTEM_DTB) \
		IMAGE=$(IMAGE) BOOT_SCR=$(SECURE_BOOT_SCR) \
		INCLUDE_IMAGE=$(INCLUDE_IMAGE) \
		AUTH_ONLY=$(AUTH_ONLY) \
		secure_boot

	# deploy generated BOOT.BIN
	mkdir -p $(dir $(SECURE_BOOT_BIN))
	cp -a $(SECURE_BOOT_WS)/secure_boot/BOOT.BIN $(SECURE_BOOT_BIN)

	# deploy informational bootgen output
	#   bootgen -log
	mv bootgen_log.txt $(dir $(SECURE_BOOT_BIN))
ifneq ($(AUTH_ONLY),yes)
	#   bootgen -encryption_dump
	mv kdf_log.txt aes_log.txt $(dir $(SECURE_BOOT_BIN))
endif
