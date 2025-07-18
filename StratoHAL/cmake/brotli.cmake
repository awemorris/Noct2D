file(ARCHIVE_EXTRACT
  INPUT       ${CMAKE_CURRENT_SOURCE_DIR}/lib/archive/brotli-1.1.0.tar.gz
  DESTINATION ${CMAKE_BINARY_DIR}
)

file(GLOB LIBPNG_EXTRACTED_DIR ${CMAKE_BINARY_DIR}/brotli-*)
file(REMOVE_RECURSE ${CMAKE_BINARY_DIR}/brotli)
file(RENAME ${LIBPNG_EXTRACTED_DIR} ${CMAKE_BINARY_DIR}/brotli)

add_library(brotlicommon OBJECT
  ${CMAKE_BINARY_DIR}/brotli/c/common/constants.c
  ${CMAKE_BINARY_DIR}/brotli/c/common/dictionary.c
  ${CMAKE_BINARY_DIR}/brotli/c/common/shared_dictionary.c
  ${CMAKE_BINARY_DIR}/brotli/c/common/context.c
  ${CMAKE_BINARY_DIR}/brotli/c/common/platform.c
)

add_library(brotlidec OBJECT
  ${CMAKE_BINARY_DIR}/brotli/c/dec/bit_reader.c
  ${CMAKE_BINARY_DIR}/brotli/c/dec/decode.c
  ${CMAKE_BINARY_DIR}/brotli/c/dec/huffman.c
  ${CMAKE_BINARY_DIR}/brotli/c/dec/state.c
)

target_include_directories(brotlidec PRIVATE ${CMAKE_BINARY_DIR}/brotli/c/include)
target_include_directories(brotlidec PUBLIC  ${CMAKE_BINARY_DIR}/brotli/c/include)

target_include_directories(brotlicommon PRIVATE ${CMAKE_BINARY_DIR}/brotli/c/include)
target_include_directories(brotlicommon PUBLIC  ${CMAKE_BINARY_DIR}/brotli/c/include)
