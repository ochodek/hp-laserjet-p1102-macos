/* SPDX-License-Identifier: GPL-2.0-or-later
 * Original generic printer artwork; no third-party logos or glyphs. */
#import <Cocoa/Cocoa.h>

static void fillRoundedRect(CGContextRef context, CGRect rect, CGFloat radius, NSColor *color) {
    CGPathRef path = CGPathCreateWithRoundedRect(rect, radius, radius, NULL);
    CGContextSetFillColorWithColor(context, color.CGColor);
    CGContextAddPath(context, path);
    CGContextFillPath(context);
    CGPathRelease(path);
}

static BOOL writeIcon(NSString *path, NSInteger pixels) {
    NSBitmapImageRep *bitmap = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL
        pixelsWide:pixels pixelsHigh:pixels bitsPerSample:8 samplesPerPixel:4
        hasAlpha:YES isPlanar:NO colorSpaceName:NSCalibratedRGBColorSpace bytesPerRow:0 bitsPerPixel:0];
    if (!bitmap) return NO;
    [NSGraphicsContext saveGraphicsState];
    NSGraphicsContext.currentContext = [NSGraphicsContext graphicsContextWithBitmapImageRep:bitmap];
    CGContextRef context = NSGraphicsContext.currentContext.CGContext;
    CGFloat s = (CGFloat)pixels;
    CGContextClearRect(context, CGRectMake(0, 0, s, s));

    fillRoundedRect(context, CGRectMake(s * .055, s * .055, s * .89, s * .89), s * .19, [NSColor colorWithCalibratedRed:.12 green:.17 blue:.19 alpha:1]);
    fillRoundedRect(context, CGRectMake(s * .14, s * .27, s * .72, s * .39), s * .07, [NSColor colorWithCalibratedRed:.20 green:.28 blue:.30 alpha:1]);
    fillRoundedRect(context, CGRectMake(s * .22, s * .56, s * .56, s * .20), s * .035, [NSColor colorWithCalibratedRed:.93 green:.90 blue:.81 alpha:1]);
    fillRoundedRect(context, CGRectMake(s * .27, s * .18, s * .46, s * .20), s * .025, [NSColor colorWithCalibratedRed:.10 green:.14 blue:.15 alpha:1]);
    fillRoundedRect(context, CGRectMake(s * .31, s * .23, s * .38, s * .15), s * .012, [NSColor colorWithCalibratedRed:.17 green:.53 blue:.54 alpha:1]);
    CGFloat lineHeight = MAX(1, s * .018);
    fillRoundedRect(context, CGRectMake(s * .31, s * .66, s * .29, lineHeight), lineHeight / 2, [NSColor colorWithCalibratedRed:.30 green:.37 blue:.38 alpha:1]);
    fillRoundedRect(context, CGRectMake(s * .31, s * .61, s * .22, lineHeight), lineHeight / 2, [NSColor colorWithCalibratedRed:.30 green:.37 blue:.38 alpha:1]);
    fillRoundedRect(context, CGRectMake(s * .75, s * .46, MAX(1, s * .035), MAX(1, s * .035)), s * .02, [NSColor colorWithCalibratedRed:.17 green:.69 blue:.67 alpha:1]);

    [NSGraphicsContext restoreGraphicsState];
    NSData *png = [bitmap representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
    return [png writeToFile:path atomically:YES];
}

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        if (argc != 2) return 2;
        NSString *icnsPath = [NSString stringWithUTF8String:argv[1]];
        NSString *iconset = [icnsPath stringByAppendingString:@".iconset"];
        NSFileManager *manager = NSFileManager.defaultManager;
        [manager removeItemAtPath:iconset error:nil];
        if (![manager createDirectoryAtPath:iconset withIntermediateDirectories:YES attributes:nil error:nil]) return 1;
        NSArray<NSArray *> *sizes = @[@[@16, @"icon_16x16.png"], @[@32, @"icon_16x16@2x.png"], @[@32, @"icon_32x32.png"], @[@64, @"icon_32x32@2x.png"], @[@128, @"icon_128x128.png"], @[@256, @"icon_128x128@2x.png"], @[@256, @"icon_256x256.png"], @[@512, @"icon_256x256@2x.png"], @[@512, @"icon_512x512.png"], @[@1024, @"icon_512x512@2x.png"]];
        for (NSArray *entry in sizes) {
            if (!writeIcon([iconset stringByAppendingPathComponent:entry[1]], [entry[0] integerValue])) return 1;
        }
        NSTask *iconutil = [[NSTask alloc] init];
        iconutil.launchPath = @"/usr/bin/iconutil";
        iconutil.arguments = @[@"-c", @"icns", iconset, @"-o", icnsPath];
        [iconutil launch];
        [iconutil waitUntilExit];
        [manager removeItemAtPath:iconset error:nil];
        return iconutil.terminationStatus;
    }
}
