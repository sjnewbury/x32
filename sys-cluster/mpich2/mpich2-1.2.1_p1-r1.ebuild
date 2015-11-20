# Copyright 1999-2013 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: /var/cvsroot/gentoo-x86/sys-cluster/mpich2/mpich2-1.2.1_p1-r1.ebuild,v 1.17 2013/01/06 18:47:14 jsbronder Exp $

EAPI=2

PYTHON_DEPEND="2"
FORTRAN_NEEDED=fortran

inherit eutils fortran-2 python toolchain-funcs

MY_PV=${PV/_/}
DESCRIPTION="MPICH2 - A portable MPI implementation"
HOMEPAGE="http://www.mcs.anl.gov/research/projects/mpich2/index.php"
SRC_URI="http://www.mcs.anl.gov/research/projects/mpich2/downloads/tarballs/${MY_PV}/${PN}-${MY_PV}.tar.gz"

LICENSE="mpich2"
SLOT="0"
KEYWORDS="amd64 hppa ppc ppc64 x86"
IUSE="+cxx debug doc fortran threads romio mpi-threads"

COMMON_DEPEND="dev-libs/libaio
	romio? ( net-fs/nfs-utils )"

DEPEND="${COMMON_DEPEND}
	dev-lang/perl
	sys-devel/libtool"

RDEPEND="
	${COMMON_DEPEND}
	!media-sound/mpd
	!sys-cluster/openmpi"

S="${WORKDIR}"/${PN}-${MY_PV}

pkg_setup() {
	fortran-2_pkg_setup
	python_set_active_version 2
	python_pkg_setup

	if use mpi-threads && ! use threads; then
		ewarn "mpi-threads requires threads, assuming that's what you want"
	fi
	MPD_CONF_FILE_DIR=/etc/${PN}
}

src_prepare() {
	# Upstream trunk, r5843
	epatch "${FILESDIR}"/0001-MPD_CONF_FILE-should-be-readable.patch
	# Upstream trunk, r5844
	epatch "${FILESDIR}"/0002-mpd_conf_file-search-order.patch
	# Upstream trunk, r5845
	epatch "${FILESDIR}"/0003-Fix-pkgconfig-for-mpich2-ch3-v1.2.1.patch
	# Upstream trunk, r6848  #313045
	epatch "${FILESDIR}"/mpich2-1.2.1-fix-missing-libs.patch

	# We need f90 to include the directory with mods, and to
	# fix hardcoded paths for src_test()
	sed -i \
		-e "s,F90FLAGS\( *\)=,F90FLAGS\1?=," \
		-e "s,\$(bindir)/,${S}/bin/,g" \
		-e "s,@MPIEXEC@,${S}/bin/mpiexec,g" \
		$(find ./test/ -name 'Makefile.in') || die

	if ! use romio; then
		# These tests in errhan/ rely on MPI::File ...which is in romio
		echo "" > test/mpi/errors/cxx/errhan/testlist
	fi

	# 293665:  Should check in on MPICH2_MPIX_FLAGS in later releases
	# (>1.3) as this is seeing some development in trunk as of r6350.
	sed -i \
		-e 's|\(WRAPPER_[A-Z90]*FLAGS\)="@.*@"|\1=""|' \
		src/env/mpi*.in || die

}

src_configure() {
	local c="--enable-sharedlibs=gcc"
	local romio_conf

	# The configure statements can be somewhat confusing, as they
	# don't all show up in the top level configure, however, they
	# are picked up in the children directories.

	use debug && c="${c} --enable-g=all --enable-debuginfo"

	if use mpi-threads; then
		# MPI-THREAD requries threading.
	    c="${c} --with-thread-package=pthreads"
		c="${c} --enable-threads=default"
	else
		if use threads ; then
	    	c="${c} --with-thread-package=pthreads"
		else
	    	c="${c} --with-thread-package=none"
		fi
		c="${c} --enable-threads=single"
	fi

	# enable f90 support for appropriate compilers
	case "$(tc-getFC)" in
	    gfortran|if*)
			c="${c} --enable-f77 --enable-f90";;
	    g77)
			c="${c} --enable-f77 --disable-f90";;
	esac

	c="${c} --sysconfdir=/etc/${PN}"
	econf ${c} ${romio_conf} \
		--docdir=/usr/share/doc/${PF} \
		--with-pm=mpd:hydra \
		--disable-mpe \
		$(use_enable romio) \
		$(use_enable cxx)
}

src_compile() {
	# Oh, the irony.
	# http://wiki.mcs.anl.gov/mpich2/index.php/Frequently_Asked_Questions#Q:_The_build_fails_when_I_use_parallel_make.
	# https://trac.mcs.anl.gov/projects/mpich2/ticket/297
	emake -j1 || die
}

src_test() {
	local rc

	cp "${FILESDIR}"/mpd.conf "${T}"/mpd.conf || die
	chmod 600 "${T}"/mpd.conf
	export MPD_CONF_FILE="${T}/mpd.conf"
	"${S}"/bin/mpd --daemon --pid="${T}"/mpd.pid

	make \
		CC="${S}"/bin/mpicc \
		CXX="${S}"/bin/mpicxx \
		FC="${S}"/bin/mpif77 \
		F90="${S}"/bin/mpif90 \
		F90FLAGS="${F90FLAGS} -I${S}/src/binding/f90/" \
		testing
	rc=$?

	"${S}"/bin/mpdallexit || kill $(<"${T}"/mpd.pid)
	return ${rc}
}

src_install() {
	local f
	emake DESTDIR="${D}" install || die

	dodir ${MPD_CONF_FILE_DIR}
	insinto ${MPD_CONF_FILE_DIR}
	doins "${FILESDIR}"/mpd.conf || die

	dodir /usr/share/doc/${PF}
	dodoc COPYRIGHT README CHANGES RELEASE_NOTES || die
	newdoc src/pm/mpd/README README.mpd || die
	if use romio; then
		newdoc src/mpi/romio/README README.romio || die
	fi

	if ! use doc; then
		rm -rf "${D}"/usr/share/doc/www*
	else
		dodir /usr/share/doc/${PF}/www
		mv "${D}"/usr/share/doc/www*/* "${D}"/usr/share/doc/${PF}/www/
	fi

	# See #316937
	MPD_PYTHON_MODULES=""
	for f in "${D}"/usr/bin/*.py; do
		MPD_PYTHON_MODULES="${MPD_PYTHON_MODULES} ${f##${D}}"
	done
}

pkg_postinst() {
	# Here so we can play with ebuild commands as a normal user
	chown root:root "${ROOT}"${MPD_CONF_FILE_DIR}/mpd.conf
	chmod 600 "${ROOT}"${MPD_CONF_FILE_DIR}/mpd.conf

	elog ""
	elog "MPE2 has been removed from this ebuild and now stands alone"
	elog "as sys-cluster/mpe2."
	elog ""

	python_mod_optimize ${MPD_PYTHON_MODULES}
}

pkg_postrm() {
	python_mod_cleanup ${MPD_PYTHON_MODULES}
}
