# Copyright 1999-2017 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Id$

EAPI=6

CMAKE_REMOVE_MODULES="no"
inherit bash-completion-r1 elisp-common toolchain-funcs eutils versionator cmake-utils virtualx flag-o-matic

MY_P="${P/_/-}"

DESCRIPTION="Cross platform Make"
HOMEPAGE="http://www.cmake.org/"
SRC_URI="http://www.cmake.org/files/v$(get_version_component_range 1-2)/${MY_P}.tar.gz"

LICENSE="CMake"
SLOT="0"
[[ "${PV}" = *_rc* ]] || \
KEYWORDS="~alpha ~amd64 ~arm ~arm64 ~hppa ~m68k ~mips ~ppc ~ppc64 ~s390 ~sh ~sparc ~x86 ~amd64-fbsd ~sparc-fbsd ~x86-fbsd ~amd64-linux ~arm-linux ~x86-linux ~ppc-macos ~x64-macos ~x86-macos ~sparc-solaris ~x64-solaris ~x86-solaris"
IUSE="doc emacs system-jsoncpp ncurses qt5"

RDEPEND="
	app-crypt/rhash
	>=app-arch/libarchive-3.0.0:=
	>=dev-libs/expat-2.0.1
	>=dev-libs/libuv-1.0.0:=
	>=net-misc/curl-7.21.5[ssl]
	sys-libs/zlib
	virtual/pkgconfig
	emacs? ( virtual/emacs )
	ncurses? ( sys-libs/ncurses:0= )
	qt5? (
		dev-qt/qtcore:5
		dev-qt/qtgui:5
		dev-qt/qtwidgets:5
	)
	system-jsoncpp? ( >=dev-libs/jsoncpp-0.6.0_rc2:0= )
"
DEPEND="${RDEPEND}
	doc? ( dev-python/sphinx )
"

S="${WORKDIR}/${MY_P}"

SITEFILE="50${PN}-gentoo.el"

PATCHES=(
	# prefix
	"${FILESDIR}"/${PN}-3.4.0_rc1-darwin-bundle.patch
	"${FILESDIR}"/${PN}-3.0.0-prefix-dirs.patch
	"${FILESDIR}"/${PN}-3.1.0-darwin-isysroot.patch

	# handle gentoo packaging in find modules
	"${FILESDIR}"/${PN}-2.8.12.1-FindImageMagick.patch
	"${FILESDIR}"/${PN}-3.0.0-FindBLAS.patch
	"${FILESDIR}"/${PN}-3.0.0-FindBoost-python.patch
	"${FILESDIR}"/${PN}-3.0.2-FindLAPACK.patch
	"${FILESDIR}"/${PN}-3.5.2-FindQt4.patch

	# respect python eclasses
	"${FILESDIR}"/${PN}-2.8.10.2-FindPythonLibs.patch
	"${FILESDIR}"/${PN}-3.1.0-FindPythonInterp.patch

	# x32 support
	"${FILESDIR}"/0001-Add-support-for-x32-abi.patch
	"${FILESDIR}"/0002-Modules-Add-x32-abi-support-to-hard-coded-paths.patch
	"${FILESDIR}"/0003-Help-Add-notes-for-topic-x32-abi.patch
	

	# upstream fixes (can usually be removed with a version bump)
)

cmake_src_bootstrap() {
	# Cleanup args to extract only JOBS.
	# Because bootstrap does not know anything else.
	echo ${MAKEOPTS} | egrep -o '(\-j|\-\-jobs)(=?|[[:space:]]*)[[:digit:]]+' > /dev/null
	if [ $? -eq 0 ]; then
		par_arg=$(echo ${MAKEOPTS} | egrep -o '(\-j|\-\-jobs)(=?|[[:space:]]*)[[:digit:]]+' | tail -n1 | egrep -o '[[:digit:]]+')
		par_arg="--parallel=${par_arg}"
	else
		par_arg="--parallel=1"
	fi

	# disable running of cmake in boostrap command
	sed -i \
		-e '/"${cmake_bootstrap_dir}\/cmake"/s/^/#DONOTRUN /' \
		bootstrap || die "sed failed"

	# execinfo.h on Solaris isn't quite what it is on Darwin
	if [[ ${CHOST} == *-solaris* ]] ; then
		sed -i -e 's/execinfo\.h/blablabla.h/' Source/kwsys/CMakeLists.txt || die
	fi

	tc-export CC CXX LD

	# bootstrap script isn't exactly /bin/sh compatible
	${CONFIG_SHELL:-sh} ./bootstrap \
		--prefix="${T}/cmakestrap/" \
		${par_arg} \
		|| die "Bootstrap failed"
}

