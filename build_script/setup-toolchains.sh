#!/bin/sh

diagnostic()
{
    echo "$@" 1>&2;
}

checkfail()
{
    if [ ! $? -eq 0 ];then
        diagnostic "$1"
        exit 1
    fi
}

if [ -z "$ANDROID_NDK" -o -z "$ANDROID_SDK" ]; then
   diagnostic "You must define ANDROID_NDK, ANDROID_SDK before starting."
   diagnostic "They must point to your NDK and SDK directories."
   exit 1
fi

if [ -z "$ANDROID_ABI" ]; then
   diagnostic "*** No ANDROID_ABI defined architecture: using ARMv7"
   ANDROID_ABI="armeabi-v7a"
fi

#########
# FLAGS #
#########

# Set up ABI variables
if [ "${ANDROID_ABI}" = "x86" ] ; then
    TARGET_TUPLE="i686-linux-android"
    PLATFORM_SHORT_ARCH="x86"
elif [ "${ANDROID_ABI}" = "x86_64" ] ; then
    TARGET_TUPLE="x86_64-linux-android"
    PLATFORM_SHORT_ARCH="x86_64"
    HAVE_64=1
elif [ "${ANDROID_ABI}" = "arm64-v8a" ] ; then
    TARGET_TUPLE="aarch64-linux-android"
    HAVE_ARM=1
    HAVE_64=1
    PLATFORM_SHORT_ARCH="arm64"
elif [ "${ANDROID_ABI}" = "armeabi-v7a" ] ; then
    TARGET_TUPLE="arm-linux-androideabi"
    HAVE_ARM=1
    PLATFORM_SHORT_ARCH="arm"
else
    echo "Unknown ABI: '${ANDROID_ABI}'. Die, die, die!"
    exit 2
fi

# try to detect NDK version
REL=$(grep -o '^Pkg.Revision.*[0-9]*.*' $ANDROID_NDK/source.properties |cut -d " " -f 3 | cut -d "." -f 1)

if [ "$REL" -ge 18 ]; then
    if [ "${HAVE_64}" = 1 ]; then
        ANDROID_API=21
    else
        ANDROID_API=17
    fi
else
    echo "NDK >= v18 needed, cf. https://developer.android.com/ndk/downloads/"
    exit 1
fi

NDK_FORCE_ARG=
NDK_TOOLCHAIN_DIR=${PWD}/toolchains/${PLATFORM_SHORT_ARCH}
NDK_TOOLCHAIN_PROPS=${NDK_TOOLCHAIN_DIR}/source.properties
NDK_TOOLCHAIN_PATH=${NDK_TOOLCHAIN_DIR}/bin

if [ "`cat \"${NDK_TOOLCHAIN_PROPS}\" 2>/dev/null`" != "`cat \"${ANDROID_NDK}/source.properties\"`" ];then
     echo "NDK changed, making new toolchain"
     NDK_FORCE_ARG="--force"
fi

$ANDROID_NDK/build/tools/make_standalone_toolchain.py \
    --arch ${PLATFORM_SHORT_ARCH} \
    --api ${ANDROID_API} \
    --stl libc++ \
    ${NDK_FORCE_ARG} \
    --install-dir ${NDK_TOOLCHAIN_DIR} 2> /dev/null
if [ ! -d ${NDK_TOOLCHAIN_PATH} ];
then
    echo "make_standalone_toolchain.py failed"
    exit 1
fi

if [ ! -z "${NDK_FORCE_ARG}" ];then
    cp "$ANDROID_NDK/source.properties" "${NDK_TOOLCHAIN_PROPS}"
fi

# Add the NDK toolchain to the PATH, needed both for contribs and for building
# stub libraries

export PATH="${NDK_TOOLCHAIN_PATH}:${PATH}"

##########
# CFLAGS #
##########

# Setup CFLAGS per ABI
if [ "${ANDROID_ABI}" = "armeabi-v7a" ] ; then
    EXTRA_CFLAGS="-march=armv7-a -mfpu=neon -mcpu=cortex-a8"
    EXTRA_CFLAGS="${EXTRA_CFLAGS} -mthumb -mfloat-abi=softfp"
elif [ "${ANDROID_ABI}" = "x86" ] ; then
    EXTRA_CFLAGS="-mtune=atom -msse3 -mfpmath=sse -m32"
fi

EXTRA_CFLAGS="${EXTRA_CFLAGS} -MMD -MP -fpic -ffunction-sections -funwind-tables \
-fstack-protector-strong -Wno-invalid-command-line-argument -Wno-unused-command-line-argument \
-no-canonical-prefixes -fno-integrated-as"
EXTRA_CXXFLAGS="${EXTRA_CXXFLAGS} -fexceptions -frtti"
EXTRA_CXXFLAGS="${EXTRA_CXXFLAGS} -D__STDC_FORMAT_MACROS=1 -D__STDC_CONSTANT_MACROS=1 -D__STDC_LIMIT_MACROS=1"

#################
# Setup LDFLAGS #
#################

if [ ${ANDROID_ABI} = "armeabi-v7a" ]; then
        EXTRA_PARAMS=" --enable-neon"
        EXTRA_LDFLAGS="${EXTRA_LDFLAGS} -Wl,--fix-cortex-a8"
fi
NDK_LIB_DIR="${NDK_TOOLCHAIN_DIR}/${TARGET_TUPLE}/lib"
if [ "${PLATFORM_SHORT_ARCH}" = "x86_64" ];then
    NDK_LIB_DIR="${NDK_LIB_DIR}64"
elif [ "${PLATFORM_SHORT_ARCH}" = "arm" ]; then
    NDK_LIB_DIR="${NDK_LIB_DIR}/armv7-a"
fi

EXTRA_LDFLAGS="${EXTRA_LDFLAGS} -L${NDK_LIB_DIR} -lc++abi"

# Make in //
if [ -z "$MAKEFLAGS" ]; then
    UNAMES=$(uname -s)
    MAKEFLAGS=
    if which nproc >/dev/null; then
        MAKEFLAGS=-j`nproc`
    elif [ "$UNAMES" == "Darwin" ] && which sysctl >/dev/null; then
        MAKEFLAGS=-j`sysctl -n machdep.cpu.thread_count`
    fi
fi

##################################################################
# save to config.sh

rm -f config.sh

echo "export CC='${NDK_TOOLCHAIN_PATH}/clang'" >> config.sh
echo "export CXX='${NDK_TOOLCHAIN_PATH}/clang++'" >> config.sh
echo "export CFLAGS='${EXTRA_CFLAGS}'" >> config.sh
echo "export CXXFLAGS='${EXTRA_CXXFLAGS}'" >> config.sh
echo "export LDFLAGS='${EXTRA_LDFLAGS}'" >> config.sh
echo "export AR='${NDK_TOOLCHAIN_PATH}/${TARGET_TUPLE}-ar'" >> config.sh
echo "export RANLIB='${NDK_TOOLCHAIN_PATH}/${TARGET_TUPLE}-ranlib'" >> config.sh
echo "export LD='${NDK_TOOLCHAIN_PATH}/${TARGET_TUPLE}-ld'" >> config.sh
echo "export CROSS_TOOLS='${NDK_TOOLCHAIN_PATH}/${TARGET_TUPLE}-'" >> config.sh
echo "export TARGET_TUPLE=${TARGET_TUPLE}" >> config.sh

echo "export MAKEFLAGS=${MAKEFLAGS}" >> config.sh

cat config.sh
