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

# This cache file is used to build the stage2 compiler using the stage1 compiler.
set(LLVM_ENABLE_PROJECTS
    "clang;clang-tools-extra;lld;lldb"
    CACHE STRING "" FORCE)

set(LLVM_ENABLE_RUNTIMES "compiler-rt" CACHE STRING "" FORCE)

set(LLVM_TARGETS_TO_BUILD X86 CACHE STRING "" FORCE)

set(CMAKE_BUILD_TYPE Release CACHE STRING "" FORCE)
set(CMAKE_C_FLAGS_RELEASE "-O3 -DNDEBUG" CACHE STRING "" FORCE)
set(CMAKE_CXX_FLAGS_RELEASE "-O3 -DNDEBUG" CACHE STRING "" FORCE)

set(LLVM_INSTALL_TOOLCHAIN_ONLY ON CACHE BOOL "" FORCE)

set(LLVM_TOOLCHAIN_TOOLS
    dsymutil
    llvm-cov
    llvm-dwarfdump
    llvm-profdata
    llvm-objdump
    llvm-nm
    llvm-size
    llvm-config
    lldb
    liblldb
    llvm-ar
    llvm-cxxfilt
    llvm-ranlib
    llvm-strings
    llvm-strip
    llvm-mca
    llvm-objcopy
    CACHE STRING "" FORCE)

set(LLVM_DISTRIBUTION_COMPONENTS
    clang
    LTO
    clang-format
    clang-tidy
    clang-resource-headers
    builtins
    runtimes
    ${LLVM_TOOLCHAIN_TOOLS}
    CACHE STRING "" FORCE)
