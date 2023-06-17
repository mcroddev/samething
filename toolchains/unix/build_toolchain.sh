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

# WARNING: This script is only meant to be executed by the CI pipeline. Please
# do not run it yourself; execute the `fetch_toolchain.sh` script instead.

# This script builds a toolchain suitable for development and deployment of
# samething. The resulting toolchain is suitable for use on these Unix(-like)
# systems:
#
# - Linux
#
# When pushing a commit, CI will check if this toolchain script has been
# changed. If it has, the toolchain is rebuilt.
#
# To reduce memory usage and have a faster compilation speed of the toolchain,
# all software is compiled with LLVM, except gcc.
llvm_ver="16.0.5"
gcc_ver="13.0.1"
cmake_ver="3.26.4"
ninja_ver="1.11.1"
qt_ver="6.5.1"

# The architectures which are supported by the toolchain.
supported_archs="AArch64 X86"

project_name="samething"

# The name of the tarball to generate. 
tarball_name="samething-toolchain-linux.tar.gz"

# Directory where the build takes place.
staging_dir="staging"

# Directory where the toolchain is stored.
assets_dir="assets"

# Do not suppress console output of external programs.
verbose=false

# Enable link-time optimization (LTO).
use_lto=false

# Enable profile-guided optimization (PGO).
use_pgo=false

create_directory() {
  mkdir "$1" || exit
  echo "Created directory ${1}..."
}

tarball_extract() {
  extract_flags="xf"

  if [ "$verbose" = true ]; then
    extract_flags="${extract_flags}v"
  fi

  tar "${extract_flags}" "$1" || exit
}

download_file() {
  curl_flags="-gLO"

  if [ "$verbose" = false ]; then
    curl_flags="${curl_flags}s"
  fi

  curl "${curl_flags}" "$1" || exit
}

command_line_arguments_handle() {
  # https://mywiki.wooledge.org/BashFAQ/035
  while :; do
    case $1 in
      -\?|--help)
        usage 0
        ;;

      --use-lto)
        use_lto=true
        ;;

      --use-pgo)
        use_pgo=true
        ;;

      --verbose)
        verbose=true
	;;

      --)
        shift
	break
	;;

      -?*)
        echo "Ignoring unknown option: ${1}" >&2
	;;

      *)
        break
    esac
    shift
  done

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

  cd "cmake-${cmake_ver}" || exit
  echo "Configuring CMake v${cmake_ver}, please wait..."

  if [ "$use_lto" = true ]; then
    set -- "$@" "-DCMake_BUILD_LTO:BOOL=ON"
  fi

  LDFLAGS='-fuse-ld=lld' V cmake -S . -B build -G Ninja "$@" || exit
  echo "Building and installing CMake v${cmake_ver}, this may take a while."
  cd build || exit
  V ninja install || exit
  echo "Installation of CMake v${cmake_ver} complete."
  cd "${staging_dir}" || exit
}

ninja_build() {
  echo "Downloading ninja v${ninja_ver}..."
  download_file "https://github.com/ninja-build/ninja/archive/refs/tags/v${ninja_ver}.tar.gz"

  echo "Extracting ninja v${ninja_ver}..."
  tarball_extract "v${ninja_ver}.tar.gz"

  cd "ninja-${ninja_ver}" || exit
  echo "Configuring ninja v${ninja_ver}, please wait..."

  LDFLAGS='-fuse-ld=lld' V cmake -S . -B build -G Ninja "$@" || exit
  echo "Building and installing ninja v${ninja_ver}, this may take a while."

  cd build || exit
  V ninja install || exit
  echo "Installation of ninja v${ninja_ver} complete."
  cd "${staging_dir}" || exit
}

