#!/usr/bin/env bash
set -euo pipefail

log() {
	printf '[install] %s\n' "$1"
}

DO_LINT=false
DO_BUILD=false

while (($#)); do
	case "$1" in
		--lint)
			DO_LINT=true
			;;
		--build)
			DO_BUILD=true
			;;
		*)
			echo "Usage: $0 [--lint] [--build]" >&2
			exit 1
			;;
	esac
	shift
done

# Default to installing everything if no flags are provided to maintain previous behaviour.
if ! $DO_LINT && ! $DO_BUILD; then
	DO_LINT=true
	DO_BUILD=true
fi

# Install the linting and/or build toolchain on a Debian/Ubuntu host via apt.
install_linux() {
	local packages=()
	if $DO_LINT; then
		packages+=(chktex shellcheck)
	fi
	if $DO_BUILD; then
		packages+=(texlive-full)
	fi

	if ((${#packages[@]})); then
		log 'Updating apt package index'
		sudo apt update -y

		log "Installing packages: ${packages[*]}"
		sudo apt install -y "${packages[@]}"
	else
		log 'No packages requested via flags; skipping apt installation.'
	fi

	install_gdrive
}

# Install the linting and/or build toolchain on macOS via Homebrew.
#
# chktex has no standalone Homebrew formula; it only ships bundled inside a TeX
# Live distribution. mactex-no-gui (full TeX Live, needed for --build) provides
# it already. For --lint without --build we use the much smaller basictex cask
# plus `tlmgr install chktex` instead of pulling in all of mactex-no-gui. Note
# basictex and mactex-no-gui conflict with each other (Homebrew casks), so they
# can never both be installed at once.
install_macos() {
	if ! command -v brew >/dev/null; then
		log 'Homebrew is required on macOS but was not found.'
		log 'Install it from https://brew.sh and re-run this script.'
		exit 1
	fi

	if $DO_LINT; then
		log 'Installing Homebrew formulae: shellcheck'
		brew install shellcheck
	fi

	if $DO_BUILD; then
		if brew list --cask basictex &>/dev/null; then
			log 'BasicTeX is installed, but it conflicts with mactex-no-gui.'
			log 'Run: brew uninstall --cask basictex --zap, then re-run this script.'
			exit 1
		fi
		log 'Installing MacTeX (no GUI) for pdflatex (also provides chktex)'
		brew install --cask mactex-no-gui
	elif $DO_LINT; then
		if brew list --cask mactex-no-gui &>/dev/null; then
			log 'mactex-no-gui is already installed; chktex is already available.'
		else
			log 'Installing BasicTeX for chktex (LaTeX linting)'
			brew install --cask basictex
			eval "$(/usr/libexec/path_helper)"
			log 'Installing chktex via tlmgr'
			sudo tlmgr install chktex
		fi
	fi

	# gdrive uploads run in CI only (see .github/workflows/main.yaml), and glotlabs
	# ships no arm64 macOS build, so skip installing gdrive locally on macOS.
	log 'Skipping gdrive install on macOS; uploads run in CI.'
}

# Download and install the glotlabs gdrive binary (Linux only).
install_gdrive() {
	local url_to_gdrive_binary="https://github.com/glotlabs/gdrive/releases/download/3.9.1/gdrive_linux-x64.tar.gz"
	local install_path="/usr/local/bin/gdrive"
	local tmp_dir
	tmp_dir="$(mktemp -d)"

	# shellcheck disable=SC2317  # invoked via the trap below
	cleanup() {
		rm -rf "${tmp_dir}"
	}
	trap cleanup EXIT

	log 'Downloading gdrive binary'
	local archive_path="${tmp_dir}/gdrive.tar.gz"
	wget "${url_to_gdrive_binary}" -O "${archive_path}"

	log 'Extracting gdrive archive'
	tar -xzf "${archive_path}" -C "${tmp_dir}"

	log "Installing gdrive to ${install_path}"
	sudo install -m 0755 "${tmp_dir}/gdrive" "${install_path}"

	if command -v gdrive >/dev/null && [[ "$(command -v gdrive)" == "${install_path}" ]]; then
		log "gdrive installed to ${install_path}."
		log "Run 'gdrive about' to verify setup or 'gdrive help' for usage information."
	else
		log 'gdrive installation check failed'
		exit 1
	fi
}

OS="$(uname -s)"
case "${OS}" in
	Linux)
		install_linux
		;;
	Darwin)
		install_macos
		;;
	*)
		log "Unsupported operating system: ${OS}"
		log 'This script supports Linux (apt) and macOS (Homebrew).'
		exit 1
		;;
esac
