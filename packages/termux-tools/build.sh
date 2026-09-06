TERMUX_PKG_HOMEPAGE=https://termux.dev/
TERMUX_PKG_DESCRIPTION="Basic system tools for Termux"
TERMUX_PKG_LICENSE="GPL-3.0"
TERMUX_PKG_MAINTAINER="@termux"
TERMUX_PKG_VERSION="1.46.0+really1.45.0"
TERMUX_PKG_REVISION=2
TERMUX_PKG_SRCURL=https://github.com/termux/termux-tools/archive/refs/tags/v1.45.0.tar.gz
TERMUX_PKG_SHA256=1ae29b1b875d95cc626dae323b45a2ace759969862d96094b2fa6d13bffe20d2
TERMUX_PKG_ESSENTIAL=true
#TERMUX_PKG_AUTO_UPDATE=true
TERMUX_PKG_UPDATE_TAG_TYPE="newest-tag"
TERMUX_PKG_BREAKS="termux-keyring (<< 1.9)"
TERMUX_PKG_CONFLICTS="procps (<< 3.3.15-2)"
TERMUX_PKG_SUGGESTS="termux-api"

# Some of these packages are not dependencies and used only to ensure
# that core packages are installed after upgrading (we removed busybox
# from essentials).
TERMUX_PKG_DEPENDS="bzip2, coreutils, curl, dash, diffutils, findutils, gawk, grep, gzip, less, procps, psmisc, sed, tar, termux-am (>= 0.8.0), termux-am-socket (>= 1.5.0), termux-core, termux-exec, util-linux, xz-utils, dialog"

# Optional packages that are distributed as part of bootstrap archives.
TERMUX_PKG_RECOMMENDS="ed, dos2unix, inetutils, net-tools, patch, unzip"

termux_step_pre_configure() {
	# termux-tools still consumes the legacy variable names in configure.ac.
	# Export the values derived from properties.sh so a fork does not silently
	# fall back to the upstream com.termux namespace and prefix.
	export TERMUX_APP_PACKAGE="$TERMUX_APP__PACKAGE_NAME"
	export TERMUX_BASE_DIR="$TERMUX__ROOTFS"
	export TERMUX_CACHE_DIR="$TERMUX__CACHE_DIR"
	export TERMUX_PREFIX="$TERMUX__PREFIX"
	export TERMUX_ANDROID_HOME="$TERMUX__HOME"
	export TERMUX_PACKAGE_FORMAT
	export TERMUX_PACKAGE_MANAGER

	# Upstream templates assume application id == Java namespace. Keep the
	# component package (application id) separate from the implementation class
	# name so applicationId-only forks still target real Android components.
	sed -i \
		"s|@TERMUX_APP_PACKAGE@\.app\.TermuxService|$TERMUX_APP__SHELL_API__SHELL_API_SERVICE__CLASS_NAME|g" \
		"$TERMUX_PKG_SRCDIR/scripts/termux-wake-lock.in" \
		"$TERMUX_PKG_SRCDIR/scripts/termux-wake-unlock.in" \
		"$TERMUX_PKG_SRCDIR/scripts/termux-reset.in"
	sed -i \
		"s|@TERMUX_APP_PACKAGE@\.app\.TermuxOpenReceiver|$TERMUX_APP__DATA_SENDER_API__DATA_SENDER_API_RECEIVER__CLASS_NAME|g" \
		"$TERMUX_PKG_SRCDIR/scripts/termux-open.in"
	sed -i \
		-e "s|com\.termux\.permission\.RUN_COMMAND|$TERMUX_APP__PACKAGE_NAME.permission.RUN_COMMAND|g" \
		-e "s|Android/data/com\.termux|Android/data/$TERMUX_APP__PACKAGE_NAME|g" \
		"$TERMUX_PKG_SRCDIR/doc/termux.1.md.in"

	autoreconf -vfi
}

termux_step_post_make_install() {
	# This example is copied verbatim by upstream instead of passing through
	# its template substitution rules.
	sed -i \
		"s|/data/data/com.termux/files/home|$TERMUX__HOME|g" \
		"$TERMUX__PREFIX/share/examples/termux/termux.properties"

	local runtime_file
	for runtime_file in termux-wake-lock termux-wake-unlock termux-reset; do
		if ! grep -F -q \
			"$TERMUX_APP__PACKAGE_NAME/$TERMUX_APP__SHELL_API__SHELL_API_SERVICE__CLASS_NAME" \
			"$TERMUX__PREFIX/bin/$runtime_file"; then
			termux_error_exit "$runtime_file service component does not match the app id and Java namespace"
		fi
	done
	if ! grep -F -q \
		"$TERMUX_APP__PACKAGE_NAME/$TERMUX_APP__DATA_SENDER_API__DATA_SENDER_API_RECEIVER__CLASS_NAME" \
		"$TERMUX__PREFIX/bin/termux-open"; then
		termux_error_exit "termux-open receiver component does not match the app id and Java namespace"
	fi
	TERMUX_PKG_CONFFILES="$(cat "$TERMUX_PKG_BUILDDIR/conffiles")"
}

termux_step_post_massage() {
	local package_root="$TERMUX_PKG_MASSAGEDIR/$TERMUX_PREFIX"
	local grep_status=0
	test -d "$package_root" || termux_error_exit "Missing massaged termux-tools package root"
	grep -r -a -F -q '/data/data/com.termux' "$package_root" || grep_status=$?
	case "$grep_status" in
		0) termux_error_exit "Official Termux paths remain in termux-tools package files";;
		1) ;;
		*) termux_error_exit "Could not scan all termux-tools package files";;
	esac
	if [ "$TERMUX_APP__PACKAGE_NAME" != "$TERMUX_APP__NAMESPACE" ]; then
		local forbidden_component
		for forbidden_component in \
			"$TERMUX_APP__PACKAGE_NAME/$TERMUX_APP__PACKAGE_NAME.app." \
			"$TERMUX_APP__NAMESPACE/$TERMUX_APP__NAMESPACE.app."; do
			grep_status=0
			grep -r -a -F -q "$forbidden_component" "$package_root" || grep_status=$?
			case "$grep_status" in
				0) termux_error_exit "Incorrect Android component remains in termux-tools package: $forbidden_component";;
				1) ;;
				*) termux_error_exit "Could not scan all termux-tools package files";;
			esac
		done
	fi
}

termux_step_create_debscripts() {
	cat <<- EOF > ./preinst
	$(cat "$TERMUX_PKG_BUILDDIR/preinst")
	EOF
}
