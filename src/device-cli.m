/* SPDX-License-Identifier: GPL-2.0-or-later */
#import "device.h"
#include <stdio.h>
int main(int argc, const char **argv)
{
    @autoreleasepool {
        NSError *error = nil; NSDictionary *result = nil;
        NSString *action = argc > 1 ? @(argv[1]) : @"status";
        if ([action isEqual:@"status"] && argc <= 3) result = P1102Snapshot(argc == 3 ? @(argv[2]) : nil, &error);
        else if ([action isEqual:@"supplies"] && argc <= 3) result = P1102Supplies(argc == 3 ? @(argv[2]) : nil, &error);
        else if ([action isEqual:@"set"] && (argc == 4 || argc == 5)) {
            if (P1102Set(argc == 5 ? @(argv[4]) : nil, @(argv[2]), @(argv[3]), &error)) result = @{@"applied": @YES};
        } else if ([action isEqual:@"page"] && (argc == 3 || argc == 4)) {
            if (P1102InternalPage(argc == 4 ? @(argv[3]) : nil, @(argv[2]), &error)) result = @{@"accepted": @YES};
        } else { fprintf(stderr, "Usage: p1102ctl status|supplies [USB-serial]\n       p1102ctl set setting value [USB-serial]\n       p1102ctl page kind [USB-serial]\n"); return 1; }
        if (!result) { fprintf(stderr, "%s\n", error.localizedDescription.UTF8String); return 1; }
        NSData *json = [NSJSONSerialization dataWithJSONObject:result options:NSJSONWritingPrettyPrinted | NSJSONWritingSortedKeys error:&error];
        if (!json || fwrite(json.bytes, 1, json.length, stdout) != json.length) return 1;
        putchar('\n'); return 0;
    }
}
