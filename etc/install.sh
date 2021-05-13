#!/bin/sh

# The original version of this script (https://github.com/Masterminds/glide.sh/blob/master/get) is licensed under the
# MIT license. See https://github.com/Masterminds/glide/blob/master/LICENSE for more details and copyright notice.

#
# Usage:
#
# To install the latest version of Arduino Lint:
#    ./install.sh
#
# To pin a specific release of Arduino Lint:
#    ./install.sh 0.9.0
#

PROJECT_OWNER="arduino"
PROJECT_NAME="arduino-lint"

# BINDIR represents the local bin location, defaults to ./bin.
EFFECTIVE_BINDIR=""
DEFAULT_BINDIR="$PWD/bin"

fail() {
	echo "$1"
	exit 1
}

initDestination() {
	if [ -n "$BINDIR" ]; then
		if [ ! -d "$BINDIR" ]; then
			# The second instance of $BINDIR is intentionally a literal in this message.
			# shellcheck disable=SC2016
			fail "$BINDIR "'($BINDIR)'" folder not found. Please create it before continuing."
		fi
		EFFECTIVE_BINDIR="$BINDIR"
	else
		if [ ! -d "$DEFAULT_BINDIR" ]; then
			mkdir "$DEFAULT_BINDIR"
		fi
		EFFECTIVE_BINDIR="$DEFAULT_BINDIR"
	fi
	echo "Installing in $EFFECTIVE_BINDIR"
}

initArch() {
	ARCH=$(uname -m)
	case $ARCH in
	armv5*) ARCH="armv5" ;;
	armv6*) ARCH="ARMv6" ;;
	armv7*) ARCH="ARMv7" ;;
	aarch64) ARCH="ARM64" ;;
	x86) ARCH="32bit" ;;
	x86_64) ARCH="64bit" ;;
	i686) ARCH="32bit" ;;
	i386) ARCH="32bit" ;;
	esac
	echo "ARCH=$ARCH"
}

initOS() {
	OS=$(uname -s)
	case "$OS" in
	Linux*) OS='Linux' ;;
	Darwin*) OS='macOS' ;;
	MINGW*) OS='Windows' ;;
	MSYS*) OS='Windows' ;;
	esac
	echo "OS=$OS"
}

initDownloadTool() {
	if command -v "curl" >/dev/null 2>&1; then
		DOWNLOAD_TOOL="curl"
	elif command -v "wget" >/dev/null 2>&1; then
		DOWNLOAD_TOOL="wget"
	else
		fail "You need curl or wget as download tool. Please install it first before continuing"
	fi
	echo "Using $DOWNLOAD_TOOL as download tool"
}

checkLatestVersion() {
	# Use the GitHub releases webpage to find the latest version for this project
	# so we don't get rate-limited.
	CHECKLATESTVERSION_REGEX="[0-9][A-Za-z0-9\.-]*"
	CHECKLATESTVERSION_LATEST_URL="https://github.com/${PROJECT_OWNER}/${PROJECT_NAME}/releases/latest"
	if [ "$DOWNLOAD_TOOL" = "curl" ]; then
		CHECKLATESTVERSION_TAG=$(curl -SsL $CHECKLATESTVERSION_LATEST_URL | grep -o "<title>Release $CHECKLATESTVERSION_REGEX · ${PROJECT_OWNER}/${PROJECT_NAME}" | grep -o "$CHECKLATESTVERSION_REGEX")
	elif [ "$DOWNLOAD_TOOL" = "wget" ]; then
		CHECKLATESTVERSION_TAG=$(wget -q -O - $CHECKLATESTVERSION_LATEST_URL | grep -o "<title>Release $CHECKLATESTVERSION_REGEX · ${PROJECT_OWNER}/${PROJECT_NAME}" | grep -o "$CHECKLATESTVERSION_REGEX")
	fi
	if [ "x$CHECKLATESTVERSION_TAG" = "x" ]; then
		echo "Cannot determine latest tag."
		exit 1
	fi
	eval "$1='$CHECKLATESTVERSION_TAG'"
}

