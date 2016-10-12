#!/usr/bin/env bash

RED="\e[31m"
GRN="\e[32m"
WHT="\e[37m"
CLR="\e[0m"
NWL="\n"


while getopts ":b:c:k:m:p:" opt; do
  case $opt in
    b)
      BITS="$OPTARG"  # 32, 64
    ;;

    c)
      CPU="$OPTARG"
    ;;

    k)
      KERNEL="$OPTARG"  # linux, netbsd, nokernel
    ;;

    m)
      MACHINE="$OPTARG"  # pc, raspi2
    ;;

    p)
      PLATFORM="$OPTARG"  # lxc, qemu, wsl
    ;;

    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit 1
    ;;

    :)
      echo "Option -$OPTARG requires an argument." >&2
      exit 1
    ;;
  esac
done

# Default machine and kernel
if [[ -z "$KERNEL" ]]; then
  KERNEL=linux
fi

if [[ -z "$MACHINE" ]]; then
  MACHINE=pc
fi

# Platform aliases
case $PLATFORM in
  ""|pc|qemu)
    PLATFORM=pc_qemu
  ;;
  iso)
    PLATFORM=pc_iso
  ;;

  docker)
    PLATFORM=docker_64
  ;;

  qemu_32)
    PLATFORM=pc_qemu_32
  ;;
  iso_32)
    PLATFORM=pc_iso_32
  ;;

  qemu_64)
    PLATFORM=pc_qemu_64
  ;;
  iso_64)
    PLATFORM=pc_iso_64
  ;;
esac

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

    raspi2)
      CPU=cortex-a7
    ;;
  esac
fi

# default CPU for each platform
if [[ -z "$CPU" ]]; then
  case $PLATFORM in
    *_32)
      CPU=i686
    ;;
    *_64)
      CPU=x86_64
    ;;

    *)
#      CPU=native  # https://gcc.gnu.org/onlinedocs/gcc-4.9.2/gcc/i386-and-x86-64-Options.html#i386-and-x86-64-Options
      CPU=`uname -m`
    ;;
  esac
fi

# [Hack] Can't be able to use x86_64 as generic x86 64 bits CPU
case $CPU in
  x86_64)
    CPU=nocona
  ;;
esac

# Normalice platforms
case $PLATFORM in
  docker_*)
    PLATFORM=docker
  ;;

  pc_qemu_*)
    PLATFORM=pc_qemu
  ;;
  pc_iso_*)
    PLATFORM=pc_iso
  ;;

  vagga_*)
    PLATFORM=vagga
  ;;
esac

# Set target and architecture for the selected CPU
case $CPU in
  # Raspi
  arm1136jf-s|arm1176jzf-s)
#  armv6j|armv6zk|arm1136jf-s|arm1176jzf-s)
    ARCH="arm"
    BITS=32
    CPU_FAMILY=arm
    CPU_PORT=armhf
    FLOAT_ABI=hard
    FPU=vfp
    NODE_ARCH=arm
    TARGET=armv6zk-nodeos-linux-musleabihf
#    TARGET=arm1176jzfs-nodeos-linux-musleabihf
  ;;

  # Raspi2
  cortex-a7)
    ARCH="arm"
    BITS=32
    CPU_FAMILY=arm
    CPU_PORT=armhf
    FLOAT_ABI=hard
    FPU=neon-vfpv4
    NODE_ARCH=arm64
    TARGET=armv7-nodeos-linux-musleabihf
#    TARGET=cortexa7-nodeos-linux-musleabihf
  ;;

  # Raspi3
  cortex-a53)
    ARCH="arm"
    BITS=64
    CPU_FAMILY=arm
    CPU_PORT=armhf
    FLOAT_ABI=hard
    FPU=crypto-neon-fp-armv8
    NODE_ARCH=arm64
    TARGET=armv7-nodeos-linux-musleabihf
#    TARGET=cortexa53-nodeos-linux-musleabihf
  ;;

  # pc 32
  i[34567]86)
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
#    TARGET=$CPU-nodeos-linux-musl
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
}

# Clean object dir and return the input error
function err(){
  printf "${RED}Error compiling '${OBJ_DIR}'${CLR}${NWL}" >&2
  rmStep $OBJ_DIR
  exit $1
}
