#!/bin/bash

set -e

#ANDROID_ABI="armeabi-v7a"
#ANDROID_ABI="x86"
#ANDROID_ABI="arm64-v8a"

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

ffmpeg_src=$third_party_dir/ffmpeg
ffmpeg_build=$build_dir/ffmpeg

pushd $DIR

ANDROID_ABI=$ANDROID_ABI ./setup-toolchains.sh

source config.sh

mkdir -p $ffmpeg_build

pushd $ffmpeg_build

source $common_config_path/ffmpeg_config

export PKG_CONFIG_PATH=$install_dir/lib/pkgconfig

#cf. https://github.com/android-ndk/ndk/issues/630
ffmpeg_extra_config="--disable-linux-perf \
    --cc=$CC \
    --cxx=$CXX \
    --prefix=$install_dir \
    --target-os=linux \
    --arch=$ANDROID_ABI \
    --cross-prefix=$CROSS_TOOLS \
    --disable-programs \
    --enable-static --disable-shared \
    --enable-pic \
    --enable-libx264 \
    --enable-gpl \
    --extra-cflags=-I$install_dir/include \
    --extra-ldflags=-L$install_dir/lib/ \
"

if [ $ANDROID_ABI == "arm64-v8a" ]; then
    ffmpeg_extra_config="$ffmpeg_extra_config --arch=aarch64"
fi

$ffmpeg_src/configure \
    $ffmpeg_config \
    $ffmpeg_extra_config \

make && make install-libs install-headers

popd # ffmpeg_build

popd # DIR
