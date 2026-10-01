#!/bin/sh
set -eu
cd "$(dirname "$0")"
./build.sh
xcrun clang -arch arm64 -O2 tests/raster_fixture.c -lcups -o build/raster_fixture
xcrun clang -arch arm64 -O2 -std=gnu99 -Ivendor/foo2zjs \
    vendor/foo2zjs/zjsdecode.c build/jbig.o build/jbig_ar.o -o build/zjsdecode
python3 tests/test_driver.py
xcrun clang -arch arm64 -fobjc-arc -Wall -Wextra -Werror \
    src/device.m tests/device_tests.m -framework Foundation -o build/device-tests
build/device-tests
xcrun clang -arch arm64 -fobjc-arc -Wall -Wextra -Werror \
    src/pdf-tools.m tests/pdf_tests.m -framework Cocoa -framework PDFKit -o build/pdf-tests
build/pdf-tests
