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

# This cache file is used to build the bootstrap (stage1) compiler using the
# host compiler. The stage1 compiler will then be used to build the stage2
# compiler which will be deployed to toolchains.
option(SAMETHING_TOOLCHAIN_ENABLE_LTO "Enable link-time optimization (LTO)" OFF)

set(LLVM_ENABLE_PROJECTS "clang;lld" CACHE STRING "")
set(LLVM_ENABLE_RUNTIMES "compiler-rt" CACHE STRING "")

# Only build the native target in stage1 since it is a throwaway build.
set(LLVM_TARGETS_TO_BUILD Native CACHE STRING "")

# Optimize the stage1 compiler, but don't LTO it because that wastes time.
set(CMAKE_BUILD_TYPE Release CACHE STRING "")

set(PACKAGE_VENDOR samething CACHE STRING "")

# Setting up the stage2 LTO option needs to be done on the stage1 build so that
# the proper LTO library dependencies can be connected.
set(BOOTSTRAP_LLVM_ENABLE_LLD ON CACHE BOOL "")

if (SAMETHING_TOOLCHAIN_ENABLE_LTO)
  set(BOOTSTRAP_LLVM_ENABLE_LTO ON CACHE "")
endif()

# Expose stage2 targets through the stage1 build configuration.
set(CLANG_BOOTSTRAP_TARGETS
    check-all
    check-llvm
    check-clang
    llvm-config
    test-suite
    test-depends
    llvm-test-depends
    clang-test-depends
    distribution
    install-distribution
    install-distribution-stripped
    clang CACHE STRING "")

set(CLANG_ENABLE_BOOTSTRAP ON CACHE BOOL "")

if (STAGE2_CACHE_FILE)
  set(CLANG_BOOTSTRAP_CMAKE_ARGS
      -C ${STAGE2_CACHE_FILE}
      CACHE STRING "")
else()
  set(CLANG_BOOTSTRAP_CMAKE_ARGS
      -C ${CMAKE_CURRENT_LIST_DIR}/llvm-stage2.cmake
      CACHE STRING "")
endif()
