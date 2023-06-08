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
llvm_ver="16.0.5"
gcc_ver="13.0.1"
cmake_ver="3.26.4"
ninja_ver="1.11.1"
qt_ver="6.5.0"

# The architectures which are supported by the toolchain.
supported_archs="AArch64 X86"

project_name="samething"

# Directory where the build takes place.
staging_dir=""

# Directory where the toolchain is stored.
target_dir=""

# Do not suppress console output of external programs.
verbose=false

# Enable link-time optimization (LTO).
use_lto=false

# Enable profile-guided optimization (PGO).
use_pgo=false

tarball_extract() {
  extract_flags="xf"

  if [ "$verbose" = true ]; then
    extract_flags="${extract_flags}v"
  fi

  if ! tar "${extract_flags}" "$1"; then
    exit 1
  fi
}

download_file() {
  curl_flags="-gLO"

  if [ "$verbose" = false ]; then
    curl_flags="${curl_flags}s"
  fi

  if ! curl "${curl_flags}" "$1"; then
    exit 1
  fi
}

command_line_arguments_handle() {
  # https://mywiki.wooledge.org/BashFAQ/035
  while :; do
    case $1 in
      -h|-\?|--help)
        usage 0
        ;;

      -s|--staging-dir)
        if [ -z "$2" ]; then
          printf '"--staging-dir" requires a path.\n' >&2
	  exit 1
	else
          staging_dir=$2
          shift
	fi
        ;;

      --staging-dir=?*)
        staging_dir=${1#*=}
        ;;

      --staging_dir=)
        printf '"--staging-dir" requires a path.\n' >&2
        exit 1
        ;;

      -t|--target-dir)
        if [ -z "$2" ]; then
          printf '"--target-dir" requires a path.\n' >&2
          exit 1
        else
          target_dir=$2
          shift
        fi
	;;

      --target-dir=?*)
        target_dir=${1#*=}
	;;

      --target-dir=)
        printf '"--target-dir" requires a path.\n' >&2
	exit 1
	;;

      -l|--use-lto)
        use_lto=true
        ;;

      -p|--use-pgo)
        use_pgo=true
        ;;

      -v|--verbose)
        verbose=true
	;;

      --)
        shift
	break
	;;

      -?*)
        printf 'Ignoring unknown option %s\n' "$1" >&2
	;;

      *)
        break
    esac
    shift
  done

  if [ -z "$staging_dir" ]; then
    echo "Staging directory not specified." >&2
    usage 1
  fi

  if [ -z "$target_dir" ]; then
    echo "Target directory not specified." >&2
    usage 1
  fi

  case $verbose in
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
}

cmake_build() {
  echo "Downloading CMake v${cmake_ver}..."
  download_file "https://github.com/Kitware/CMake/releases/download/v${cmake_ver}/cmake-${cmake_ver}.tar.gz"

  echo "Extracting CMake v${cmake_ver}..."
  tarball_extract "cmake-${cmake_ver}.tar.gz"

  if ! cd "cmake-${cmake_ver}"; then
    exit 1
  fi

  echo "Configuring CMake v${cmake_ver}, please wait..."

  if [ "$use_lto" = true ]; then
    set -- "$@" "-DCMake_BUILD_LTO:BOOL=ON"
  fi

  if ! V cmake -S . -B build -G Ninja "$@"; then
    exit 1
  fi

  echo "Building and installing CMake v${cmake_ver}, this may take a while."

  if ! cd build; then
    exit 1
  fi

  if ! V ninja install; then
    exit 1
  fi

  echo "Installation of CMake v${cmake_ver} complete."

  if ! cd "${staging_dir}"; then
    exit 1
  fi
}

ninja_build() {
  echo "Downloading ninja v${ninja_ver}..."
  download_file "https://github.com/ninja-build/ninja/archive/refs/tags/v${ninja_ver}.tar.gz"

  echo "Extracting ninja v${ninja_ver}..."
  tarball_extract "v${ninja_ver}.tar.gz"

  if ! cd "ninja-${ninja_ver}"; then
    exit 1
  fi

  # Regardless of whether or not LTO is enabled by this script, Ninja will
  # enforce LTO if the compiler supports it (which it should). This shouldn't
  # cause harm; ninja is quite small to begin with.
  ninja_build_flags="-DCMAKE_BUILD_TYPE:STRING=Release -DCMAKE_INSTALL_PREFIX:STRING=""${target_dir}""/ninja"

  echo "Configuring ninja v${ninja_ver}, please wait..."

  if ! V cmake -S . -B build -G Ninja $ninja_build_flags; then
    exit 1
  fi

  echo "Building and installing ninja v${ninja_ver}, this may take a while."

  if ! cd build; then
    exit 1
  fi

  if ! V ninja install; then
    exit 1
  fi

  echo "Installation of ninja v${ninja_ver} complete."

  if ! cd "${staging_dir}"; then
    exit 1
  fi
}

llvm_build() {
  echo "Downloading LLVM ${llvm_ver}..."
  download_file "https://github.com/llvm/llvm-project/releases/download/llvmorg-${llvm_ver}/llvm-project-${llvm_ver}.src.tar.xz"

  echo "Extracting LLVM ${llvm_ver}..."
  tarball_extract "llvm-project-${llvm_ver}.src.tar.xz"
}

usage() {
  cat << EOF
Usage: ./build_toolchain.sh [OPTIONS]

Builds a toolchain suitable for development and deployment of ${project_name}.

Required arguments:

  --staging-dir=STAGINGDIR    Directory where the build takes place.
  --target-dir=TARGETDIR      Directory where the toolchain is stored.

Optional arguments:
  -l, --use-lto       Compile the toolchain with link-time optimization
                      where appropriate. The toolchain will be faster,
                      but the build time will be much slower and much
                      more intensive on the host. Default is off.
  -p, --use-pgo       Compile the toolchain with profile-guided
                      optimization where appropriate. The toolchain
		      will be faster, but the build time will be much
                      slower and much more intensive on the host.
                      Default is off.
  -v, --verbose       Do not suppress console output of external
                      programs; default is off.
EOF
  exit "$1"
}

check_required() {
  for required in cmake ninja gcc clang; do
    if ! command -v "$required" >/dev/null; then
      echo "Required command ${required} not found."
      "$required" >&2
      set -- "$@"
      "$required"
    fi
  done

  if [ $# -gt 0 ]; then
    cat <<-EOF >&2
ERROR: One or more required software packages were not detected on your system.
This software is necessary to bootstrap the toolchain. It is highly recommended
that you consult your distribution's package manager to install the required
software. This script will not install the software for you as there are too
many package managers to account for to reasonably automate this process. If you
are unable to install the required software, your only alternative is to
download a prebuilt toolchain.

Required software:

* CMake - https://cmake.org/
* GCC   - https://gcc.gnu.org/
* LLVM  - https://llvm.org/
* Ninja - https://ninja-build.org/
EOF
  fi
}

if [ "$(id -u)" -eq 0 ]; then
  cat <<-EOF >&2
WARNING: You appear to be running this script as a superuser. It is
adviseable, though not required, to run this script as a non-privileged user.

EOF
fi

command_line_arguments_handle "$@"
check_required

staging_dir=$(realpath "${staging_dir}")
target_dir=$(realpath "${target_dir}")

mkdir -v "${staging_dir}"
mkdir -v "${target_dir}"

if ! cd "${staging_dir}"; then
  exit 1
fi

cmake_build -DCMAKE_BUILD_TYPE:STRING=Release "-DCMAKE_INSTALL_PREFIX:STRING=${target_dir}/cmake"
ninja_build
llvm_build
