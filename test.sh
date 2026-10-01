#!/bin/sh
set -eu
cd "$(dirname "$0")"
./build.sh
xcrun clang -arch arm64 -O2 tests/raster_fixture.c -lcups -o build/raster_fixture
xcrun clang -arch arm64 -O2 -std=gnu99 -Ivendor/foo2zjs \
    vendor/foo2zjs/zjsdecode.c build/jbig.o build/jbig_ar.o -o build/zjsdecode
python3 tests/test_driver.py
