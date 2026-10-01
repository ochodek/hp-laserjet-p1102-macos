/* SPDX-License-Identifier: GPL-2.0-or-later */
#import "device.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
int main(int argc, const char **argv)
{
    @autoreleasepool {
        if (argc != 6 && argc != 7) return 1;
        const char *uri = getenv("DEVICE_URI");
        NSString *serial = uri ? P1102SerialFromURI(@(uri)) : nil;
        if (!serial) { fprintf(stderr, "ERROR: P1102: Missing or invalid USB device URI.\n"); return 1; }
        FILE *input = argc == 7 ? fopen(argv[6], "r") : stdin;
        if (!input) return 1;
        char line[256]; unsigned count = 0; BOOL report = NO, invalid = NO;
        while (fgets(line, sizeof(line), input)) {
            if (++count > 32 || (!strchr(line, '\n') && !feof(input))) { invalid = YES; break; }
            line[strcspn(line, "\r\n")] = 0;
            if (!*line || *line == '#') continue;
            if (!strcmp(line, "ReportLevels")) report = YES;
            else invalid = YES;
        }
        if (ferror(input)) invalid = YES;
        if (argc == 7) fclose(input);
        if (invalid || !report) { fprintf(stderr, "ERROR: P1102: Unsupported command.\n"); return 1; }
        NSError *error = nil; NSDictionary *supply = P1102Supplies(serial, &error);
        if (!supply) {
            fprintf(stderr, "ATTR: marker-levels=-2\nWARNING: P1102: Cannot refresh supplies; level is unknown.\n"); return 1;
        }
        NSNumber *level = supply[@"tonerPercent"];
        fprintf(stderr, "ATTR: marker-colors=#000000 marker-names=Black marker-types=toner marker-levels=%ld\n", level ? level.longValue : -2L);
        fprintf(stderr, "INFO: P1102: Supply information refreshed from USB.\n");
        return 0;
    }
}
