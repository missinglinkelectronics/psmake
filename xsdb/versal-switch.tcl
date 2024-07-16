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
##  File Name      : versal-switch.tcl
##  Initial Author : Joachim Foerster
##                   <joachim.foerster@missinglinkelectronics.com>
##
################################################################################
##
##  File Summary   : petalinux-* convenience wrapper
##
##                   TCL script for XSDB to force switch boot mode and reset
##                   Versal.
##
################################################################################

# default
set boot_mode "jtag"

set boot_mode_opt ""
foreach arg $argv {
	if {"$boot_mode_opt" ne ""} {
		set boot_mode_opt ""
		set boot_mode $arg
		continue
	}

	if {"$arg" eq "-m"} {
		set boot_mode_opt "yes"
	} else {
		puts stderr "error: Invalid argument \"${arg}\""
		exit 1
	}
}

# translate known symbols to Versal boot mode number
switch -exact $boot_mode {
	"jtag" {
		set boot_mode 0x0
		set boot_mode_text "JTAG"
	}
	"sbi" {
		set boot_mode 0x0
		set boot_mode_text "JTAG"
	}
	"sd1_2.0" {
		set boot_mode 0x5
		set boot_mode_text "SD1 (2.0)"
	}
	"sd1" {
		set boot_mode 0x5
		set boot_mode_text "SD1 (2.0)"
	}
	default {
		set boot_mode_text "[format 0x%x $boot_mode]"
	}
}

if {[regexp -nocase {^(0x[0-9a-f]|[0-9]+)$} $boot_mode]} {
	if {[expr $boot_mode < 16]} {
		set boot_mode_user_reg [expr ($boot_mode << 12) + (0x1 << 8)]
	} else {
		puts "error: Out of range boot mode \"${boot_mode}\""
		exit 1
	}
} else {
	puts "error: Unknown or invalid boot mode \"${boot_mode}\""
	exit 1
}

connect -url $::env(HW_SERVER_URL)

targets -set -filter {name =~ "Versal *"};

# PMC_MULTI_BOOT (PMC_GLOBAL) Register
#   0x00F1110004
puts "Clear PMC_MULTI_BOOT register (0x00f1110004 = 0x0)"
mwr 0x00f1110004 0x0;

# switch boot mode

# BOOT_MODE_USER (CRP) Register
#   0x00f1260200[15:12] == 0x0  => JTAG boot mode
#   0x00f1260200[15:12] == 0x5  => SD1 (2.0) boot mode
#   0x00f1260200[8]     == 0x1  => use [15:12] as boot mode
puts "Switch to ${boot_mode_text} boot mode, BOOT_MODE_USER register (0x00f1260200 = [format 0x%04x $boot_mode_user_reg])"
mwr 0x00f1260200 $boot_mode_user_reg


# trigger system reset
puts "Reset system"
rst -type system

disconnect

exit