llvm_build() {
  echo "Downloading LLVM ${llvm_ver}..."
  download_file "https://github.com/llvm/llvm-project/releases/download/llvmorg-${llvm_ver}/llvm-project-${llvm_ver}.src.tar.xz"

  echo "Extracting LLVM ${llvm_ver}..."
  tarball_extract "llvm-project-${llvm_ver}.src.tar.xz"

  cp ../cmake/llvm-stage1.cmake llvm-project-${llvm_ver}.src/clang/cmake/caches || exit
  cp ../cmake/llvm-stage2.cmake llvm-project-${llvm_ver}.src/clang/cmake/caches || exit
  cd llvm-project-${llvm_ver}.src || exit

  if [ "$use_lto" = true ]; then
    set -- "$@" "-DSAMETHING_TOOLCHAIN_ENABLE_LTO:BOOL=ON"
  fi

  LDFLAGS='-fuse-ld=lld' V cmake -S llvm -B build -G Ninja -C clang/cmake/caches/llvm-stage1.cmake "$@" || exit
  cd build || exit

  echo "Building LLVM ${llvm_ver}, this will take a long time..."
  V ninja stage2-distribution || exit

  echo "Installing LLVM ${llvm_ver}..."
  V ninja stage2-install-distribution-stripped || exit

  echo "Installation of LLVM ${llvm_ver} complete."
  cd "${staging_dir}" || exit
}

tarball_create() {
  cd "${staging_dir}"/.. || exit
  echo "Creating toolchain deployment tarball..."
  tar czf "${tarball_name}" "assets" || exit
}

usage() {
  cat << EOF
Usage: ./build_toolchain.sh [OPTIONS]

Builds a toolchain suitable for development and deployment of ${project_name}.

This script should only be executed by the CI pipeline. If you are not the CI
pipeline, execute the "fetch_toolchain.sh" script instead.

Optional arguments:
  --use-lto       Compile the toolchain with link-time optimization where
                  appropriate. The toolchain will be faster, but the build time
		  will be much slower and much more intensive on the host.
		  Default is off.
  --use-pgo       Compile the toolchain with profile-guided optimization where
                  appropriate. The toolchain will be faster, but the build time
		  will be much slower and much more intensive on the host.
		  Default is off.
  --verbose       Do not suppress console output of external programs; default
                  is off.
EOF
  exit "$1"
}

check_required() {
  all_commands_found=true

  for required in cmake ninja gcc clang lld re2c; do
    if ! command -v "$required" >/dev/null; then
      echo "Required command ${required} not found."
      all_commands_found=false
    fi
  done

  if [ "${all_commands_found}" = false ]; then
    exit 1
  fi
}

if [ ! -f "build_toolchain.sh" ]; then
  echo "Working directory is not correct."
  exit 1
fi

command_line_arguments_handle "$@"
check_required

staging_dir=$(cd "$(dirname "${staging_dir}")" || exit; pwd)/$(basename "${staging_dir}")
assets_dir=$(cd "$(dirname "${assets_dir}")" || exit; pwd)/$(basename "${assets_dir}")

create_directory "${staging_dir}"
create_directory "${assets_dir}"
cd "${staging_dir}" || exit

cmake_build -DCMAKE_BUILD_TYPE:STRING=Release "-DCMAKE_INSTALL_PREFIX:STRING=""${assets_dir}""/cmake" -DCMAKE_C_COMPILER:STRING="clang" -DCMAKE_CXX_COMPILER:STRING="clang++"
ninja_build -DCMAKE_BUILD_TYPE:STRING=Release "-DCMAKE_INSTALL_PREFIX:STRING=""${assets_dir}""/ninja" -DCMAKE_C_COMPILER:STRING="clang" -DCMAKE_CXX_COMPILER:STRING="clang++"
llvm_build -DCMAKE_BUILD_TYPE:STRING=Release "-DCMAKE_INSTALL_PREFIX:STRING=""${assets_dir}""/llvm" -DCMAKE_C_COMPILER:STRING="clang" -DCMAKE_CXX_COMPILER:STRING="clang++"
tarball_create
echo "Toolchain build complete."
