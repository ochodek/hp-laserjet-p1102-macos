/* SPDX-License-Identifier: GPL-2.0-or-later */
#import "pdf-tools.h"
#include <math.h>
#ifndef P1102_PDF_OUTPUT_LIMIT
#define P1102_PDF_OUTPUT_LIMIT (256u * 1024u * 1024u)
#endif
typedef struct { CFMutableDataRef data; BOOL exceeded; } PDFOutput;
static size_t appendPDFBytes(void *info, const void *bytes, size_t count)
{
    PDFOutput *out=info;
    size_t length=(size_t)CFDataGetLength(out->data);
    if (out->exceeded || count > P1102_PDF_OUTPUT_LIMIT - length) { out->exceeded=YES; return 0; }
    CFDataAppendBytes(out->data,bytes,(CFIndex)count); return count;
}
static void pdfError(NSError **error, NSString *text)
{ if (error) *error = [NSError errorWithDomain:@"P1102 PDF" code:1 userInfo:@{NSLocalizedDescriptionKey:text}]; }
static BOOL validRect(CGRect r)
{ return isfinite(r.origin.x) && isfinite(r.origin.y) && isfinite(r.size.width) && isfinite(r.size.height) && r.size.width > 0 && r.size.height > 0 && r.size.width <= 14400 && r.size.height <= 14400; }
static BOOL draw(PDFDocument *doc, NSInteger index, CGRect area, CGContextRef context, NSError **error)
{
    if (index < 0 || index >= (NSInteger)doc.pageCount) return YES;
    PDFPage *page = [doc pageAtIndex:(NSUInteger)index];
    CGRect box = [page boundsForBox:kPDFDisplayBoxCropBox];
    if (!validRect(box)) { pdfError(error, @"PDF page has invalid dimensions."); return NO; }
    CGContextSaveGState(context);
    CGContextClipToRect(context, area);
    CGRect rotated = CGRectApplyAffineTransform(box, [page transformForBox:kPDFDisplayBoxCropBox]);
    if (!validRect(rotated)) { CGContextRestoreGState(context); pdfError(error, @"Invalid rotated PDF bounds."); return NO; }
    CGFloat scale = MIN(area.size.width / rotated.size.width, area.size.height / rotated.size.height);
    CGContextTranslateCTM(context, area.origin.x + (area.size.width - rotated.size.width * scale) / 2 - rotated.origin.x * scale,
        area.origin.y + (area.size.height - rotated.size.height * scale) / 2 - rotated.origin.y * scale);
    CGContextScaleCTM(context, scale, scale);
    [page drawWithBox:kPDFDisplayBoxCropBox toContext:context];
    CGContextRestoreGState(context); return YES;
}
PDFDocument *P1102PreparePDF(PDFDocument *input, NSInteger booklet, NSString *watermark, BOOL firstOnly, NSError **error)
{
    if (!input || input.isLocked || !input.allowsPrinting || !input.pageCount || input.pageCount > 2000 || booklet < 0 || booklet > 2 || watermark.length > 120) {
        pdfError(error, @"Open a printable PDF with 1-2000 pages; watermark limit is 120 characters."); return nil;
    }
    NSMutableData *data = [NSMutableData data];
    PDFOutput output={(__bridge CFMutableDataRef)data,NO};
    CGDataConsumerCallbacks callbacks={appendPDFBytes,NULL};
    CGDataConsumerRef consumer = CGDataConsumerCreate(&output,&callbacks);
    if (!consumer) { pdfError(error, @"Cannot allocate PDF output."); return nil; }
    CGContextRef context = CGPDFContextCreate(consumer, NULL, NULL); CGDataConsumerRelease(consumer);
    if (!context) { pdfError(error, @"Cannot create PDF output."); return nil; }
    NSUInteger padded = (input.pageCount + 3) / 4 * 4, count = booklet ? padded / 2 : input.pageCount;
    BOOL ok = YES; NSError *pageError = nil;
    for (NSUInteger i = 0; i < count && ok; i++) {
        @autoreleasepool {
            CGRect paper = booklet ? CGRectMake(0, 0, 842, 595) : [[input pageAtIndex:i] boundsForBox:kPDFDisplayBoxCropBox];
            if (!validRect(paper)) { pdfError(&pageError, @"Invalid PDF page dimensions."); ok = NO; break; }
            /* Normalize the page origin and preserve landscape rotations. */
            if (!booklet && labs([input pageAtIndex:i].rotation) % 180 == 90) paper.size = CGSizeMake(paper.size.height, paper.size.width);
            paper.origin = CGPointZero;
            NSData *box = [NSData dataWithBytes:&paper length:sizeof(paper)];
            CGPDFContextBeginPage(context, (__bridge CFDictionaryRef)@{(__bridge NSString *)kCGPDFContextMediaBox:box});
            if (booklet) {
                NSInteger left = i % 2 ? (NSInteger)i : (NSInteger)padded - 1 - (NSInteger)i;
                NSInteger right = i % 2 ? (NSInteger)padded - 1 - (NSInteger)i : (NSInteger)i;
                if (booklet == 2) { NSInteger swap = left; left = right; right = swap; }
                ok = draw(input, left, CGRectMake(16.25, 16.25, 388.5, 562.5), context, &pageError) &&
                     draw(input, right, CGRectMake(437.25, 16.25, 388.5, 562.5), context, &pageError);
            } else ok = draw(input, (NSInteger)i, paper, context, &pageError);
            if (watermark.length && (!firstOnly || i == 0)) {
                CGContextSaveGState(context);
                CGContextTranslateCTM(context, paper.size.width / 2, paper.size.height / 2);
                CGContextRotateCTM(context, M_PI / 4);
                [NSGraphicsContext saveGraphicsState];
                NSGraphicsContext.currentContext = [NSGraphicsContext graphicsContextWithCGContext:context flipped:NO];
                CGFloat fontSize = MIN(48, paper.size.width / 10);
                NSDictionary *attributes = @{NSFontAttributeName:[NSFont boldSystemFontOfSize:fontSize], NSForegroundColorAttributeName:[NSColor colorWithWhite:0 alpha:0.18]};
                NSSize size = [watermark sizeWithAttributes:attributes];
                CGFloat scale = MIN(1, paper.size.width * 0.8 / MAX(1, size.width));
                CGContextScaleCTM(context, scale, scale);
                [watermark drawAtPoint:NSMakePoint(-size.width / 2, -size.height / 2) withAttributes:attributes];
                [NSGraphicsContext restoreGraphicsState]; CGContextRestoreGState(context);
            }
            CGPDFContextEndPage(context);
            if (output.exceeded) { pdfError(&pageError, @"Prepared PDF exceeds the output size limit."); ok = NO; }
        }
    }
    CGPDFContextClose(context); CGContextRelease(context);
    if (output.exceeded) { pdfError(&pageError, @"Prepared PDF exceeds the output size limit."); ok = NO; }
    if (!ok) { if (error) *error = pageError; return nil; }
    PDFDocument *result = [[PDFDocument alloc] initWithData:data];
    if (!result) pdfError(error, @"Cannot reopen prepared PDF.");
    return result;
}
PDFDocument *P1102PDFPass(PDFDocument *input, BOOL backs, BOOL shortEdge, NSError **error)
{
    if (!input || !input.pageCount || input.pageCount > 2000) { pdfError(error, @"Invalid duplex source."); return nil; }
    PDFDocument *result = [PDFDocument new];
    /* Match foo2zjs's manual-duplex ordering: odd fronts ascending, even backs
       descending. Long-edge backs rotate 180 degrees for unchanged stack feed. */
    NSUInteger sheets = (input.pageCount + 1) / 2;
    for (NSUInteger n = 0; n < sheets; n++) {
        NSUInteger i = backs ? (sheets - 1 - n) * 2 + 1 : n * 2;
        PDFPage *page;
        if (i < input.pageCount) page = [[input pageAtIndex:i] copy];
        else {
            page = [PDFPage new];
            [page setBounds:[[input pageAtIndex:input.pageCount - 1] boundsForBox:kPDFDisplayBoxCropBox] forBox:kPDFDisplayBoxMediaBox];
            page.rotation=[input pageAtIndex:input.pageCount - 1].rotation;
        }
        if (backs && !shortEdge) page.rotation = (page.rotation + 180) % 360;
        [result insertPage:page atIndex:result.pageCount];
    }
    return result;
}
