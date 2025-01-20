# SPDX-License-Identifier: Apache-2.0
#
################################################################################
##
## Copyright 2019-2025 Missing Link Electronics, Inc.
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
##  File Name      : default_7series.mk
##  Initial Author : Stefan Wiehler <stefan.wiehler@missinglinkelectronics.com>
##
################################################################################
##
##  File Summary   : Example for Vitis Makefile
##
##                   Build with default fixed platform for ZC706:
##
##                       $ make HW_PLAT=zc706
##
##                   Also provide PLATS variable if default does not fit.
##
################################################################################

# FSBL

DOMAIN_PRJS += fsbl_bsp
fsbl_bsp_PROC = ps7_cortexa9_0
fsbl_bsp_IS_FSBL = yes
fsbl_bsp_LIBS = xilffs xilrsa
fsbl_bsp_STDOUT = ps7_uart_1

APP_PRJS += fsbl
fsbl_TMPL = Zynq FSBL
fsbl_DOMAIN = fsbl_bsp
fsbl_BCFG = Debug
fsbl_CPPSYMS = FSBL_DEBUG_INFO

################################################################################
# Hello World

DOMAIN_PRJS += gen_bsp
gen_bsp_PROC = ps7_cortexa9_0
gen_bsp_EXTRA_CFLAGS = -g -Wall -Wextra -Os
gen_bsp_STDOUT = ps7_uart_1

APP_PRJS += helloworld
helloworld_TMPL = Hello World
helloworld_DOMAIN = gen_bsp
helloworld_BCFG = Debug
helloworld_PATCH = helloworld.patch
helloworld_SED = platform.c;baud_rate.sed
helloworld_EXTRA_CFLAGS = -Wall -Wextra
helloworld_OPT = Optimize for size (-Os)

APP_PRJS += example_app
example_app_TMPL = Empty Application(C)
example_app_DOMAIN = gen_bsp
example_app_BCFG = Debug
example_app_SRC = example_app

APP_PRJS += example_app_cpp
example_app_cpp_TMPL = Empty Application (C++)
example_app_cpp_DOMAIN = gen_bsp
example_app_cpp_BCFG = Debug
example_app_cpp_LANG = C++
example_app_cpp_SRC = example_app_cpp

################################################################################
# Boot image

BOOTGEN_PRJS += bootbin

bootbin_BIF_ARCH = zynq
bootbin_BIF_ATTRS = fsbl bit helloworld
bootbin_fsbl_BIF_ATTR = bootloader
bootbin_fsbl_BIF_FILE = fsbl/$(fsbl_BCFG)/fsbl.elf
bootbin_bit_BIF_ATTR =
bootbin_bit_BIF_FILE = $(BIT)
bootbin_helloworld_BIF_ATTR =
bootbin_helloworld_BIF_FILE = helloworld/$(helloworld_BCFG)/helloworld.elf

################################################################################
# JTAG flash

JTAG_FSBL_PRJ = fsbl
JTAG_APP_PRJ = helloworld
JTAG_ARCH = zynq
JTAG_PL_FILE = $(BIT)
JTAG_PL_ARG =

