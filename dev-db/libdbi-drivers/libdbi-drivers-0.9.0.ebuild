# Copyright 1999-2014 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: /var/cvsroot/gentoo-x86/dev-db/libdbi-drivers/libdbi-drivers-0.9.0.ebuild,v 1.12 2014/06/09 23:56:13 vapier Exp $

EAPI=4

inherit eutils autotools

DESCRIPTION="The libdbi-drivers project maintains drivers for libdbi."
SRC_URI="mirror://sourceforge/project/${PN}/${PN}/${P}/${P}.tar.gz"
HOMEPAGE="http://libdbi-drivers.sourceforge.net/"
LICENSE="LGPL-2.1"

IUSE="bindist doc firebird mysql oci8 postgres +sqlite static-libs"
KEYWORDS="alpha amd64 arm arm64 hppa ia64 m68k ~mips ppc ppc64 s390 sh sparc x86 ~x86-fbsd"
SLOT=0

RDEPEND="
	>=dev-db/libdbi-0.9.0
	firebird? ( dev-db/firebird )
	mysql? ( virtual/mysql )
	postgres? ( dev-db/postgresql-base )
	sqlite? ( dev-db/sqlite:3 )
"
DEPEND="${RDEPEND}
	doc? ( app-text/openjade )
"

REQUIRED_USE="
	firebird? ( !bindist )
	|| ( mysql postgres sqlite firebird oci8 )
"

DOCS="AUTHORS ChangeLog NEWS README README.osx TODO"

pkg_setup() {
	use oci8 && [[ -z "${ORACLE_HOME}" ]] && die "\$ORACLE_HOME is not set!"
}

src_prepare() {
		#"${FILESDIR}"/${P}-fix-ac-macro.patch \
		#"${FILESDIR}"/${PN}-0.8.3-oracle-build-fix.patch \
		#"${FILESDIR}"/${PN}-0.8.3-firebird-fix.patch
	epatch \
		"${FILESDIR}"/${PN}-0.9.0-doc-build-fix.patch
	eautoreconf
}

src_configure() {
	local myconf=""
	# WARNING: the configure script does NOT work correctly
	# --without-$driver does NOT work
	# so do NOT use `use_with...`
	# Future additions:
	# msql
	# freetds
	# ingres
	# db2
	# configure script is broken with respect to multilib
	# FIXME? Need to check postgres and firebird lib/include dirs
	use mysql && myconf+=" --with-mysql --with-mysql-libdir=/usr/$(get_libdir)/mysql --with-mysql-incdir=/usr/include/mysql"
	use postgres && myconf+=" --with-pgsql --with-pgsql-libdir=/usr/$(get_libdir)/pgsql --with-pgsql-incdir=/usr/include/pgsql"
	use sqlite && myconf+=" --with-sqlite3 --with-sqlite-libdir=/usr/$(get_libdir) --with-sqlite-incdir=/usr/include"
	use firebird && myconf+=" --with-firebird --with-firebird-libdir=/usr/$(get_libdir)/firebird --with-firebird-incdir=/usr/include/firebird"
	if use oci8; then
		[[ -z "${ORACLE_HOME}" ]] && die "\$ORACLE_HOME is not set!"
		myconf+=" --with-oracle-dir=${ORACLE_HOME} --with-oracle"
	fi

	econf \
		$(use_enable doc docs) \
		$(use_enable static-libs static) \
		--with-dbi-incdir=/usr/include/dbi \
		--with-dbi-libdir=/usr/$(get_libdir) \
		${myconf}
}

src_test() {
	if [[ -z "${WANT_INTERACTIVE_TESTS}" ]]; then
		ewarn "Tests disabled due to interactivity."
		ewarn "Run with WANT_INTERACTIVE_TESTS=1 if you want them."
		return 0
	fi
	einfo "Running interactive tests"
	emake check
}

src_install() {
	default

	prune_libtool_files --all
}
