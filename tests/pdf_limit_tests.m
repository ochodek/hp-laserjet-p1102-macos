/* SPDX-License-Identifier: GPL-2.0-or-later */
#import "../src/pdf-tools.h"
#include <assert.h>
#include <stdio.h>
/* Compile the production renderer with a 4096-byte output limit. Even this
   tiny PDF exceeds it when Core Graphics finishes the document. */
int main(void)
{
    @autoreleasepool {
        [NSApplication sharedApplication];
        NSMutableData *data=[NSMutableData data];
        CGDataConsumerRef out=CGDataConsumerCreateWithCFData((__bridge CFMutableDataRef)data);
        CGRect box=CGRectMake(0,0,595,842);
        CGContextRef context=CGPDFContextCreate(out,&box,NULL); CGDataConsumerRelease(out);
        CGPDFContextBeginPage(context,NULL); CGContextFillRect(context,CGRectMake(10,10,100,100));
        CGPDFContextEndPage(context); CGPDFContextClose(context); CGContextRelease(context);
        PDFDocument *input=[[PDFDocument alloc] initWithData:data]; assert(input);
        NSError *error=nil;
        assert(!P1102PreparePDF(input,0,@"",NO,&error)&&error);
        puts("PDF output limit enforced through document finalization.");
    }
    return 0;
}
