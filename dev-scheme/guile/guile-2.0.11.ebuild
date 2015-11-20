# Copyright 1999-2011 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: $

EAPI=5
inherit eutils flag-o-matic elisp-common multilib-minimal

DESCRIPTION="GNU Ubiquitous Intelligent Language for Extensions"
HOMEPAGE="http://www.gnu.org/software/guile/"
SRC_URI="mirror://gnu/guile/${P}.tar.xz"

LICENSE="LGPL-3"
KEYWORDS="~amd64"
IUSE="networking +regex +deprecated emacs nls debug-freelist debug-malloc debug +threads"

DEPEND="
	dev-libs/gmp[${MULTILIB_USEDEP}]
	>=sys-devel/libtool-1.5.6
	dev-libs/libltdl[${MULTILIB_USEDEP}]
	sys-devel/gettext
	dev-util/pkgconfig
	dev-libs/libunistring[${MULTILIB_USEDEP}]
	>=dev-libs/boehm-gc-7.0[threads?,${MULTILIB_USEDEP}]
	virtual/libffi[${MULTILIB_USEDEP}]
	emacs? ( virtual/emacs )"
RDEPEND="${DEPEND}"

SLOT="12"
MAJOR="2.0"

ECONF_SOURCE="${S}"

src_prepare() {
	default
	epatch "${FILESDIR}/${P}-x32.patch"
}

multilib_src_configure() {
	# see bug #178499
	filter-flags -ftree-vectorize

	#will fail for me if posix is disabled or without modules -- hkBst
	# install headers in subdir from libdir due to ABI differences
	econf \
		--includedir=/usr/$(get_libdir)/guile/2.0/include
		--disable-error-on-warning \
		--disable-static \
		--enable-posix \
		$(use_enable networking) \
		$(use_enable regex) \
		$(use_enable deprecated) \
		$(use_enable nls) \
		--disable-rpath \
		$(use_enable debug-freelist) \
		$(use_enable debug-malloc) \
		$(use_enable debug guile-debug) \
		$(use_with threads) \
		--with-modules # \
#		EMACS=no
}

multilib_src_compile()  {
	emake || die "make failed"

	# Above we have disabled the build system's Emacs support;
	# for USE=emacs we compile (and install) the files manually
	# if use emacs; then
	# 	cd emacs
	# 	make
	# 	elisp-compile *.el || die
	# fi
}

multilib_src_install_all() {
	dodoc AUTHORS ChangeLog GUILE-VERSION HACKING NEWS README THANKS || die

	# texmacs needs this, closing bug #23493
	dodir /etc/env.d
	echo "GUILE_LOAD_PATH=\"${EPREFIX}/usr/share/guile/${MAJOR}\"" > "${ED}"/etc/env.d/50guile

	# necessary for registering slib, see bug 206896
	keepdir /usr/share/guile/site

	# if use emacs; then
	# 	elisp-install ${PN} emacs/*.{el,elc} || die
	# 	elisp-site-file-install "${FILESDIR}/50${PN}-gentoo.el" || die
	# fi
}

pkg_postinst() {
	[ "${EROOT}" == "/" ] && pkg_config
	use emacs && elisp-site-regen
}

pkg_postrm() {
	use emacs && elisp-site-regen
}

pkg_config() {
	if has_version dev-scheme/slib; then
		einfo "Registering slib with guile"
		install_slib_for_guile
	fi
}

_pkg_prerm() {
	rm -f "${EROOT}"/usr/share/guile/site/slibcat
}
