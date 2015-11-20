# Copyright 1999-2013 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header:
# @ECLASS: multilib-build.eclass
# @MAINTAINER:
# Steven Newbury <steve@snewbury.org.uk>
# @BLURB: stub multilib-build.eclass to provide compatiblity with multilib-portage
# @DESCRIPTION:
# The multilib-build.eclass exports USE flags and utility functions
# necessary to build packages for multilib in a clean and uniform
# manner.  Unfortnately, it is incompatible with multilib-portage, 
# this eclass provides stub functions and ebuild compatiblity between
# the two implementations.
#
# USE dependencies are automatically determined by multilib-portage


if [[ ! ${_MULTILIB_BUILD} ]]; then

# REQUIRED_USE needs EAPI>=4 
[[ ${EAPI} -lt 4 ]] && die "EAPI=${EAPI} is not supported"

inherit multilib

# @ECLASS-VARIABLE: _MULTILIB_FLAGS
# @INTERNAL
# @DESCRIPTION:
# The list of gx86 supported multilib flags and corresponding ABI values.
_MULTILIB_FLAGS=(
	abi_x86_32:x86
	abi_x86_64:amd64
	abi_x86_x32:x32
)

_multilib_build_set_globals() {
	debug-print-function ${FUNCNAME} "${@}"
	local abis abi mabi i
	local flags usedeps other_flags

	for abi in ${MULTILIB_ABIS}; do
		has ${abi} ${MULTILIB_ABI} && abis+=( "${abi}" )
	done
	[[ -z "$abis" ]] && abis=( "${DEFAULT_ABI}" )

	for abi in "${abis[@]}"; do
		for i in "${_MULTILIB_FLAGS[@]}"; do
			local m_abi=${i#*:}
			local m_flag=${i%:*}
			if [[ ${m_abi} == ${abi} ]]; then
				flags+=(+"${m_flag}")
			else
				other_flags+=(-"${m_flag}")
			fi
		done
	done
	usedeps=${flags[@]/+}

	IUSE="${flags[*]} ${other_flags[*]}"
	#REQUIRED_USE="${flags[*]/+}"
	MULTILIB_USEDEP=${usedeps// /,}
}
_multilib_build_set_globals

# @FUNCTION: multilib_get_enabled_abis
# @DESCRIPTION:
# Return the ordered list of enabled ABIs if multilib builds
# are enabled. The best (most preferred) ABI will come last.
#
# If multilib is disabled, the default ABI will be returned
# in order to enforce consistent testing with multilib code.
# 
# Return the current ABI, this can be called from each
# multilib-portage loop
multilib_get_enabled_abis() {
	echo "${ABI}"
}

# @FUNCTION: multilib_foreach_abi
# @USAGE: <argv>...
# @DESCRIPTION:
# This is just a stub, it just runs the commands. No setup
# is done.
multilib_foreach_abi() {
	"${@}"
}

# @FUNCTION: multilib_parallel_foreach_abi
# @USAGE: <argv>...
# @DESCRIPTION:
# This is just a stub, it just runs the commands. No setup
# is done.
multilib_parallel_foreach_abi() {
	"${@}"
}

# @FUNCTION: multilib_for_best_abi
# @USAGE: <argv>...
# @DESCRIPTION:
# abi-wrapper takes care of this.
multilib_for_best_abi() {
	"${@}"
}

# @FUNCTION: multilib_check_headers
# @DESCRIPTION:
# This is a null function, since this is performed by 
# internally by multilib-portage.
multilib_check_headers() {
	:
}
_MULTILIB_BUILD=1
fi

multilib_prepare_wrappers() {
	:
}

multilib_install_wrappers() {
	:
}
