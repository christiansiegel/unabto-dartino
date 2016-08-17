cmake_minimum_required(VERSION 2.8.8)
project(unabtolib-posix)

set(PROJECT_ROOT ${CMAKE_CURRENT_SOURCE_DIR}/../..)
set(UNABTO_ROOT ${PROJECT_ROOT}/unabto)
include(${UNABTO_ROOT}/build/cmake/unabto_files.cmake)

set(src
  ${unabto_core_src}
  ${unabto_module_crypto_generic_src}
  ${PROJECT_ROOT}/src/lib/unabtolib.c
  ${PROJECT_ROOT}/src/lib/unabtoadapter.c
)

include_directories(
  ${unabto_core_include_directories}
  ${PROJECT_ROOT}/src/lib
)

add_definitions(
  ${unabto_definitions}
)

set(CMAKE_LIBRARY_OUTPUT_DIRECTORY
  ${PROJECT_ROOT}/dartino-sdk/bin/lib
)

add_library(${PROJECT_NAME} SHARED ${src})
