# Copyright 1999-2016 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Id$

EAPI="7"

MY_PN="${PN}-cross"
MY_P="${MY_PN}-${PV}"

inherit autotools eutils flag-o-matic

DESCRIPTION="Modifies ELFs to avoid runtime symbol resolutions resulting in faster load times"
HOMEPAGE="https://git.yoctoproject.org/cgit/cgit.cgi/prelink-cross/ https://people.redhat.com/jakub/prelink"

if [[ ${PV} == 99999999 ]]; then
	inherit git-r3
	#EGIT_REPO_URI=https://github.com/sjnewbury/prelink-cross.git
	#EGIT_BRANCH=master_staging
	EGIT_REPO_URI=https://git.yoctoproject.org/git/prelink-cross
	EGIT_BRANCH=cross_prelink #_staging
	SRC_URI="doc? ( https://people.redhat.com/jakub/prelink/prelink.pdf )"
	KEYWORDS=
else
	SRC_URI="https://git.yoctoproject.org/cgit/cgit.cgi/${MY_PN}/snapshot/${MY_P}.tar.bz2
		doc? ( https://people.redhat.com/jakub/prelink/prelink.pdf )"
	KEYWORDS="~amd64 -arm ~ppc ~ppc64 ~x86"
	S=${WORKDIR}/${MY_P}
fi

LICENSE="GPL-2"
SLOT="0"
IUSE="doc selinux"

DEPEND=">=dev-libs/elfutils-0.100
	selinux? ( sys-libs/libselinux[static-libs(+)] )
	!dev-libs/libelf
	sys-libs/binutils-libs
	>=sys-libs/glibc-2.8"
RDEPEND="${DEPEND}
	>=sys-devel/binutils-2.18"

PATCHES=(
	"${FILESDIR}"/${PN}-20130503-prelink-conf.patch
	"${FILESDIR}"/${PN}-20130503-libiberty-md5.patch
	"${FILESDIR}"/adjust-x32-mmap-range-r1.patch
	"${FILESDIR}"/prelink-link-bfd.patch
	"${FILESDIR}"/0001-Add-support-for-R_X86_64_TLSDESC.patch
	"${FILESDIR}"/${PN}-bitwise_AND.patch
)


src_prepare() {
	default

	# Disable build of documentation
	sed -i -e '/SUBDIRS/s/doc //' Makefile.am

	sed -i -e '/^CC=/s: : -Wl,--disable-new-dtags :' testsuite/functions.sh #100147

	has_version 'dev-libs/elfutils[threads]' && append-ldflags -pthread

	eautoreconf
}

src_configure() {
	econf $(use_enable selinux)
}

src_install() {
	default

	use doc && dodoc "${WORKDIR}"/prelink.pdf

	insinto /etc
	doins doc/prelink.conf

	exeinto /etc/cron.daily
	newexe "${FILESDIR}"/prelink.cron prelink
	newconfd "${FILESDIR}"/prelink.confd prelink

	dodir /etc/prelink.conf.d
	insinto /etc/prelink.conf.d
	doins "${FILESDIR}"/prelink.conf.d/*
}

pkg_postinst() {
	if [ -z "${REPLACING_VERSIONS}" ] ; then
		elog "You may wish to read the Gentoo Linux Prelink Guide, which can be"
		elog "found online at:"
		elog "    https://wiki.gentoo.org/wiki/Prelink"
		elog "Please edit /etc/conf.d/prelink to enable and configure prelink"
	fi
}
