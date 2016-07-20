cmake_minimum_required(VERSION 2.8)
project(unabtolib)

set(UNABTO_ROOT ${CMAKE_CURRENT_SOURCE_DIR}/unabto)
include(${UNABTO_ROOT}/build/cmake/unabto_files.cmake)

set(src
  ${unabto_core_src}
  ${unabto_module_crypto_generic_src}
  ${unabto_module_log_unix_src}         # TODO
  ${unabto_module_timers_unix_src}      # TODO
  ${CMAKE_CURRENT_SOURCE_DIR}/src/lib/unabtolib.c
  ${CMAKE_CURRENT_SOURCE_DIR}/src/lib/unabtoadapter.c
)

include_directories(
  ${unabto_core_include_directories}
  ${CMAKE_CURRENT_SOURCE_DIR}/src/lib
)

add_definitions(
  ${unabto_definitions}
)

set(CMAKE_LIBRARY_OUTPUT_DIRECTORY
  ${CMAKE_CURRENT_SOURCE_DIR}/dartino-sdk/bin/lib
)

add_library(${PROJECT_NAME} SHARED ${src})

target_link_libraries(${PROJECT_NAME} ${unabto_link_libraries})

