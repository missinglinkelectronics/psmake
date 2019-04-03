#!/usr/bin/make -f
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
##  File Summary   : xsct/xsdk convenience wrapper
##
##                   Uses: cat git patch rm xsct xsdk
##
################################################################################


all: build


# include config
CFG ?= default
include $(CFG).mk


###############################################################################


# user arguments
VCS_SKIP ?=

# get version control information
ifeq ($(VCS_SKIP),)
VCS_HEAD := $(shell git rev-parse --verify --short HEAD 2>/dev/null)
endif
ifneq ($(VCS_HEAD),)
VCS_DIRTY := $(shell git diff-index --name-only HEAD | head -n 1)
VCS_VER := _g$(VCS_HEAD)$(patsubst %,-dirty,$(VCS_DIRTY))
else
VCS_VER :=
endif

# get build time stamp
BSTAMP := $(shell date +%Y%m%d-%H%M%S)

# user arguments, usually provided on command line
#  container for build directories (= xsdk workspaces)
CNTR ?= build
#  build directory name
BLDN ?= $(CFG)_$(BSTAMP)$(VCS_VER)
#  relative path to build directory
O ?= $(CNTR)/$(BLDN)
#  path to .hdf file exported from Vivado
HDF ?=

# user arguments, defaults, usually set via config.mk
DEF_BSP_OS ?= standalone
DEF_APP_BCFG ?= Release
DEF_APP_OPT ?= Optimize more (-O2)
DEF_APP_TMPL ?= Empty Application

BSP_PRJS ?=
APP_PRJS ?=

# user arguments, rarely modified
HW_PRJ ?= hw
XSCT ?= xsct
XSDK ?= xsdk
BOOTGEN ?= bootgen

# internal settings
# <none>


###############################################################################

REPOS ?=

ifneq ($(strip $(REPOS)),)
__REPOS_CCMD = $(foreach REPO,$(REPOS), \
	repo -set {$(REPO)};)
endif

$(O)/.metadata/repos.stamp:
ifneq ($(strip $(REPOS)),)
	$(XSCT) -eval 'setws {$(O)}; $(__REPOS_CCMD)'
else
	mkdir -p $(O)/.metadata/
endif
	touch $@

# arg1: hw name
# arg2: path to hdf file
define gen-hw-rule
$(O)/$(1)/system.hdf: $(O)/.metadata/repos.stamp
ifeq ($(HDF),)
	@echo "error: missing HDF, run with HDF=<path-to-hdf>" >&2
	@false
endif
	$(XSCT) -eval 'setws {$(O)}; \
		createhw -name {$(1)} -hwspec {$(2)}; \
		$$($(1)_POST_CREATE_TCL)'

# shortcut to create hw, "make <hw>"
$(1): $(O)/$(1)/system.hdf
.PHONY: $(1)

$(1)_distclean:
	-$(XSCT) -eval 'setws {$(O)}; \
		deleteprojects -name {$(1)}'
.PHONY: $(1)_distclean
endef

# arg1: prj name
# arg2: patch file name, scheme <patchfile>[;<stripnum>]
define patch-src
patch -d $(O)/$(1)/ -p$$(subst ,1,$$(word 2,$$(subst ;, ,$(2)))) \
	<$$(word 1,$$(subst ;, ,$(2))) &&
endef

# arg1: prj name
# arg2: src file name to edit and sed command file, scheme <srcfile>;<sedfile>
define sed-src
sed -i -f $$(lastword $$(subst ;, ,$(2))) \
	$(O)/$(1)/$$(firstword $$(subst ;, ,$(2))) &&
endef

# arg1: bsp name
# arg2: hw name
define gen-bsp-rule
$(1)_PROC ?=
$(1)_OS ?= $(DEF_BSP_OS)
ifeq ($$($(1)_PROC),psu_cortexa53_0)
$(1)_ARCH ?= 64
else
$(1)_ARCH ?= 32
endif
$(1)_LIBS ?=
$(1)_EXTRA_CFLAGS ?=
$(1)_STDIN ?=
$(1)_STDOUT ?=
$(1)_IS_FSBL ?=

ifneq ($$strip($$($(1)_LIBS)),)
__$(1)_LIBS_CCMD = $$(foreach LIB,$$($(1)_LIBS), \
	setlib -bsp {$(1)} -lib {$$(LIB)};)
endif
__$(1)_EXTRA_CCMD =
ifneq ($$($(1)_EXTRA_CFLAGS),)
__$(1)_EXTRA_CCMD += \
	configbsp -bsp {$(1)} extra_compiler_flags {$$($(1)_EXTRA_CFLAGS)};
endif
ifneq ($$($(1)_STDIN),)
__$(1)_EXTRA_CCMD += \
	configbsp -bsp {$(1)} stdin {$$($(1)_STDIN)};
endif
ifneq ($$($(1)_STDOUT),)
__$(1)_EXTRA_CCMD += \
	configbsp -bsp {$(1)} stdout {$$($(1)_STDOUT)};
