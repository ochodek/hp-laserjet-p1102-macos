#!/bin/sh
set -eu
cd "$(dirname "$0")"
mkdir -p build
shasum -a 256 -c vendor/SHA256SUMS
for source in foo2zjs jbig jbig_ar; do
    xcrun clang -arch arm64 -mmacosx-version-min=11.0 -O2 -std=gnu99 \
        -Dmain=foo2zjs_cli_main -Ivendor/foo2zjs \
        -c "vendor/foo2zjs/$source.c" -o "build/$source.o"
done
xcrun clang -arch arm64 -mmacosx-version-min=11.0 -O2 -std=c11 \
    -Wall -Wextra -Werror src/rastertop1102.c \
    build/foo2zjs.o build/jbig.o build/jbig_ar.o -lcups -Wl,-dead_strip -o build/rastertop1102
codesign --force --sign - build/rastertop1102
cupstestppd -q -I filters ppd/HP-P1102-Native.ppd
file build/rastertop1102
otool -L build/rastertop1102
