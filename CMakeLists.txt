cmake_minimum_required(VERSION 2.8)
project(unabtolib)

set(UNABTO_ROOT ${CMAKE_CURRENT_SOURCE_DIR}/unabto)
include(${UNABTO_ROOT}/build/cmake/unabto_files.cmake)

set(src
  ${unabto_core_src}
  ${unabto_module_log_unix_src}         # TODO
  ${unabto_module_timers_unix_src}      # TODO
  ${CMAKE_CURRENT_SOURCE_DIR}/src/lib/unabtolib.c
  ${CMAKE_CURRENT_SOURCE_DIR}/src/lib/unabtoadapter.c
)

if(${CMAKE_SYSTEM} MATCHES Linux)
  list(APPEND unabto_include_directories ${unabto_3rdparty_libtomcrypt_include_directories})
  list(APPEND unabto_src ${unabto_module_crypto_libtomcrypt_src})
  list(APPEND unabto_src ${unabto_3rdparty_libtomcrypt_src})
  list(APPEND unabto_definitions -DLTC_NO_ASM)
else()
  list(APPEND src ${unabto_module_crypto_generic_src})
endif()

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

