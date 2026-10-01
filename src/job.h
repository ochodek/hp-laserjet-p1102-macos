/* SPDX-License-Identifier: GPL-2.0-or-later */
/* Adapted 2026-10-01 from foo2zjs P1102 job framing, Rick Richardson and
 * contributors. Original source and notices: vendor/foo2zjs/foo2zjs.c. */
#ifndef P1102_JOB_H
#define P1102_JOB_H
#include <stdio.h>
#include <time.h>
/* P1102 has a fixed simplex START_DOC. Keep vendor encoders unchanged while
   exposing job-scoped PJL options; no user text is interpolated into PJL. */
static void p1102_start_job(FILE *out, int density, int economy, int recovery)
{
    time_t now = time(NULL); struct tm tm; char stamp[15] = "00000000000000";
    if (localtime_r(&now, &tm)) strftime(stamp, sizeof(stamp), "%Y%m%d%H%M%S", &tm);
    fprintf(out, "\033%%-12345X@PJL JOB\n@PJL SET JAMRECOVERY=%s\n"
        "@PJL SET DENSITY=%d\n@PJL SET ECONOMODE=%s\n@PJL SET RET=MEDIUM\n"
        "@PJL INFO STATUS\n@PJL USTATUS DEVICE = ON\n@PJL USTATUS JOB = ON\n"
        "@PJL USTATUS PAGE = ON\n@PJL USTATUS TIMED = 30\n"
        "@PJL SET JOBATTR=\"JobAttr4=%s\"", recovery ? "AUTO" : "OFF", density, economy ? "ON" : "OFF", stamp);
    fputc(0, out); fputs("\033%-12345XJZJZ", out);
    static const unsigned char start[] = {
        0,0,0,40, 0,0,0,0, 0,0,0,2, 0,24,0x5a,0x5a,
        0,0,0,12, 0,1,1,0, 0,0,0,0,
        0,0,0,12, 0,2,1,0, 0,0,0,1
    };
    fwrite(start, 1, sizeof(start), out);
}
#endif