cmake_src_test() {
	# fix OutDir and SelectLibraryConfigurations tests
	# these are altered thanks to our eclass
	sed -i -e 's:#IGNORE ::g' \
		"${S}"/Tests/{OutDir,CMakeOnly/SelectLibraryConfigurations}/CMakeLists.txt \
		|| die

	pushd "${BUILD_DIR}" > /dev/null

	local ctestargs
	[[ -n ${TEST_VERBOSE} ]] && ctestargs="--extra-verbose --output-on-failure"

	# Excluded tests:
	#    BootstrapTest: we actualy bootstrap it every time so why test it.
	#    BundleUtilities: bundle creation broken
	#    CTest.updatecvs: which fails to commit as root
	#    Fortran: requires fortran
	#    Qt4Deploy, which tries to break sandbox and ignores prefix
	#    TestUpload, which requires network access
	"${BUILD_DIR}"/bin/ctest ${ctestargs} \
		-E "(BootstrapTest|BundleUtilities|CTest.UpdateCVS|Fortran|Qt4Deploy|TestUpload)" \
		|| die "Tests failed"

	popd > /dev/null
}

src_prepare() {
	cmake-utils_src_prepare

	# Add gcc libs to the default link paths
	sed -i \
		-e "s|@GENTOO_PORTAGE_GCCLIBDIR@|${EPREFIX}/usr/${CHOST}/lib/|g" \
		-e "s|@GENTOO_PORTAGE_EPREFIX@|${EPREFIX}/|g" \
		Modules/Platform/{UnixPaths,Darwin}.cmake || die "sed failed"
	if ! has_version \>=${CATEGORY}/${PN}-3.4.0_rc1 ; then
		CMAKE_BINARY="${S}/Bootstrap.cmk/cmake"
		cmake_src_bootstrap
	fi
}

src_configure() {
	# Fix linking on Solaris
	[[ ${CHOST} == *-solaris* ]] && append-ldflags -lsocket -lnsl

	local mycmakeargs=(
		-DCMAKE_USE_SYSTEM_LIBRARIES=ON
		-DCMAKE_USE_SYSTEM_LIBRARY_JSONCPP=$(usex system-jsoncpp)
		-DCMAKE_INSTALL_PREFIX="${EPREFIX}"/usr
		-DCMAKE_DOC_DIR=/share/doc/${PF}
		-DCMAKE_MAN_DIR=/share/man
		-DCMAKE_DATA_DIR=/share/${PN}
		-DSPHINX_MAN=$(usex doc)
		-DSPHINX_HTML=$(usex doc)
		-DBUILD_CursesDialog="$(usex ncurses)"
	)

	if use qt5 ; then
		mycmakeargs+=(
			-DBUILD_QtDialog=ON
			$(cmake-utils_use_find_package qt5 Qt5Widgets)
		)
	fi

	cmake-utils_src_configure
}

src_compile() {
	cmake-utils_src_compile
	use emacs && elisp-compile Auxiliary/cmake-mode.el
}

src_test() {
	virtx cmake_src_test
}

src_install() {
	cmake-utils_src_install

	if use emacs; then
		elisp-install ${PN} Auxiliary/cmake-mode.el Auxiliary/cmake-mode.elc
		elisp-site-file-install "${FILESDIR}/${SITEFILE}"
	fi

	insinto /usr/share/vim/vimfiles/syntax
	doins Auxiliary/vim/syntax/cmake.vim

	insinto /usr/share/vim/vimfiles/indent
	doins Auxiliary/vim/indent/cmake.vim

	insinto /usr/share/vim/vimfiles/ftdetect
	doins "${FILESDIR}/${PN}.vim"

	dobashcomp Auxiliary/bash-completion/{${PN},ctest,cpack}

	rm -r "${ED}"/usr/share/cmake/{completions,editors} || die
}

pkg_postinst() {
	use emacs && elisp-site-regen
}

pkg_postrm() {
	use emacs && elisp-site-regen
}
