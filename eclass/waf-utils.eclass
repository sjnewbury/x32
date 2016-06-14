# Copyright 1999-2012 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: /var/cvsroot/gentoo-x86/eclass/waf-utils.eclass,v 1.17 2012/12/06 09:28:11 scarabeus Exp $

# @ECLASS: waf-utils.eclass
# @MAINTAINER:
# gnome@gentoo.org
# @AUTHOR:
# Original Author: Gilles Dartiguelongue <eva@gentoo.org>
# Various improvements based on cmake-utils.eclass: Tomáš Chvátal <scarabeus@gentoo.org>
# Proper prefix support: Jonathan Callen <abcd@gentoo.org>
# @BLURB: common ebuild functions for waf-based packages
# @DESCRIPTION:
# The waf-utils eclass contains functions that make creating ebuild for
# waf-based packages much easier.
# Its main features are support of common portage default settings.

inherit eutils multilib toolchain-funcs multiprocessing

[[ ${EAPI} -lt 6 ]] && inherit base

case ${EAPI:-0} in
	3|4|5|6) EXPORT_FUNCTIONS src_configure src_compile src_install ;;
	*) die "EAPI=${EAPI} is not supported" ;;
esac

# Python with threads is required to run waf. We do not know which python slot
# is being used as the system interpreter, so we are forced to block all
# slots that have USE=-threads.
DEPEND="${DEPEND}
	dev-lang/python
	!dev-lang/python[-threads]"

# @ECLASS-VARIABLE: WAF_VERBOSE
# @DESCRIPTION:
# Set to OFF to disable verbose messages during compilation
# this is _not_ meant to be set in ebuilds
: ${WAF_VERBOSE:=ON}

# @FUNCTION: waf-utils_waflibdir
# @USAGE: [<waf-binary>]
# @DESCRIPTION:
# Echoes the absolute path to the directory containing the waf-based
# project's waflib python module. Ensures that the waflib shipped with a
# project is unpacked if it isn't already. This waflib may be safely
# patched because waf-lite will not touch the waflib directory if it
# already exists. Uses the waf binary specified in WAF_BINARY.
#
# @EXAMPLE
# The simplest case, for a monolithic compilation:
#
# @CODE
# pushd "$(waf-utils_waflibdir)" || die "Unable to patch waflib"
# epatch "${FILESDIR}"/${P}-waf-fix.patch
# popd
# @CODE
#
# Note that if you are using the python eclass and installating python
# modules, you must either call python_set_active_version or call
# waf-utils_waflibdir() from within a function run by
# python_execute(). This is because waf uses a different directory for
# waflib when using python3 than when using python2.
#
# @CODE
# SUPPORT_PYTHON_ABIS=1
# inherit eutils python waf-utils
#
# # Always use the waf associated with the current python ABI.
# WAF_BINARY=./waf
#
# src_prepare() {
# 	python_copy_sources
#
# 	myprepare() {
# 		epatch "${FILESDIR}"/${P}-sourcecode-fix.patch
#
# 		pushd "$(waf-utils_waflibdir)" || die "Unable to patch waflib"
# 		epatch "${FILESDIR}"/${P}-waf-fix.patch
# 		popd
# 	}
# 	python_execute_function -s myprepare
# }
# @CODE
waf-utils_waflibdir() {
	debug-print-function ${FUNCNAME} "$@"

	: ${WAF_BINARY:="${S}/waf"}

	#HACK
	if [[ ${EPYTHON} == "python3.3" ]]; then 
      	python3.2 -c "import imp, sys; sys.argv[0] = '${WAF_BINARY}'; waflite = imp.load_source('waflite', '${WAF_BINARY}'); print(waflite.find_lib());" \
		|| die "Unable to unpack or locate waflib module from the waf script at ${WAF_BINARY}"
	else
      	python -c "import imp, sys; sys.argv[0] = '${WAF_BINARY}'; waflite = imp.load_source('waflite', '${WAF_BINARY}'); print(waflite.find_lib());" \
		|| die "Unable to unpack or locate waflib module from the waf script at ${WAF_BINARY}"
	fi
}

# @FUNCTION: waf-utils_src_configure
# @DESCRIPTION:
# General function for configuring with waf.
waf-utils_src_configure() {
	debug-print-function ${FUNCNAME} "$@"

	local libdir=""

	# @ECLASS-VARIABLE: WAF_BINARY
	# @DESCRIPTION:
	# Eclass can use different waf executable. Usually it is located in "${S}/waf".
	: ${WAF_BINARY:="${S}/waf"}

	# @ECLASS-VARIABLE: NO_WAF_LIBDIR
	# @DEFAULT_UNSET
	# @DESCRIPTION:
	# Variable specifying that you don't want to set the libdir for waf script.
	# Some scripts does not allow setting it at all and die if they find it.
	[[ -z ${NO_WAF_LIBDIR} ]] && libdir="--libdir=${EPREFIX}/usr/$(get_libdir)"

	tc-export AR CC CPP CXX RANLIB
	echo "CCFLAGS=\"${CFLAGS}\" LINKFLAGS=\"${LDFLAGS}\" \"${WAF_BINARY}\" --prefix=${EPREFIX}/usr ${libdir} $@ configure"

	# This condition is required because waf takes even whitespace as function
	# calls, awesome isn't it?
	if [[ -z ${NO_WAF_LIBDIR} ]]; then
		CCFLAGS="${CFLAGS}" LINKFLAGS="${LDFLAGS}" "${WAF_BINARY}" \
			"--prefix=${EPREFIX}/usr" \
			"${libdir}" \
			"$@" \
			configure || die "configure failed"
	else
		CCFLAGS="${CFLAGS}" LINKFLAGS="${LDFLAGS}" "${WAF_BINARY}" \
			"--prefix=${EPREFIX}/usr" \
			"$@" \
			configure || die "configure failed"
	fi
}

# @FUNCTION: waf-utils_src_compile
# @DESCRIPTION:
# General function for compiling with waf.
waf-utils_src_compile() {
	debug-print-function ${FUNCNAME} "$@"
	local _mywafconfig
	[[ "${WAF_VERBOSE}" ]] && _mywafconfig="--verbose"

	local jobs="--jobs=$(makeopts_jobs)"
	echo "\"${WAF_BINARY}\" build ${_mywafconfig} ${jobs}"
	"${WAF_BINARY}" ${_mywafconfig} ${jobs} || die "build failed"
}

# @FUNCTION: waf-utils_src_install
# @DESCRIPTION:
# Function for installing the package.
waf-utils_src_install() {
	debug-print-function ${FUNCNAME} "$@"

	echo "\"${WAF_BINARY}\" --destdir=\"${D}\" install"
	"${WAF_BINARY}" --destdir="${D}" install  || die "Make install failed"

	# Manual document installation
	base_src_install_docs
}