endif
ifeq ($$($(1)_IS_FSBL),yes)
# non-default BSP settings for FSBL
__$(1)_EXTRA_CCMD += \
	configbsp -bsp {$(1)} {zynqmp_fsbl_bsp} {true}; \
	configbsp -bsp {$(1)} {read_only} {true}; \
	configbsp -bsp {$(1)} {use_mkfs} {false}; \
	configbsp -bsp {$(1)} {extra_compiler_flags} {-g -Wall -Wextra -Os -flto -ffat-lto-objects};
endif
$(O)/$(1)/system.mss: $(O)/$(2)/system.hdf
	$(XSCT) -eval 'setws {$(O)}; \
		createbsp -name {$(1)} -proc {$$($(1)_PROC)} \
			-hwproject {$(2)} -os {$$($(1)_OS)} \
			-arch {$$($(1)_ARCH)}; \
		$$(__$(1)_LIBS_CCMD) \
		$$(__$(1)_EXTRA_CCMD) \
		$$($(1)_POST_CREATE_TCL); \
		regenbsp -bsp {$(1)}'
ifneq ($$(strip $$($(1)_PATCH)),)
	$$(foreach PATCH,$$($(1)_PATCH),$(call patch-src,$(1),$$(PATCH))) :
endif
ifneq ($$(strip $$($(1)_SED)),)
	$$(foreach SED,$$($(1)_SED),$(call sed-src,$(1),$$(SED))) :
endif

$(O)/$(1)/$$($(1)_PROC)/lib/libxil.a: $(O)/$(2)/system.hdf $(O)/$(1)/system.mss
	$(XSCT) -eval 'setws {$(O)}; \
		projects -build -type bsp -name {$(1)}'

# shortcut to build bsp, "make <bsp>"
$(1): $(O)/$(1)/$$($(1)_PROC)/lib/libxil.a
.PHONY: $(1)

$(1)_clean:
	-$(XSCT) -eval 'setws {$(O)}; \
		projects -clean -type bsp -name {$(1)}'
.PHONY: $(1)_clean

$(1)_distclean:
	-$(XSCT) -eval 'setws {$(O)}; \
		deleteprojects -name {$(1)}'
.PHONY: $(1)_distclean
endef

# arg1: app name
define gen-app-proc-contents-rule
$$($(1)_PROC)
endef

# arg1: app name
# arg2: src file name, scheme <srcfile>
define symlink-src
rm -f $(O)/$(1)/src/$$(notdir $(2)) && \
ln -s ../../../../$(2) $(O)/$(1)/src/$$(notdir $(2)) &&
endef

# arg1: app name
# arg2: hw name
define gen-app-rule
$(1)_BSP ?=
$(1)_PROC ?= $(call gen-app-proc-contents-rule,$$($(1)_BSP))
$(1)_BCFG ?= $(DEF_APP_BCFG)
$(1)_OPT ?= $(DEF_APP_OPT)
$(1)_TMPL ?= $(DEF_APP_TMPL)
$(1)_CPPSYMS ?=

ifneq ($$strip($$($(1)_CPPSYMS)),)
__$(1)_CPPSYMS_CCMD = $$(foreach SYM,$$($(1)_CPPSYMS), \
	configapp -app {$(1)} define-compiler-symbols {$$(SYM)};)
endif
$(O)/$(1)/src/lscript.ld: $(O)/$$($(1)_BSP)/system.mss
	$(XSCT) -eval 'setws {$(O)}; \
		createapp -name {$(1)} -app {$$($(1)_TMPL)} \
			-proc {$$($(1)_PROC)} -hwproject {$(2)} \
			-bsp {$$($(1)_BSP)}; \
		configapp -app {$(1)} build-config {$$($(1)_BCFG)}; \
		configapp -app {$(1)} compiler-optimization {$$($(1)_OPT)}; \
		$$(__$(1)_CPPSYMS_CCMD) \
		$$($(1)_POST_CREATE_TCL)'
ifneq ($$(strip $$($(1)_SRC)),)
	$$(foreach SRC,$$($(1)_SRC),$(call symlink-src,$(1),$$(SRC))) :
endif
ifneq ($$(strip $$($(1)_PATCH)),)
	$$(foreach PATCH,$$($(1)_PATCH),$(call patch-src,$(1)/src,$$(PATCH))) :
endif
ifneq ($$(strip $$($(1)_SED)),)
	$$(foreach SED,$$($(1)_SED),$(call sed-src,$(1)/src,$$(SED))) :
endif

$(O)/$(1)/$$($(1)_BCFG)/$(1).elf: $(O)/$$($(1)_BSP)/$$($(1)_PROC)/lib/libxil.a $(O)/$(1)/src/lscript.ld
	$(XSCT) -eval 'setws {$(O)}; \
		projects -build -type app -name {$(1)}'

