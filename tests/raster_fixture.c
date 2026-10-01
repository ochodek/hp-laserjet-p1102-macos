/* SPDX-License-Identifier: GPL-2.0-or-later */
#include <cups/raster.h>
#include <math.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

int main(int argc, char **argv)
{
    int fractional = argc > 3 && strncmp(argv[3], "fractional", 10) == 0;
    cups_raster_t *r = cupsRasterOpen(STDOUT_FILENO,
        fractional ? CUPS_RASTER_WRITE_COMPRESSED : CUPS_RASTER_WRITE);
    int ramp = argc > 3 && strcmp(argv[3], "ramp") == 0;
    int verification = argc > 3 && strcmp(argv[3], "verification") == 0;
    for (int page = 0; page < (ramp || verification || fractional ? 1 : 2); page++) {
        cups_page_header2_t h = {0};
        h.HWResolution[0] = 600;
        h.HWResolution[1] = 600;
        h.PageSize[0] = 297; h.PageSize[1] = 420;
        h.ImagingBoundingBox[0] = h.ImagingBoundingBox[1] = 12;
        h.ImagingBoundingBox[2] = 285; h.ImagingBoundingBox[3] = 408;
        h.cupsWidth = 2275; h.cupsHeight = 3300 - page;
        if (fractional) {
            h.ImagingBoundingBox[0] = h.ImagingBoundingBox[1] = 16;
            h.ImagingBoundingBox[2] = 280; h.ImagingBoundingBox[3] = 403;
            h.cupsImagingBBox[0] = h.cupsImagingBBox[1] = 16.25;
            h.cupsImagingBBox[2] = 280.75; h.cupsImagingBBox[3] = 403.75;
            h.cupsWidth = 2204; h.cupsHeight = 3229;
            if (strcmp(argv[3], "fractional-nan") == 0) h.cupsImagingBBox[0] = NAN;
            if (strcmp(argv[3], "fractional-infinity") == 0) h.cupsImagingBBox[2] = INFINITY;
            if (strcmp(argv[3], "fractional-outside") == 0) h.cupsImagingBBox[2] = 298;
            if (strcmp(argv[3], "fractional-inverted") == 0) h.cupsImagingBBox[0] = 281;
        }
        h.cupsBitsPerColor = h.cupsBitsPerPixel = atoi(argv[1]);
        h.cupsColorSpace = atoi(argv[2]);
        h.cupsNumColors = 1;
        h.cupsBytesPerLine = (h.cupsWidth * h.cupsBitsPerPixel + 7) / 8;
        h.NumCopies = page + 1;
        if (ramp || verification) h.cupsCompression = 401; /* HP FastRes 600. */
        if (!cupsRasterWriteHeader2(r, &h)) return 1;
        unsigned char *row = malloc(h.cupsBytesPerLine);
        for (unsigned y = 0; y < h.cupsHeight; y++) {
            memset(row, h.cupsColorSpace == CUPS_CSPACE_W ? 255 : 0, h.cupsBytesPerLine);
            if (fractional && h.cupsBitsPerPixel == 8 && (y == 0 || y == h.cupsHeight - 1))
                row[0] = row[h.cupsWidth - 1] = h.cupsColorSpace == CUPS_CSPACE_W ? 0 : 255;
            if ((y >= 10 && y < 20) || y == h.cupsHeight - 1)
                for (unsigned x = 24 + page * 16; x < 40 + page * 16; x++) {
                    if (h.cupsBitsPerPixel == 8)
                        row[x] = h.cupsColorSpace == CUPS_CSPACE_W ? 0 : 255;
                    else
                        row[x / 8] ^= 0x80 >> (x % 8);
                }
            /* 256 constant tones for comparison with a reference driver. */
            if (ramp && h.cupsBitsPerPixel == 8 && y >= 100 && y < 2148)
                for (unsigned x = 100; x < 2148; x++) {
                    unsigned ink = ((y - 100) / 128) * 16 + (x - 100) / 128;
                    row[x] = h.cupsColorSpace == CUPS_CSPACE_W ? 255 - ink : ink;
                }
            /* Held-out varying tones and thin lines, not used to fit calibration. */
            if (verification && h.cupsBitsPerPixel == 8 && y >= 100 && y < 2100)
                for (unsigned x = 100; x < 1700; x++) {
                    unsigned ink = (x * x / 17 + y * y / 23 + ((x / 37) ^ (y / 29)) * 19) & 255;
                    if (x % 97 == 0 || y % 101 == 0) ink = 255;
                    row[x] = h.cupsColorSpace == CUPS_CSPACE_W ? 255 - ink : ink;
                }
            if (cupsRasterWritePixels(r, row, h.cupsBytesPerLine) != h.cupsBytesPerLine)
                return 1;
        }
        free(row);
    }
    cupsRasterClose(r);
    return 0;
}
