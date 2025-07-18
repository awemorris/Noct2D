cmake_minimum_required(VERSION 3.16)
project(StratoHAL LANGUAGES C CXX)

set(CMAKE_OSX_ARCHITECTURES "x86_64;arm64" CACHE STRING "" FORCE)

#
# Configuration
#

option(USE_SHARED "Enable shared libraries" OFF)
option(USE_GLX    "Enable OpenGL on X11"    ON)

#
# Dependency
#

if(USE_SHARED)
  list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake/modules")
  find_package(PNG REQUIRED)
  find_package(JPEG REQUIRED)
  find_package(WebP REQUIRED)
  find_package(Ogg REQUIRED)
  find_package(Vorbis MODULE REQUIRED)
  find_package(Freetype REQUIRED)
  find_package(Brotli REQUIRED)
  find_package(BZip2 REQUIRED)
  find_package(ZLIB REQUIRED)
else()
  include(cmake/zlib.cmake)
  include(cmake/libpng.cmake)
  include(cmake/jpeg.cmake)
  include(cmake/libwebp.cmake)
  include(cmake/libogg.cmake)
  include(cmake/libvorbis.cmake)
  include(cmake/brotli.cmake)
  include(cmake/bzip2.cmake)
  include(cmake/freetype.cmake)
endif()

#
# Source Files
#

# For Windows.
if(WIN32)
  set(SOURCES
    src/image.c
    src/glyph.c
    src/wave.c
    src/stdfile.c
    src/winmain.c
    src/d3drender.c
    src/d3d12render.cc
    src/d3d11render.cc
    src/d3d9render.cc
    src/gdirender.c
    src/dsound.c
    src/dsvideo.cc
  )
endif()

# For macOS.
if(APPLE AND NOT IOS)
  set(SOURCES
    src/image.c
    src/glyph.c
    src/wave.c
    src/stdfile.c
    src/nsmain.m
    src/aunit.c
    src/GameRenderer.m
    src/GameShaders.c
  )
endif()

# For POSIX (X11).
if(UNIX AND NOT APPLE)
  set(SOURCES
    src/image.c
    src/glyph.c
    src/wave.c
    src/stdfile.c
    src/x11main.c
    src/x11opengl.c
    src/x11softrender.c
    src/icon.c
    src/glrender.c
    src/asound.c
    src/bsdsound.c
    src/nosound.c
    src/gstplay.c
  )
endif()

# For Haiku.
if(CMAKE_SYSTEM_NAME STREQUAL "Haiku")
  set(SOURCES
    src/platform/image.c
    src/platform/glyph.c
    src/platform/wave.c
    src/platform/stdfile.c
    src/platform/bemain.cc
  )
endif()

if(USE_SHARED)
  add_library(strato SHARED ${SOURCES})
else()
  add_library(strato STATIC
    ${SOURCES}
    $<TARGET_OBJECTS:png>
    $<TARGET_OBJECTS:jpeg>
    $<TARGET_OBJECTS:webp>
    $<TARGET_OBJECTS:vorbisfile>
    $<TARGET_OBJECTS:vorbis>
    $<TARGET_OBJECTS:ogg>
    $<TARGET_OBJECTS:freetype>
    $<TARGET_OBJECTS:brotlidec>
    $<TARGET_OBJECTS:brotlicommon>
    $<TARGET_OBJECTS:bz2>
    $<TARGET_OBJECTS:z>
  )
endif()

# Windows specific.
if(WIN32)
  enable_language(RC)
  set(CMAKE_CXX_STANDARD 11)
  set(CMAKE_CXX_STANDARD_REQUIRED ON)
  file(ARCHIVE_EXTRACT
    INPUT       ${CMAKE_CURRENT_SOURCE_DIR}/lib/archive/dx12headers.tar.gz
    DESTINATION ${CMAKE_BINARY_DIR}
  )
endif()

# macOS specific
if(APPLE)
  enable_language(OBJC)
endif()

#
# CPPFLAGS
#

#-Dinclude
target_include_directories(strato PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/include)
target_include_directories(strato PUBLIC  ${CMAKE_CURRENT_SOURCE_DIR}/include)

# -DUSE_SHARED if we use dynamic linking.
if(USE_SHARED)
  target_compile_definitions(strato PRIVATE USE_SHARED)
endif()

# -DUSE_JIT if we use JIT.
if(USE_JIT)
  target_compile_definitions(strato PRIVATE USE_JIT)
endif()

# -DUSE_GLX if we use OpenGL on X11.
if(UNIX AND NOT Haiku)
  if(USE_GLX)
    target_compile_definitions(strato PRIVATE USE_X11_OPENGL)
  else()
    target_compile_definitions(strato PRIVATE USE_X11_SOFTRENDER)
  endif()
endif()