GEN_APPS_DEP += $(O)/$(1)/src/lscript.ld
BLD_APPS_DEP += $(O)/$(1)/$$($(1)_BCFG)/$(1).elf

# shortcut to build app, "make <app>"
$(1): $(O)/$(1)/$$($(1)_BCFG)/$(1).elf
.PHONY: $(1)

$(1)_clean:
	-$(XSCT) -eval 'setws {$(O)}; \
		projects -clean -type app -name {$(1)}'
.PHONY: $(1)_clean

$(1)_distclean:
	-$(XSCT) -eval 'setws {$(O)}; \
		deleteprojects -name {$(1)}'
.PHONY: $(1)_distclean
endef

# arg1: BIF file name
# arg2: BIF attribute
define gen-bif-attr
\t[$$($(1)_$(2)_BIF_ATTR)] $$($(1)_$(2)_BIF_FILE)\n
endef

define gen-bif-rule
$(1)_FLASH_TYPE ?=
$(1)_FLASH_FSBL ?=
$(1)_FLASH_OFF ?= 0

$(O)/$(1)/$(1).bif: $(BLD_APPS_DEP)
	mkdir -p $(O)/$(1)
	printf '$(1):\n{\n' > $(O)/$(1)/$(1).bif
ifneq ($$(strip $$($(1)_BIF_ATTRS)),)
	printf '$$(foreach BIF_ATTR,$$($(1)_BIF_ATTRS), \
		$(call gen-bif-attr,$(1),$$(BIF_ATTR)))' \
		>> $(O)/$(1)/$(1).bif
endif
	printf '}\n' >> $(O)/$(1)/$(1).bif

$(O)/$(1)/BOOT.BIN: $(O)/$(1)/$(1).bif
ifeq ($$($(1)_BIF_NO_OUTPUT),yes)
	cd $(O) && $(BOOTGEN) -arch $$($(1)_BIF_ARCH) -image $(1)/$(1).bif \
		$$($(1)_BIF_ARGS_EXTRA)
else
	cd $(O) && $(BOOTGEN) -arch $$($(1)_BIF_ARCH) -image $(1)/$(1).bif \
		-o $(1)/BOOT.BIN -w $$($(1)_BIF_ARGS_EXTRA)
endif

GEN_BOOTGEN_DEP += $(O)/$(1)/$(1).bif
BLD_BOOTGEN_DEP += $(O)/$(1)/BOOT.BIN

# NOTE: Target $(1)_flash is written for QSPI flashing in mind - other types
#       might need more or other arguments!
$(1)_flash: $(O)/$(1)/BOOT.BIN
	cd $(O) && \
	program_flash \
		-flash_type $$($(1)_FLASH_TYPE) \
		-fsbl $$($(1)_FLASH_FSBL) \
		-f $(1)/BOOT.BIN -offset $$($(1)_FLASH_OFF) \
		-verify \
		-cable type xilinx_tcf url $(HW_SERVER_URL)
.PHONY: $(1)_flash

# shortcut to build bootgen project, "make <bootgen>"
$(1): $(O)/$(1)/BOOT.BIN
.PHONY: $(1)

$(1)_clean:
	find $(O)/$(1)/* -not -name $(1).bif -delete
.PHONY: $(1)_clean

$(1)_distclean:
	rm -fr $(O)/$(1)
.PHONY: $(1)_distclean
endef

###############################################################################


# generate make rules for hardware project, single
$(eval $(call gen-hw-rule,$(HW_PRJ),$(HDF)))
gethdf: $(HW_PRJ)
.PHONY: gethdf

# generate make rules for bsp projects, multiple
$(foreach BSP_PRJ,$(BSP_PRJS),\
	$(eval $(call gen-bsp-rule,$(BSP_PRJ),$(HW_PRJ))))

# generate make rules for application projects, multiple
$(foreach APP_PRJ,$(APP_PRJS),\
	$(eval $(call gen-app-rule,$(APP_PRJ),$(HW_PRJ))))

# generate make rules for bootgen projects, multiple
$(foreach BOOTGEN_PRJ,$(BOOTGEN_PRJS),\
	$(eval $(call gen-bif-rule,$(BOOTGEN_PRJ))))

# generate all (app) projects
generate: $(GEN_APPS_DEP) $(GEN_BOOTGEN_DEP)
.PHONY: generate

# build all (app) projects
build: $(BLD_APPS_DEP) $(BLD_BOOTGEN_DEP)
.PHONY: build

# open workspace in GUI mode
xsdk:
	$(XSDK) -workspace $(O)
.PHONY: xsdk

# show logs
metalog:
	cat $(O)/.metadata/.log
sdklog:
	cat $(O)/SDK.log
.PHONY: sdklog metalog

# clean all projects
clean:
	$(XSCT) -eval 'setws {$(O)}; \
		projects -clean -type all'
.PHONY: clean

# remove workspace
distclean:
	rm -fr $(O)
.PHONY: distclean
