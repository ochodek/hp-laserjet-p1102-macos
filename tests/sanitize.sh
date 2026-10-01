#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
mkdir -p build/sanitized
for source in foo2zjs jbig jbig_ar; do
    xcrun clang -arch arm64 -O1 -g -std=gnu99 -fsanitize=address,undefined \
        -fno-omit-frame-pointer -Dmain=foo2zjs_cli_main -Ivendor/foo2zjs \
        -c "vendor/foo2zjs/$source.c" -o "build/sanitized/$source.o"
done
xcrun clang -arch arm64 -O1 -g -std=c11 -fsanitize=address,undefined \
    -fno-omit-frame-pointer -Wl,-dead_strip src/rastertop1102.c \
    build/sanitized/foo2zjs.o build/sanitized/jbig.o build/sanitized/jbig_ar.o \
    -lcups -o build/sanitized/rastertop1102
P1102_TEST_FILTER="$PWD/build/sanitized/rastertop1102" \
    UBSAN_OPTIONS=halt_on_error=1 ASAN_OPTIONS=detect_leaks=0 python3 tests/test_driver.py
