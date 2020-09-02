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

x264_src=$third_party_dir/x264
x264_build=$build_dir/x264

pushd $DIR

ANDROID_ABI=$ANDROID_ABI ./setup-toolchains.sh

source config.sh

mkdir -p $x264_build

pushd $x264_build

$x264_src/configure \
    --prefix=$install_dir \
    --enable-static \
    --enable-pic \
    --cross-prefix=$CROSS_TOOLS \
    --host=$TARGET_TUPLE \

make && make install

popd

popd
