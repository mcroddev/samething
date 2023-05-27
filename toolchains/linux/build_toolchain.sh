#!/bin/bash
#
# SPDX-License-Identifier: MIT
#
# Copyright 2023 Michael Rodriguez
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the “Software”), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

# This script is to be used to build a toolchain suitable for developing and
# deploying samething. It is to be used on host Linux systems.

# When pushing a commit to CI, it will check if any of these variables have
# changed since the last commit. If they have, the toolchain is rebuilt.

LLVM_VER="16.0.3"
GCC_VER="13.0.1"
CMAKE_VER="3.26.4"
QT_VER="6.5.0"

# The architectures which are supported by the toolchain.
SUPPORTED_ARCHS=(AArch64 X86)

PROJECT_NAME="samething"

# Directory where the build takes place.
STAGING_DIR=""

# Directory where the toolchain is stored.
TARGET_DIR=""

# Accept all prompts, useful for CI.
UNATTENDED=false

# Do not suppress console output of external programs.
VERBOSE=false

# The function to call when an error has occurred.
error_occurred() {
  exit 1
}

# When an error occurs, call the `error_occurred` function.
trap "error_occurred" ERR

usage() {
  echo "Usage: ./build_toolchain.sh [OPTIONS]"
  echo
  echo "Builds a toolchain suitable for development and deployment of "
  echo "$PROJECT_NAME."
  echo
  echo "Required arguments: "
  echo
  echo "  --staging-dir=STAGINGDIR    Directory where the build takes place."
  echo "  --target-dir=TARGETDIR      Directory where the toolchain is stored."
  echo
  echo "Optional arguments:"
  echo "  -u, --unattended    Accept all prompts, useful for CI. Default is off."
  echo "  --use-lto           Compile the toolchain with link-time optimization"
  echo "                      enabled. The toolchain will be faster, but the "
  echo "                      build time will be much slower. Default is off."
  echo "  -v, --verbose        Do not suppress console output of external "
  echo "                       programs; default is off."
}

# $@ is all command line parameters passed to the script.
# -o is for short options like -v
# -l is for long options with double dash like --version
# the comma separates different long options
# -a is for long options with single dash like -version
options=$(getopt -l "staging-dir:,target-dir:,help,verbose" -o "s:t:uhv" -a -- "$@")

# set --:
# If no arguments follow this option, then the positional parameters are unset. Otherwise, the positional parameters
# are set to the arguments, even if some of them begin with a ‘-’.
eval set -- "$options"

while true
  do
    case "$1" in
    -s|--staging-dir)
      shift
      STAGING_DIR="$1"
      ;;

    -t|--target-dir)
      shift
      TARGET_DIR="$1"
      ;;

    -u|--use-lto)
      USE_LTO=1
      ;;

    -h|--help)
      usage
      exit 0
      ;;

    -v|--verbose)
      VERBOSE=1
      ;;
    --)
      shift
      break;;
  esac
  shift
done

if [ -z "$STAGING_DIR" ]; then
  >&2 echo "Staging directory not specified; aborting."
  exit 1
fi

if [ -z "$TARGET_DIR" ]; then
  >&2 echo "Target directory not specified; aborting."
  exit 1
fi

install_software_display() {
  echo "WARNING: This script requires the existence of certain software on your"
  echo "system to bootstrap the toolchain. It is highly recommended that you "
  echo "consult your distribution's package manager to install the required "
  echo "software. This script will not install the software for you as there"
  echo "are too many package managers to account for to reasonably automate"
  echo "this process. If you are unable to install the required software, your "
  echo "only alternative is to download a prebuilt toolchain."
  echo
  echo "Required software:"
  echo
  echo "* CMake - https://cmake.org/"
  echo "* GCC   - https://gcc.gnu.org/"
  echo "* LLVM  - https://llvm.org/"
  echo "* Ninja - https://ninja-build.org/"
  echo
}

if [ "$UNATTENDED" = false ]; then
  install_software_display

  while true
  do
    read -p "Have you installed this software? [Y/N] " -n 1 -r
    echo

    if [[ $REPLY =~ ^[Yy] ]]; then
      break
    elif [[ $REPLY =~ ^[Nn] ]]; then
      >&2 echo "Aborting due to required software not being installed."
      exit 1
    else
      >&2 echo "Invalid input; please press Y or N, or press Ctrl+C to exit."
    fi
  done
fi

printf "Creating staging directory %s... \n" "${STAGING_DIR}"

if [ "$VERBOSE" = true ]; then
  mkdir -v "${STAGING_DIR}"
else
  mkdir "${STAGING_DIR}"
fi

cd "${STAGING_DIR}" || return
