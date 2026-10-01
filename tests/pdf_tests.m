/* SPDX-License-Identifier: GPL-2.0-or-later */
#import "../src/pdf-tools.h"
#include <assert.h>
#include <stdio.h>
static PDFDocument *fixture(NSUInteger pages)
{
    NSMutableData *data = [NSMutableData data]; CGDataConsumerRef out = CGDataConsumerCreateWithCFData((__bridge CFMutableDataRef)data);
    CGRect box = CGRectMake(0,0,595,842); CGContextRef c = CGPDFContextCreate(out,&box,NULL);CGDataConsumerRelease(out);
    for(NSUInteger i=0;i<pages;i++) {
        CGPDFContextBeginPage(c,NULL); [NSGraphicsContext saveGraphicsState]; NSGraphicsContext.currentContext=[NSGraphicsContext graphicsContextWithCGContext:c flipped:NO];
        [[NSString stringWithFormat:@"PAGE%lu",(unsigned long)i+1] drawAtPoint:NSMakePoint(50,750) withAttributes:@{NSFontAttributeName:[NSFont systemFontOfSize:36]}];
        CGContextSetGrayFillColor(c,(i+1)*0.1,1);CGContextFillRect(c,CGRectMake(50,50,150,150));
        [NSGraphicsContext restoreGraphicsState];CGPDFContextEndPage(c);
    }
    CGPDFContextClose(c);CGContextRelease(c);return [[PDFDocument alloc] initWithData:data];
}
static void cropped_pages_keep_the_visible_size_and_orientation(void)
{
    PDFDocument *input=fixture(1); PDFPage *page=[input pageAtIndex:0];
    [page setBounds:CGRectMake(25,25,300,500) forBox:kPDFDisplayBoxCropBox];
    for (NSNumber *rotation in @[@0,@90,@180,@270]) {
        page.rotation=rotation.integerValue; NSError *error=nil;
        PDFDocument *prepared=P1102PreparePDF(input,0,@"",NO,&error);
        assert(prepared&&!error);
        CGRect bounds=[[prepared pageAtIndex:0] boundsForBox:kPDFDisplayBoxMediaBox];
        BOOL landscape=rotation.integerValue%180!=0;
        assert(bounds.size.width==(landscape?500:300)&&bounds.size.height==(landscape?300:500));
        NSImage *original=[page thumbnailOfSize:NSMakeSize(300,300) forBox:kPDFDisplayBoxCropBox];
        NSImage *output=[[prepared pageAtIndex:0] thumbnailOfSize:NSMakeSize(300,300) forBox:kPDFDisplayBoxMediaBox];
        NSBitmapImageRep *a=[NSBitmapImageRep imageRepWithData:original.TIFFRepresentation];
        NSBitmapImageRep *b=[NSBitmapImageRep imageRepWithData:output.TIFFRepresentation];
        assert(a.pixelsWide==b.pixelsWide&&a.pixelsHigh==b.pixelsHigh);
        double difference=0;
        for (NSInteger y=0;y<a.pixelsHigh;y++) for (NSInteger x=0;x<a.pixelsWide;x++) {
            CGFloat av=[[[a colorAtX:x y:y] colorUsingColorSpace:NSColorSpace.genericGrayColorSpace] whiteComponent];
            CGFloat bv=[[[b colorAtX:x y:y] colorUsingColorSpace:NSColorSpace.genericGrayColorSpace] whiteComponent];
            difference+=fabs(av-bv);
        }
        assert(difference/(a.pixelsWide*a.pixelsHigh)<0.01);
    }
}
int main(void)
{
 @autoreleasepool {
    [NSApplication sharedApplication]; PDFDocument *input=fixture(5);NSError *error=nil;
    cropped_pages_keep_the_visible_size_and_orientation();
    PDFDocument *book=P1102PreparePDF(input,1,@"",NO,&error); assert(book&&book.pageCount==4&&!error);
    assert([[book pageAtIndex:0].string containsString:@"PAGE1"]&&![[book pageAtIndex:0].string containsString:@"PAGE5"]);
    assert([[book pageAtIndex:1].string containsString:@"PAGE2"]);
    assert([[book pageAtIndex:2].string containsString:@"PAGE3"]);
    assert([[book pageAtIndex:3].string containsString:@"PAGE4"]&&[[book pageAtIndex:3].string containsString:@"PAGE5"]);
    PDFDocument *front=P1102PDFPass(input,NO,NO,&error),*back=P1102PDFPass(input,YES,NO,&error);
    assert(front.pageCount==3&&back.pageCount==3);
    for(NSUInteger n=0;n<3;n++)assert(([[front pageAtIndex:n].string containsString:[NSString stringWithFormat:@"PAGE%lu",(unsigned long)(n*2+1)]]));
    assert(![back pageAtIndex:0].string.length&&[[back pageAtIndex:1].string containsString:@"PAGE4"]&&[[back pageAtIndex:2].string containsString:@"PAGE2"]);
    assert([back pageAtIndex:1].rotation==180&&[input pageAtIndex:3].rotation==0);
    PDFDocument *shortBack=P1102PDFPass(input,YES,YES,&error);assert([shortBack pageAtIndex:1].rotation==0);
    PDFAnnotation *annotation=[[PDFAnnotation alloc] initWithBounds:NSMakeRect(100,300,250,60) forType:PDFAnnotationSubtypeFreeText withProperties:nil];annotation.contents=@"ANNOTATION";annotation.font=[NSFont systemFontOfSize:20];[[input pageAtIndex:0] addAnnotation:annotation];
    PDFDocument *marked=P1102PreparePDF(input,0,@"WATERMARK",YES,&error);assert(marked&&[[marked pageAtIndex:0].string containsString:@"WATERMARK"]&&![[marked pageAtIndex:1].string containsString:@"WATERMARK"]);
    assert([[marked pageAtIndex:0].string containsString:@"ANNOTATION"]); /* Printed form/annotation appearance survives. */
    [input pageAtIndex:0].rotation=90;PDFDocument *rotated=P1102PreparePDF(input,0,@"",NO,&error);assert(rotated);
    CGRect r=[[rotated pageAtIndex:0] boundsForBox:kPDFDisplayBoxMediaBox];assert(r.size.width==842&&r.size.height==595);
    assert([[rotated pageAtIndex:0].string containsString:@"PAGE1"]);
    error=nil;assert(!P1102PreparePDF(input,3,@"",NO,&error)&&error);
    error=nil;assert(!P1102PreparePDF(input,0,[@"x" stringByPaddingToLength:121 withString:@"x" startingAtIndex:0],NO,&error)&&error);
    [fixture(4) writeToFile:@"build/duplex-orientation-test.pdf"];
    [book writeToFile:@"build/booklet-test.pdf"];[marked writeToFile:@"build/watermark-test.pdf"];
    puts("PDF contracts passed: booklet padding/order, duplex pairing and rotation, annotations, watermark scope, limits.");
 } return 0;
}
