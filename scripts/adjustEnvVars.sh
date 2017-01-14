#!/usr/bin/env bash

RED="\e[31m"
GRN="\e[32m"
WHT="\e[37m"
CLR="\e[0m"
NWL="\n"

ORIGINAL_CFLAGS="$CFLAGS"
ORIGINAL_CXXFLAGS="$CXXFLAGS"

# Platform dependent commands
UNAME_S=$(uname -s)
case $UNAME_S in
  "Linux")
    RMDIR="rmdir -p --ignore-fail-on-non-empty"
    STRIP_DEBUG="strip --strip-debug"
    STRIP_UNNEEDED="strip --strip-unneeded"
  ;;
  "Darwin")
    RMDIR="rmdir -p"
    STRIP_DEBUG="strip -u -r -S"
    STRIP_UNNEEDED="strip -u -r -x"
  ;;
  *)
    echo "Unsupported platform: $UNAME_S" >&2
    exit 1
  ;;
esac

while getopts ":b:c:M:-:" opt; do
  case $opt in
    b)
      BITS="$OPTARG"  # 32, 64
    ;;

    c)
      CPU="$OPTARG"
    ;;

    M)
      MACHINE="$OPTARG"  # pc, raspi, raspi2, raspi3
    ;;

    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit 1
    ;;

    :)
      echo "Option -$OPTARG requires an argument." >&2
      exit 2
    ;;
  esac
done

# Get architecture from the `npm` environment variables to set the other ones
if [[ -z "$BITS" && -z "$CPU" && -z "$MACHINE" && -z "$NODE_ARCH" ]]; then
  NODE_ARCH=$npm_config_arch
fi

case $NODE_ARCH in
  "")
  ;;

  arm)
    CPU=cortex-a7
  ;;

  arm64)
    CPU=cortex-a53
  ;;

  ia32)
    BITS=32
    MACHINE=pc
  ;;

  x64)
    BITS=64
    MACHINE=pc
  ;;

  *)
    echo "Unknown architecture $NODE_ARCH"
    exit 1
  ;;
esac

# Default machine
if [[ -z "$MACHINE" ]]; then
  MACHINE=pc
fi

# default CPU for each machine
if [[ -z "$CPU" ]]; then
  case $MACHINE in
    pc)
      case $BITS in
        "")
          # CPU=native  # https://gcc.gnu.org/onlinedocs/gcc-4.9.2/gcc/i386-and-x86-64-Options.html#i386-and-x86-64-Options
          CPU=`uname -m`
        ;;

        32)
          CPU=i686
        ;;

        64)
          CPU=nocona
        ;;

        *)
          echo "Unknown BITS '$BITS' for MACHINE '$MACHINE'" >&2
          exit 1
        ;;
      esac
    ;;

    raspi)
      CPU=arm1176jzf-s
    ;;

    raspi2)
      CPU=cortex-a7
    ;;

    raspi3)
      CPU=cortex-a53
    ;;
  esac
fi

# [Hack] Can't be able to use x86_64 as generic x86 64 bits CPU
case $CPU in
  x86_64)
    CPU=nocona
  ;;
esac

# Set target and architecture for the selected CPU
case $CPU in
  # Raspi
  arm1176jzf-s)
    ARCH="arm"
    BITS=32
    CPU_FAMILY=arm
    CPU_PORT=armhf
    FLOAT_ABI=hard
    FPU=vfp
    NODE_ARCH=arm
    TARGET=armv6zk-nodeos-linux-musleabihf
  ;;

  # Raspi2
  cortex-a7)
    ARCH="arm"
    BITS=32
    CPU_FAMILY=arm
    CPU_PORT=armhf
    FLOAT_ABI=hard
    FPU=neon-vfpv4
    NODE_ARCH=arm
    TARGET=armv7ve-nodeos-linux-musleabihf
  ;;

  # Raspi3
  cortex-a53)
    ARCH="arm"  # armv8-a+crc
    BITS=64
    CPU_FAMILY=arm
    CPU_PORT=armhf
    FLOAT_ABI=hard
    FPU=crypto-neon-fp-armv8
    NODE_ARCH=arm64
    TARGET=armv8a-nodeos-linux-musleabihf
  ;;

  # pc 32
  i[345678]86)
    ARCH="x86"
    BITS=32
    CPU_FAMILY=i386
    CPU_PORT=$CPU_FAMILY
    NODE_ARCH=ia32
    TARGET=$CPU-nodeos-linux-musl
  ;;

  # pc 64
  athlon64|athlon-fx|atom|core2|k8|nocona|opteron|x86_64)
    ARCH="x86"
    BITS=64
    CPU_FAMILY=x86_64
    CPU_PORT=$CPU_FAMILY
    NODE_ARCH=x64
    TARGET=x86_64-nodeos-linux-musl
  ;;

  *)
    echo "Unknown CPU '$CPU'"
    exit 1
  ;;
esac


# Set host triplet and number of concurrent jobs
HOST=$(echo ${MACHTYPE} | sed "s/-[^-]*/-cross/")

if [[ -z $JOBS ]]; then
  JOBS=$((`getconf _NPROCESSORS_ONLN` + 1))
fi


# Auxiliar variables
OBJECTS=`pwd`/build/$CPU

MAKE1="make ${SILENT:=--silent LIBTOOLFLAGS=--silent V=}"
MAKE="$MAKE1 --jobs=$JOBS"

KERNEL_NAME=$(uname -s | tr '[:upper:]' '[:lower:]')

function rmStep(){
  rm -rf "$@"
  $RMDIR `dirname "$@"`
}

# Clean object dir and return the input error
function err(){
  printf "${RED}Error building '${STEP_DIR}'${CLR}${NWL}" >&2
  rmStep $STEP_DIR
  exit $1
}