get() {
	GET_URL="$2"
	echo "Getting $GET_URL"
	if [ "$DOWNLOAD_TOOL" = "curl" ]; then
		GET_HTTP_RESPONSE=$(curl -sL --write-out 'HTTPSTATUS:%{http_code}' "$GET_URL")
		GET_HTTP_STATUS_CODE=$(echo "$GET_HTTP_RESPONSE" | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')
		GET_BODY=$(echo "$GET_HTTP_RESPONSE" | sed -e 's/HTTPSTATUS\:.*//g')
	elif [ "$DOWNLOAD_TOOL" = "wget" ]; then
		TMP_FILE=$(mktemp)
		GET_BODY=$(wget --server-response --content-on-error -q -O - "$GET_URL" 2>"$TMP_FILE" || true)
		GET_HTTP_STATUS_CODE=$(awk '/^  HTTP/{print $2}' "$TMP_FILE")
	fi
	if [ "$GET_HTTP_STATUS_CODE" != 200 ]; then
		echo "Request failed with HTTP status code $GET_HTTP_STATUS_CODE"
		fail "Body: $GET_BODY"
	fi
	eval "$1='$GET_BODY'"
}

getFile() {
	GETFILE_URL="$1"
	GETFILE_FILE_PATH="$2"
	if [ "$DOWNLOAD_TOOL" = "curl" ]; then
		GETFILE_HTTP_STATUS_CODE=$(curl -s -w '%{http_code}' -L "$GETFILE_URL" -o "$GETFILE_FILE_PATH")
	elif [ "$DOWNLOAD_TOOL" = "wget" ]; then
		wget --server-response --content-on-error -q -O "$GETFILE_FILE_PATH" "$GETFILE_URL"
		GETFILE_HTTP_STATUS_CODE=$(awk '/^  HTTP/{print $2}' "$TMP_FILE")
	fi
	echo "$GETFILE_HTTP_STATUS_CODE"
}

downloadFile() {
	if [ -z "$1" ]; then
		checkLatestVersion TAG
	else
		TAG=$1
	fi
	#  arduino-lint_0.4.0-rc1_Linux_64bit.[tar.gz, zip]
	if [ "$OS" = "Windows" ]; then
		ARDUINO_LINT_DIST="${PROJECT_NAME}_${TAG}_${OS}_${ARCH}.zip"
	else
		ARDUINO_LINT_DIST="${PROJECT_NAME}_${TAG}_${OS}_${ARCH}.tar.gz"
	fi

	# Support specifying nightly build versions (e.g., "nightly-latest") via the script argument.
	case "$TAG" in
	nightly*)
		DOWNLOAD_URL="https://downloads.arduino.cc/${PROJECT_NAME}/nightly/${ARDUINO_LINT_DIST}"
		;;
	*)
		DOWNLOAD_URL="https://downloads.arduino.cc/${PROJECT_NAME}/${ARDUINO_LINT_DIST}"
		;;
	esac

	ARDUINO_LINT_TMP_FILE="/tmp/$ARDUINO_LINT_DIST"
	echo "Downloading $DOWNLOAD_URL"
	httpStatusCode=$(getFile "$DOWNLOAD_URL" "$ARDUINO_LINT_TMP_FILE")
	if [ "$httpStatusCode" -ne 200 ]; then
		echo "Did not find a release for your system: $OS $ARCH"
		echo "Trying to find a release using the GitHub API."
		LATEST_RELEASE_URL="https://api.github.com/repos/${PROJECT_OWNER}/$PROJECT_NAME/releases/tags/$TAG"
		echo "LATEST_RELEASE_URL=$LATEST_RELEASE_URL"
		get LATEST_RELEASE_JSON "$LATEST_RELEASE_URL"
		# || true forces this command to not catch error if grep does not find anything
		DOWNLOAD_URL=$(echo "$LATEST_RELEASE_JSON" | grep 'browser_' | cut -d\" -f4 | grep "$ARDUINO_LINT_DIST") || true
		if [ -z "$DOWNLOAD_URL" ]; then
			echo "Sorry, we dont have a dist for your system: $OS $ARCH"
			fail "You can request one here: https://github.com/${PROJECT_OWNER}/$PROJECT_NAME/issues"
		else
			echo "Downloading $DOWNLOAD_URL"
			getFile "$DOWNLOAD_URL" "$ARDUINO_LINT_TMP_FILE"
		fi
	fi
}

installFile() {
	ARDUINO_LINT_TMP="/tmp/$PROJECT_NAME"
	mkdir -p "$ARDUINO_LINT_TMP"
	if [ "$OS" = "Windows" ]; then
		unzip -d "$ARDUINO_LINT_TMP" "$ARDUINO_LINT_TMP_FILE"
	else
		tar xf "$ARDUINO_LINT_TMP_FILE" -C "$ARDUINO_LINT_TMP"
	fi
	ARDUINO_LINT_TMP_BIN="$ARDUINO_LINT_TMP/$PROJECT_NAME"
	cp "$ARDUINO_LINT_TMP_BIN" "$EFFECTIVE_BINDIR"
	rm -rf "$ARDUINO_LINT_TMP"
	rm -f "$ARDUINO_LINT_TMP_FILE"
}

bye() {
	BYE_RESULT=$?
	if [ "$BYE_RESULT" != "0" ]; then
		echo "Failed to install $PROJECT_NAME"
	fi
	exit $BYE_RESULT
}

testVersion() {
	set +e
	ARDUINO_LINT="$(which $PROJECT_NAME)"
	if [ "$?" = "1" ]; then
		# $PATH is intentionally a literal in this message.
		# shellcheck disable=SC2016
		echo "$PROJECT_NAME not found. You might want to add \"$EFFECTIVE_BINDIR\" to your "'$PATH'
	else
		# Convert to resolved, absolute paths before comparison
		ARDUINO_LINT_REALPATH="$(cd -- "$(dirname -- "$ARDUINO_LINT")" && pwd -P)"
		EFFECTIVE_BINDIR_REALPATH="$(cd -- "$EFFECTIVE_BINDIR" && pwd -P)"
		if [ "$ARDUINO_LINT_REALPATH" != "$EFFECTIVE_BINDIR_REALPATH" ]; then
			# shellcheck disable=SC2016
			echo "An existing $PROJECT_NAME was found at $ARDUINO_LINT. Please prepend \"$EFFECTIVE_BINDIR\" to your "'$PATH'" or remove the existing one."
		fi
	fi

	set -e
	ARDUINO_LINT_VERSION="$("$EFFECTIVE_BINDIR/$PROJECT_NAME" --version)"
	echo "$ARDUINO_LINT_VERSION installed successfully in $EFFECTIVE_BINDIR"
}

# Execution

#Stop execution on any error
trap "bye" EXIT
initDestination
set -e
initArch
initOS
initDownloadTool
downloadFile "$1"
installFile
testVersion
