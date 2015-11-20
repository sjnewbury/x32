# Copyright 1999-2013 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: /var/cvsroot/gentoo-x86/eclass/multilib-minimal.eclass,v 1.1 2013/03/09 20:33:29 hasufell Exp $

# @ECLASS: multilib-minimal.eclass
# @MAINTAINER:
# Julian Ospald <hasufell@gentoo.org>
# @BLURB: wrapper for multilib builds providing convenient multilib_src_* functions
# @DESCRIPTION:
#
# src_configure, src_compile, src_test and src_install are exported.
#
# Use multilib_src_* instead of src_* which runs this phase for
# all enabled ABIs.
#
# multilib-minimal should _always_ go last in inherit order!
#
# If you want to use in-source builds, then you must run
# multilib_copy_sources at the end of src_prepare!
# Also make sure to set correct variables such as
# ECONF_SOURCE=${S}
#
# If you need generic install rules, use multilib_src_install_all function.


# EAPI=5 is required for meaningful MULTILIB_USEDEP.
case ${EAPI:-0} in
	5) ;;
	*) die "EAPI=${EAPI} is not supported" ;;
esac



EXPORT_FUNCTIONS src_configure src_compile src_test src_install


multilib-minimal_src_configure() {
	default_src_configure
}

multilib-minimal_src_compile() {
	default_src_compile
}

multilib-minimal_src_test() {
	default_src_test
}

multilib-minimal_src_install() {
	default_src_install
}
