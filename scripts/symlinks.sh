#!/usr/bin/env bash

set -o pipefail


SYMLINKS=(addr2line ar as c++filt elfedit gprof ld ld.bfd nm objcopy objdump \
          ranlib readelf size strings strip c++ cpp g++ gcc gcov gcov-tool)


#
# (Re-)create the bypass symlinks to the native platform binaries
#

for i in "${SYMLINKS[@]}"
do
  cp resources/bypass.js bin/$i || exit 1
done


# If host platform is not based on musl, don't create un-prefixed symlinks
readlink /lib/ld-linux.so.2 | grep musl || exit 0


#
# Update the bypass symbolic links to point to the cross-toolchain binaries
#

CPU=

source scripts/adjustEnvVars.sh || exit $?

mkdir -p bin || exit 10

for i in "${SYMLINKS[@]}"
do
  ln -sf $TARGET-$i bin/$i || exit 11
done
