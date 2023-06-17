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

# The FATAL_ERROR option is accepted but ignored by CMake 2.6 and higher. It
# should be specified so CMake versions 2.4 and lower fail with an error instead
# of just a warning.
#
# All toolchains ship with CMake 3.26.4, so this is safe.
cmake_minimum_required(VERSION 3.26.4 FATAL_ERROR)

if (CMAKE_CURRENT_SOURCE_DIR STREQUAL CMAKE_CURRENT_BINARY_DIR)
  message(FATAL_ERROR "In-source builds are not supported.")
endif()

project(samething
        VERSION 1.0.0.0
        DESCRIPTION "Specific Area Message Encoding header generator"
        HOMEPAGE_URL "https://github.com/mcroddev/samething"
        LANGUAGES CXX)

if (NOT CMAKE_TOOLCHAIN_FILE)
  message(FATAL_ERROR "You must specify a toolchain file via "
                      "-DCMAKE_TOOLCHAIN_FILE.")
endif()

option(SAMETHING_BUILD_TESTS "Build the unit tests" OFF)
option(SAMETHING_BUILD_BENCHMARKS "Build the benchmarks" OFF)
option(SAMETHING_USE_LTO "Build with link-time optimization (LTO)" OFF)
option(SAMETHING_BUILD_QT_FRONTEND "Build the Qt frontend" OFF)

set(SAMETHING_COMPILER_SUITE "LLVM"
    CACHE STRING "Specifies the compiler suite to use.")

set_property(CACHE SAMETHING_COMPILER_SUITE
             PROPERTY STRINGS
             "GNU" "LLVM")

if (NOT SAMETHING_COMPILER_SUITE STREQUAL "LLVM" AND
    NOT SAMETHING_COMPILER_SUITE STREQUAL "GNU")
  message(FATAL_ERROR "Invalid compiler suite specified; valid options are GNU "
                      "or LLVM.")
endif()

if (SAMETHING_BUILD_TESTS)
  # Since googletest follows the Abseil Live at Head philosophy, this is the
  # only "right" way to pull it in.
  include(FetchContent)

  FetchContent_Declare(
    googletest
    GIT_REPOSITORY https://github.com/google/googletest.git
    GIT_TAG main
  )
  FetchContent_MakeAvailable(googletest)
endif()

if (SAMETHING_BUILD_BENCHMARKS)
  include(FetchContent)

  FetchContent_Declare(
    benchmark
    GIT_REPOSITORY https://github.com/google/benchmark.git
    GIT_TAG v1.8.0
  )
  FetchContent_MakeAvailable(benchmark)
endif()

# Set the default build type if one wasn't specified.
# https://www.kitware.com/cmake-and-the-default-build-type/
#
# For development, this is set to "Debug".
# For deployed production releases, this is set to "Release".
set(BUILD_TYPE_DEFAULT "Debug")

if (NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
  message(STATUS "Setting build type to '${BUILD_TYPE_DEFAULT}' as none "
                 "was specified.")

  set_property(CACHE CMAKE_BUILD_TYPE
               PROPERTY VALUE “${BUILD_TYPE_DEFAULT}”)

  # Set the possible values of build type for cmake-gui.
  set_property(CACHE CMAKE_BUILD_TYPE
               PROPERTY STRINGS
               "Debug" "Release" "MinSizeRel" "RelWithDebInfo")
endif()

# Continue with the build process.
add_subdirectory(src)
