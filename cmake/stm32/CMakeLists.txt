cmake_minimum_required(VERSION 2.8.8)
project(unabtolib-stm32)

set(PROJECT_ROOT ${CMAKE_CURRENT_SOURCE_DIR}/../..)

set(CMAKE_C_COMPILER
  ${PROJECT_ROOT}/dartino-sdk/tools/gcc-arm-embedded/bin/arm-none-eabi-gcc
)

set(CMAKE_C_FLAGS
  "${CMAKE_C_FLAGS} -mcpu=cortex-m7 -mthumb -mfloat-abi=hard -mfpu=fpv5-sp-d16"
)

set(UNABTO_ROOT ${PROJECT_ROOT}/unabto)
include(${UNABTO_ROOT}/build/cmake/unabto_files.cmake)

set(src
  ${unabto_core_src}
  ${unabto_module_crypto_generic_src}
  ${PROJECT_ROOT}/src/lib/unabtolib.c
  ${PROJECT_ROOT}/src/lib/unabtoadapter.c
  ${PROJECT_ROOT}/src/lib/unabto_dns_fallback_stubs.c
)

include_directories(
  ${unabto_core_include_directories}
  ${PROJECT_ROOT}/src/lib
  ${PROJECT_ROOT}/dartino-sdk
)

add_definitions(
  ${unabto_definitions}
)

set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY
  ${PROJECT_ROOT}/src/ffi
)

add_library(${PROJECT_NAME} STATIC ${src})

# Still needs to be copied into src/ffi by hand!
add_library(unabtolib_dartino_ffi OBJECT
  ${PROJECT_ROOT}/src/lib/unabtolib_dartino_ffi.c
)
