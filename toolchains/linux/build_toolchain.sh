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

directory_create() {
  if [ "$VERBOSE" = true ]; then
    mkdir -v "$1"
  else
    mkdir "$1"
  fi
}

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

options=$(getopt -l "staging-dir:,target-dir:,help,verbose" -o "s:t:uhv" -a -- "$@")

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
      USE_LTO=true
      ;;

    -h|--help)
      usage
      exit 0
      ;;

    -v|--verbose)
      VERBOSE=true
      ;;
    --)
      shift
      break;;
  esac
  shift
done

if [ -z "$STAGING_DIR" ]; then
  >&2 echo "Staging directory not specified."
  usage
  exit 1
fi

if [ -z "$TARGET_DIR" ]; then
  >&2 echo "Target directory not specified."
  usage
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

# Resolve relative to absolute paths.
STAGING_DIR=$(realpath "${STAGING_DIR}")
TARGET_DIR=$(realpath "${TARGET_DIR}")

echo "Creating staging directory ${STAGING_DIR}..."
directory_create "${STAGING_DIR}"

echo "Creating target directory ${TARGET_DIR}..."
directory_create "${TARGET_DIR}"

cd "${STAGING_DIR}" || return

echo "Downloading CMake v${CMAKE_VER}..."

wget "https://github.com/Kitware/CMake/releases/download/v${CMAKE_VER}/cmake-${CMAKE_VER}.tar.gz"
echo "Extracting CMake v${CMAKE_VER}..."

if [ "$VERBOSE" = true ]; then
  tar xvf "cmake-${CMAKE_VER}.tar.gz"
else
  tar xf "cmake-${CMAKE_VER}.tar.gz"
fi

cd cmake-${CMAKE_VER} || return
echo "Configuring CMake v${CMAKE_VER}, please wait..."

CMAKE_BUILD_FLAGS=(-DCMAKE_BUILD_TYPE:STRING=Release
                   -DCMAKE_INSTALL_PREFIX:STRING="${TARGET_DIR}"/cmake)

if [ "$USE_LTO" = true ]; then
  CMAKE_BUILD_FLAGS+=(-DCMake_BUILD_LTO:BOOL=ON)
fi

if [ "$VERBOSE" = true ]; then
  cmake -S . -B build -G Ninja "${CMAKE_BUILD_FLAGS[@]}"
else
  cmake -S . -B build -G Ninja "${CMAKE_BUILD_FLAGS[@]}" >& /dev/null
fi

echo "Building CMake v${CMAKE_VER}, this may take a while."
cd build || return

if [ "$VERBOSE" = true ]; then
  ninja
else
  ninja >& /dev/null
fi

echo "Installing CMake v${CMAKE_VER} into target directory..."

if [ "$VERBOSE" = true ]; then
  ninja install
else
  ninja install >& /dev/null
fi
