#!/bin/sh

set -e

echo "ANDROID_NDK = $ANDROID_NDK"

ANDROID_ABI=armeabi-v7a ./build_script/x264_build.sh
ANDROID_ABI=armeabi-v7a ./build_script/ffmpeg_build.sh

ANDROID_ABI=arm64-v8a ./build_script/x264_build.sh
ANDROID_ABI=arm64-v8a ./build_script/ffmpeg_build.sh
