#!/bin/sh
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
# deploying samething. It is to be used on host Unix(-like) systems.

# When pushing a commit to CI, it will check if any of these variables have
# changed since the last commit. If they have, the toolchain is rebuilt.

NINJA_VER="1.11.1"
LLVM_VER="16.0.3"
GCC_VER="13.0.1"
CMAKE_VER="3.26.4"
QT_VER="6.5.0"

# The architectures which are supported by the toolchain.
SUPPORTED_ARCHS="AArch64 X86"

PROJECT_NAME="samething"

# Directory where the build takes place.
STAGING_DIR=""

# Directory where the toolchain is stored.
TARGET_DIR=""

# Accept all prompts, useful for CI.
UNATTENDED=false

# Do not suppress console output of external programs.
VERBOSE=false

directory_create() {
  if [ "$VERBOSE" = true ]; then
    mkdir -v "$1"
  else
    mkdir "$1"
  fi
}

tarball_extract() {
  if [ "$VERBOSE" = true ]; then
    tar xvf "$1"
  else
    tar xf "$1"
  fi
}

download_file() {
  curl_flags="-gLO"

  if [ "$VERBOSE" = false ]; then
    curl_flags="${curl_flags}s"
  fi

  if ! curl "${curl_flags}" "$1"; then
    exit 1
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
  echo "                      build time will be much slower and much more"
  echo "                      intensive on the host. Default is off."
  echo "  -v, --verbose       Do not suppress console output of external "
  echo "                      programs; default is off."
}

if [ "$(id -u)" -eq 0 ]; then
  >&2 echo "Refusing to run as root."
  exit 1
fi

options=$(getopt -l "staging-dir:,target-dir:,use-lto,unattended,help,verbose" -o "s:t:luhv" -a -- "$@")

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

    -l|--use-lto)
      USE_LTO=true
      ;;

    -u|--unattended)
      UNATTENDED=true
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

case $VERBOSE in
  true)
    V() {
      "$@";
    }
    ;;

  *)
    V() {
      "$@" > /dev/null;
    }
    ;;
esac

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
    printf "Have you installed this software? [Y/N] "
    read -r REPLY

    if expr "$REPLY" : '^[Yy]' 1>/dev/null; then
      echo
      break
    elif expr "$REPLY" : '^[Nn]' 1>/dev/null; then
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

if ! cd "${STAGING_DIR}"; then
  exit 1
fi

echo "Downloading CMake v${CMAKE_VER}..."
download_file "https://github.com/Kitware/CMake/releases/download/v${CMAKE_VER}/cmake-${CMAKE_VER}.tar.gz"

echo "Extracting CMake v${CMAKE_VER}..."
tarball_extract "cmake-${CMAKE_VER}.tar.gz"

if ! cd "cmake-${CMAKE_VER}"; then
  exit 1
fi

echo "Configuring CMake v${CMAKE_VER}, please wait..."

CMAKE_BUILD_FLAGS="-DCMAKE_BUILD_TYPE:STRING=Release -DCMAKE_INSTALL_PREFIX:STRING=""${TARGET_DIR}""/cmake"

if [ "$USE_LTO" = true ]; then
  CMAKE_BUILD_FLAGS="$CMAKE_BUILD_FLAGS -DCMake_BUILD_LTO:BOOL=ON"
fi

V cmake -S . -B build -G Ninja $CMAKE_BUILD_FLAGS

echo "Building and installing CMake v${CMAKE_VER}, this may take a while."

if ! cd build; then
  exit 1
fi

if ! V ninja install; then
  exit 1
fi

echo "Installation of CMake v${CMAKE_VER} complete."

if ! cd "${STAGING_DIR}"; then
  exit 1
fi

echo "Downloading ninja v${NINJA_VER}..."
download_file "https://github.com/ninja-build/ninja/archive/refs/tags/v${NINJA_VER}.tar.gz"

echo "Extracting ninja v${NINJA_VER}..."
tarball_extract "v${NINJA_VER}.tar.gz"

if ! cd "ninja-${NINJA_VER}"; then
  exit 1
fi

# Regardless of whether or not LTO is enabled by this script, Ninja will enforce
# LTO if the compiler supports it (which it should). This shouldn't cause harm,
# ninja is quite small to begin with.
NINJA_BUILD_FLAGS="-DCMAKE_BUILD_TYPE:STRING=Release -DCMAKE_INSTALL_PREFIX:STRING=""${TARGET_DIR}""/ninja"

echo "Configuring ninja v${NINJA_VER}, please wait..."

if ! V cmake -S . -B build -G Ninja $NINJA_BUILD_FLAGS; then
  exit 1
fi

echo "Building and installing ninja v${NINJA_VER}, this may take a while."

if ! cd build; then
  exit 1
fi

if ! V ninja install; then
  exit 1
fi

echo "Installation of ninja v${NINJA_VER} complete."
