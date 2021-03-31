#!/bin/bash

set -e
diagnostic()
{
    echo "$@" 1>&2;
}

if [ -z "$ANDROID_ABI" ]; then
   diagnostic "*** No ANDROID_ABI defined architecture: using ARMv7"
   ANDROID_ABI="armeabi-v7a"
fi

DIR="$(cd "$(dirname "$0")" && pwd)"
project_root=$DIR/..
platform=$ANDROID_ABI

common_config_path=$project_root/common_config
source $common_config_path/setup_path.sh

tls_src=$third_party_dir/mbedtls
tls_build=$build_dir/mbedtls

mkdir -p $tls_build
pushd $tls_build

cmake -DCMAKE_TOOLCHAIN_FILE=$ANDROID_NDK/build/cmake/android.toolchain.cmake \
    -DANDROID_ABI=$ANDROID_ABI \
    -DANDROID_NDK=$ANDROID_NDK \
    -DCMAKE_ANDROID_ARCH_ABI=$ANDROID_ABI \
    -DCMAKE_ANDROID_NDK=$ANDROID_NDK \
    -DCMAKE_SYSTEM_NAME=Android \
    -DCMAKE_INSTALL_PREFIX=$install_dir \
    -DENABLE_TESTING=OFF \
    -DENABLE_PROGRAMS=OFF \
    $tls_src

cmake --build . --target install

popd # tls_build

srt_src=$third_party_dir/srt
srt_build=$build_dir/srt

mkdir -p $srt_build
pushd $srt_build


cmake -DCMAKE_TOOLCHAIN_FILE=$ANDROID_NDK/build/cmake/android.toolchain.cmake \
    -DANDROID_ABI=$ANDROID_ABI \
    -DANDROID_NDK=$ANDROID_NDK \
    -DCMAKE_ANDROID_ARCH_ABI=$ANDROID_ABI \
    -DCMAKE_ANDROID_NDK=$ANDROID_NDK \
    -DCMAKE_SYSTEM_NAME=Android \
    -DCMAKE_INSTALL_PREFIX=$install_dir \
    -DCMAKE_PREFIX_PATH=$install_dir \
    -DCMAKE_INSTALL_LIBDIR=lib \
    -DUSE_ENCLIB="mbedtls" \
    -DSSL_LIBRARY_DIRS=$install_dir/lib \
    -DSSL_INCLUDE_DIRS=$install_dir/include \
    -DCMAKE_SHARED_LINKER_FLAGS="-L$install_dir/lib" \
    -DENABLE_SHARED=ON \
    -DENABLE_STATIC=OFF \
    -DENABLE_APPS=OFF \
    -DCMAKE_INSTALL_INCLUDEDIR=include \
    -DCMAKE_INSTALL_LIBDIR=lib \
    -DCMAKE_INSTALL_BINDIR=bin \
    -DENABLE_CXX_DEPS=OFF \
    $srt_src

cmake --build . --target install

sed -i '' -e 's/^Requires.private.*//' $install_dir/lib/pkgconfig/srt.pc

popd
