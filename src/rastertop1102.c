/* SPDX-License-Identifier: GPL-2.0-or-later */
#include <cups/raster.h>
#include <fcntl.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include "halftone.h"

/* The unchanged foo2zjs encoder is linked with its CLI entry point renamed. */
extern int Model, ResX, ResY, Bpp, OutputStartPlane, LogicalClip, IsCUPS;
extern int PaperCode, Copies, PageNum;
extern long JbgOptions[5];
extern void start_doc(FILE *), end_doc(FILE *);
extern int pbm_page(unsigned char *, int, int, FILE *);

static void fail(const char *message)
{
    fprintf(stderr, "ERROR: P1102: %s\n", message);
    exit(1);
}

static int paper_code(const unsigned *size)
{
    static const unsigned papers[][3] = {
        {595, 842, 9}, {420, 595, 11}, {297, 420, 70},
        {612, 792, 1}, {612, 1008, 5}
    };
    for (unsigned i = 0; i < sizeof(papers) / sizeof(papers[0]); i++)
        if (size[0] >= papers[i][0] - 1 && size[0] <= papers[i][0] + 1 &&
            size[1] >= papers[i][1] - 1 && size[1] <= papers[i][1] + 1)
            return papers[i][2];
    fail("Unsupported paper size. Use A4, A5, A6, Letter or Legal.");
    return 0;
}

int main(int argc, char **argv)
{
    if (argc != 6 && argc != 7)
        fail("Expected job-id user title copies options [raster-file].");
    int fd = argc == 7 ? open(argv[6], O_RDONLY) : STDIN_FILENO;
    if (fd < 0) fail("Cannot open raster input.");
    cups_raster_t *raster = cupsRasterOpen(fd, CUPS_RASTER_READ);
    if (!raster) fail("Cannot read CUPS raster input.");

    Model = 2;                 /* HP Pro P1102 dialect */
    ResX = 600;
    ResY = 400;                /* HP FastRes 600 wire mode; raster stays 600 dpi. */
    Bpp = 2;                   /* Four exposure levels per 600 dpi pixel. */
    OutputStartPlane = 0;
    LogicalClip = 0;
    IsCUPS = 1;
    JbgOptions[3] = 0;          /* This printer requires JBIG MX = 0. */
    cups_page_header2_t h;

    while (cupsRasterReadHeader2(raster, &h)) {
        if (h.HWResolution[0] != 600 || h.HWResolution[1] != 600 ||
            h.cupsColorOrder != CUPS_ORDER_CHUNKED ||
            (h.cupsColorSpace != CUPS_CSPACE_K && h.cupsColorSpace != CUPS_CSPACE_W) ||
            (h.cupsBitsPerPixel != 1 && h.cupsBitsPerPixel != 8) ||
            h.cupsBitsPerColor != h.cupsBitsPerPixel || h.Duplex)
            fail("Expected simplex, 600x600 dpi, 1-bit or 8-bit grayscale raster.");
        PaperCode = paper_code(h.PageSize);
        if (h.ImagingBoundingBox[0] > h.ImagingBoundingBox[2] ||
            h.ImagingBoundingBox[1] > h.ImagingBoundingBox[3] ||
            h.ImagingBoundingBox[2] > h.PageSize[0] ||
            h.ImagingBoundingBox[3] > h.PageSize[1])
            fail("Invalid printable area.");
        /* Quartz retains fractional PPD margins only in the Raster v2 fields. */
        double box[4];
        int fractional_box = 0;
        for (unsigned i = 0; i < 4; i++)
            if (h.cupsImagingBBox[i] != 0) fractional_box = 1;
        for (unsigned i = 0; i < 4; i++) {
            box[i] = fractional_box ? h.cupsImagingBBox[i] : h.ImagingBoundingBox[i];
            if (!isfinite(box[i]) || box[i] < 0 || box[i] > h.PageSize[i % 2])
                fail("Invalid printable area.");
        }
        if (box[0] >= box[2] || box[1] >= box[3])
            fail("Invalid printable area.");
        unsigned max_width = (unsigned)ceil(
            (box[2] - box[0]) * 600.0 / 72);
        unsigned max_height = (unsigned)ceil(
            (box[3] - box[1]) * 600.0 / 72);
        unsigned width = h.cupsWidth, height = h.cupsHeight;
        if (!width || !height || width > max_width || height > max_height ||
            h.cupsBytesPerLine < (h.cupsWidth * h.cupsBitsPerPixel + 7) / 8 ||
            h.cupsBytesPerLine > width * 8 || h.NumCopies > 999)
            fail("Invalid raster dimensions, margins or copy count.");
        /* Calibrated to the mean of three identical A4 prints. The padded A4
           canvas stays unchanged; other sizes reserve enough rows for all ink.
           Screen phase stays anchored to the input image, not the padding. */
        const unsigned horizontal_padding = 83, vertical_padding = 31;
        const unsigned left_padding = 15, top_padding = 31;
        width += horizontal_padding;
        /* HP pads the final raster band to 12 rows; extra rows remain white. */
        height = (height + vertical_padding + 11) / 12 * 12;
        size_t stride = ((width * 2 + 127) / 128) * 16;
        unsigned char *bitmap = calloc(height, stride);
        unsigned char *row = malloc(h.cupsBytesPerLine);
        if (!bitmap || !row) fail("Cannot allocate page buffer.");
        for (unsigned y = 0; y < h.cupsHeight; y++) {
            if (cupsRasterReadPixels(raster, row, h.cupsBytesPerLine) != h.cupsBytesPerLine)
                fail("Truncated raster page; job was not completed.");
            for (unsigned x = 0; x < h.cupsWidth; x++) {
                unsigned ink = h.cupsBitsPerPixel == 1 ?
                    ((row[x / 8] >> (7 - x % 8)) & 1) * 255 : row[x];
                if (h.cupsColorSpace == CUPS_CSPACE_W) ink = 255 - ink;
                const unsigned char *threshold = exposure_threshold[y % 12][x % 12];
                unsigned level = (ink >= threshold[0]) +
                    (ink >= threshold[1]) + (ink >= threshold[2]);
                unsigned output_x = x + left_padding;
                bitmap[(y + top_padding) * stride + output_x / 4] |=
                    level << (6 - (output_x % 4) * 2);
            }
        }
        free(row);
        Copies = h.NumCopies ? (int)h.NumCopies : 1;
        if (PageNum == 0) start_doc(stdout);
        ++PageNum;
        pbm_page(bitmap, (int)width * 2, (int)height, stdout);
        free(bitmap);
        if (ferror(stdout)) fail("Cannot write printer data.");
    }
    if (!PageNum) fail("Empty or invalid raster job.");
    const char *raster_error = cupsRasterErrorString();
    if (raster_error && *raster_error) fail(raster_error);
    end_doc(stdout);
    if (fflush(stdout) || ferror(stdout)) fail("Cannot finish printer data.");
    cupsRasterClose(raster);
    if (fd != STDIN_FILENO) close(fd);
    return 0;
}
