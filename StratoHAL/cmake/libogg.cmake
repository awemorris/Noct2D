file(ARCHIVE_EXTRACT
  INPUT       ${CMAKE_CURRENT_SOURCE_DIR}/lib/archive/libogg-1.3.3.tar.gz
  DESTINATION ${CMAKE_BINARY_DIR}
)

file(GLOB LIBPNG_EXTRACTED_DIR ${CMAKE_BINARY_DIR}/libogg-*)
file(REMOVE_RECURSE ${CMAKE_BINARY_DIR}/libogg)
file(RENAME ${LIBPNG_EXTRACTED_DIR} ${CMAKE_BINARY_DIR}/libogg)

file(WRITE  ${CMAKE_BINARY_DIR}/libogg/include/ogg/config_types.h "#ifndef __CONFIG_TYPES_H__\n")
file(APPEND ${CMAKE_BINARY_DIR}/libogg/include/ogg/config_types.h "#define __CONFIG_TYPES_H__\n")
file(APPEND ${CMAKE_BINARY_DIR}/libogg/include/ogg/config_types.h "#define INCLUDE_INTTYPES_H  1\n")
file(APPEND ${CMAKE_BINARY_DIR}/libogg/include/ogg/config_types.h "#define INCLUDE_STDINT_H    1\n")
file(APPEND ${CMAKE_BINARY_DIR}/libogg/include/ogg/config_types.h "#define INCLUDE_SYS_TYPES_H 1\n")
file(APPEND ${CMAKE_BINARY_DIR}/libogg/include/ogg/config_types.h "#include <stdint.h>\n")
file(APPEND ${CMAKE_BINARY_DIR}/libogg/include/ogg/config_types.h "typedef int16_t ogg_int16_t;\n")
file(APPEND ${CMAKE_BINARY_DIR}/libogg/include/ogg/config_types.h "typedef uint16_t ogg_uint16_t;\n")
file(APPEND ${CMAKE_BINARY_DIR}/libogg/include/ogg/config_types.h "typedef int32_t ogg_int32_t;\n")
file(APPEND ${CMAKE_BINARY_DIR}/libogg/include/ogg/config_types.h "typedef uint32_t ogg_uint32_t;\n")
file(APPEND ${CMAKE_BINARY_DIR}/libogg/include/ogg/config_types.h "typedef int64_t ogg_int64_t;\n")
file(APPEND ${CMAKE_BINARY_DIR}/libogg/include/ogg/config_types.h "#endif\n")

add_library(ogg OBJECT
  ${CMAKE_BINARY_DIR}/libogg/src/bitwise.c
  ${CMAKE_BINARY_DIR}/libogg/src/framing.c
)

target_include_directories(ogg PRIVATE ${CMAKE_BINARY_DIR}/libogg)
target_include_directories(ogg PUBLIC  ${CMAKE_BINARY_DIR}/libogg/include)
set(OGG_INCLUDE_DIRS ${CMAKE_BINARY_DIR}/libogg/include)