# Add library header directories.
target_include_directories(strato PRIVATE ${PNG_INCLUDE_DIRS})
target_include_directories(strato PRIVATE ${JPEG_INCLUDE_DIRS})
target_include_directories(strato PRIVATE ${WEBP_INCLUDE_DIRS})
target_include_directories(strato PRIVATE ${OGG_INCLUDE_DIRS})
target_include_directories(strato PRIVATE ${VORBIS_INCLUDE_DIRS})
target_include_directories(strato PRIVATE ${FREETYPE_INCLUDE_DIRS})
target_include_directories(strato PRIVATE ${BROTLI_INCLUDE_DIRS})
target_include_directories(strato PRIVATE ${BZIP2_INCLUDE_DIRS})
target_include_directories(strato PRIVATE ${ZLIB_INCLUDE_DIRS})

# Windows: Add -Ires -Idx12headers/include/directx -Idx12headers/include/fxguids
if(CMAKE_SYSTEM_NAME STREQUAL "Windows")
  target_include_directories(strato PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/res
    ${CMAKE_BINARY_DIR}/dx12headers/include/directx
    ${CMAKE_BINARY_DIR}/dx12headers/include/dxguids
  )
endif()

# FreeBSD: Add -I/usr/local/include
if(CMAKE_SYSTEM_NAME STREQUAL "FreeBSD")
  target_include_directories(strato PRIVATE /usr/local/include)
endif()

# NetBSD: Add -I/usr/local/include -I/usr/X11R7/include
if(CMAKE_SYSTEM_NAME STREQUAL "NetBSD")
  target_include_directories(strato PRIVATE /usr/local/include /usr/X11R7/include)
endif()

# OpenBSD: Add -I/usr/local/include -I/usr/X11R6/include
if(CMAKE_SYSTEM_NAME STREQUAL "OpenBSD")
  target_include_directories(strato PRIVATE /usr/local/include /usr/X11R6/include)
endif()

#
# CFLAGS
#

# Use "Release" build type by default.
if(NOT CMAKE_BUILD_TYPE)
  set(CMAKE_BUILD_TYPE "Release" CACHE STRING "Build type (Debug or Release)" FORCE)
endif()

# Debug Configuration.
set(CMAKE_C_FLAGS_DEBUG   "${CMAKE_C_FLAGS_RELEASE}   -O0 -g3")
set(CMAKE_CXX_FLAGS_DEBUG "${CMAKE_CXX_FLAGS_RELEASE} -O0 -g3")

# Release Configuration.
set(CMAKE_C_FLAGS_RELEASE   "${CMAKE_C_FLAGS_RELEASE}   -O3 -g0")
set(CMAKE_CXX_FLAGS_RELEASE "${CMAKE_CXX_FLAGS_RELEASE} -O3 -g0")

#
# Link
#

# Libraries.
if(USE_SHARED)
  target_link_libraries(strato PRIVATE
    ${PNG_LIBRARIES}
    ${JPEG_LIBRARIES}
    ${WEBP_LIBRARIES}
    ${VORBIS_LIBRARY}
    ${VORBISFILE_LIBRARY}
    ${OGG_LIBRARY}
    ${FREETYPE_LIBRARY}
    ${BROTLIDEC_LIBRARIES}
    ${BROTLICOMMON_LIBRARIES}
    ${BZIP2_LIBRARIES}
    ${ZLIB_LIBRARIES}
  )
endif()

# macOS link options.
if(APPLE AND NOT IOS)
  target_compile_options(strato PRIVATE
    -fmodules
  )
  target_link_libraries(strato PRIVATE
    "-framework AppKit"
    "-framework MetalKit"
    "-framework AVFoundation"
  )
endif()

# POSIX GLX: Add -lGL -lGLX
if(UNIX AND NOT APPLE)
  if(USE_GLX)
    target_link_libraries(strato PRIVATE
      GL
      GLX
    )
  endif()
endif()

# POSIX: Add -lm -lpthread -lXpm -lX11
if(UNIX AND NOT APPLE)
  target_link_libraries(strato PRIVATE
    m
    pthread
    Xpm
    X11
  )
endif()

# Linux: Add -lasound
if(CMAKE_SYSTEM_NAME STREQUAL "Linux")
  target_link_libraries(strato PRIVATE
    asound
  )
endif()

# FreeBSD: Add -L/usr/local/lib -L/usr/X11R7/lib
if(CMAKE_SYSTEM_NAME STREQUAL "FreeBSD")
  link_directories(
    /usr/local/lib
    /usr/X11R7/lib
  )
endif()

# NetBSD: Add -L/usr/local/lib -L/usr/X11R7/lib
if(CMAKE_SYSTEM_NAME STREQUAL "NetBSD")
  link_directories(
    /usr/local/lib
    /usr/X11R7/lib
  )
endif()

# OpenBSD: Add -L/usr/local/lib -L/usr/X11R6/lib
if(CMAKE_SYSTEM_NAME STREQUAL "OpenBSD")
  link_directories(
    /usr/local/lib
    /usr/X11R6/lib
  )
endif()

# Haiku: Add -lbe -lmedia
if(CMAKE_SYSTEM_NAME STREQUAL "Haiku")
  target_link_libraries(strato PRIVATE
    be
    media
  )
endif()
