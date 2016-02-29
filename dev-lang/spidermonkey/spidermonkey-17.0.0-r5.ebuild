# Copyright 1999-2016 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Id$

EAPI="5"
WANT_AUTOCONF="2.1"
PYTHON_COMPAT=( python2_7 )
PYTHON_REQ_USE="threads"
inherit eutils toolchain-funcs multilib python-any-r1 versionator pax-utils multilib-minimal

MY_PN="mozjs"
MY_P="${MY_PN}${PV}"
DESCRIPTION="Stand-alone JavaScript C library"
HOMEPAGE="http://www.mozilla.org/js/spidermonkey/"
SRC_URI="http://ftp.mozilla.org/pub/mozilla.org/js/${MY_PN}${PV}.tar.gz"

LICENSE="NPL-1.1"
SLOT="17"
KEYWORDS="alpha amd64 arm -hppa ia64 -mips ppc ppc64 ~s390 ~sh sparc x86 ~x86-fbsd"
# "MIPS, MacroAssembler is not supported" wrt #491294 for -mips
IUSE="debug jit minimal static-libs test"

REQUIRED_USE="debug? ( jit )"
RESTRICT="ia64? ( test )"

S="${WORKDIR}/${MY_P}"
BUILDDIR="${S}/js/src"

RDEPEND=">=dev-libs/nspr-4.9.4[${MULTILIB_USEDEP}]
	virtual/libffi[${MULTILIB_USEDEP}]
	sys-libs/readline:0[${MULTILIB_USEDEP}]
	>=sys-libs/zlib-1.1.4[${MULTILIB_USEDEP}]"

DEPEND="${RDEPEND}
	${PYTHON_DEPS}
	app-arch/zip
	virtual/pkgconfig"

pkg_setup(){
	if [[ ${MERGE_TYPE} != "binary" ]]; then
		python-any-r1_pkg_setup
		export LC_ALL="C"
	fi
}

_freebsd_prepare() {
		# Don't try to be smart, this does not work in cross-compile anyway
		ln -sfn "${BUILD_DIR}/js/src/config/Linux_All.mk" "${S}/config/$(uname -s)$(uname -r).mk" || die
}

src_prepare() {
	epatch "${FILESDIR}"/${PN}-17.0.0-x32.patch
	epatch "${FILESDIR}"/${PN}-${SLOT}-js-config-shebang.patch
	epatch "${FILESDIR}"/${PN}-${SLOT}-ia64-mmap.patch
	epatch "${FILESDIR}"/${PN}-17.0.0-fix-file-permissions.patch

	# https://bugs.gentoo.org/show_bug.cgi?id=552786
	epatch "${FILESDIR}"/${PN}-perl-defined-array-check.patch
 
	# Remove obsolete jsuword bug #506160
	sed -i -e '/jsuword/d' "${S}"/js/src/jsval.h ||die "sed failed"

	epatch_user

	multilib_copy_sources

	if [[ ${CHOST} == *-freebsd* ]]; then
		multilib_foreach_abi _freebsd_prepare
	fi
}

multilib_src_configure() {
	cd "${BUILD_DIR}/js/src" || die

	CC="$(tc-getCC)" CXX="$(tc-getCXX)" \
	AR="$(tc-getAR)" RANLIB="$(tc-getRANLIB)" \
	LD="$(tc-getLD)" \
	# Install headers in libdir due to ABI differences
	econf \
		${myopts} \
		--includedir="/usr/$(get_libdir)/${PN}/include" \
		--enable-jemalloc \
		--enable-readline \
		--enable-threadsafe \
		--with-system-nspr \
		--enable-system-ffi \
		--enable-jemalloc \
		$(use_enable debug) \
		$(use_enable jit tracejit) \
		$(use_enable jit methodjit) \
		$(use_enable static-libs static) \
		$(use_enable test tests)
}

cross_make() {
	emake \
		CFLAGS="${BUILD_CFLAGS}" \
		CXXFLAGS="${BUILD_CXXFLAGS}" \
		AR="${BUILD_AR}" \
		CC="${BUILD_CC}" \
		CXX="${BUILD_CXX}" \
		RANLIB="${BUILD_RANLIB}" \
		"$@"
}

multilib_src_compile() {
	cd "${BUILD_DIR}/js/src" || die
	if tc-is-cross-compiler; then
		tc-export_build_env BUILD_{AR,CC,CXX,RANLIB}
		cross_make host_jsoplengen host_jskwgen
		cross_make -C config nsinstall
		mv {,native-}jscpucfg || die
		mv {,native-}host_jskwgen || die
		mv {,native-}host_jsoplengen || die
		mv config/{,native-}nsinstall || die
		sed -i \
			-e 's@./jscpucfg@./native-jscpucfg@' \
			-e 's@./host_jskwgen@./native-host_jskwgen@' \
			-e 's@./host_jsoplengen@./native-host_jsoplengen@' \
			Makefile || die
		sed -i -e 's@/nsinstall@/native-nsinstall@' config/config.mk || die
		rm -f config/host_nsinstall.o \
			config/host_pathsub.o \
			host_jskwgen.o \
			host_jsoplengen.o || die
	fi
	emake
}

multilib_src_test() {
	cd "${BUILD_DIR}/js/src/jsapi-tests" || die
	emake check
}

multilib_src_install() {
	cd "${BUILD_DIR}/js/src" || die
	emake DESTDIR="${D}" install
}

multilib_src_install_all() {
	if ! use minimal; then
		if use jit; then
			pax-mark m "${ED}/usr/bin/js${SLOT}"
		fi
	else
		rm -f "${ED}/usr/bin/js${SLOT}"
	fi

	if ! use static-libs; then
		# We can't actually disable building of static libraries
		# They're used by the tests and in a few other places
		find "${D}" -iname '*.a' -delete || die
	fi
}
