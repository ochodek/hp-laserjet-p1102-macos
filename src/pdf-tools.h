/* SPDX-License-Identifier: GPL-2.0-or-later */
#import <PDFKit/PDFKit.h>
/* Booklet: 0 off, 1 left binding, 2 right binding. All output is in memory. */
PDFDocument *P1102PreparePDF(PDFDocument *input, NSInteger booklet, NSString *watermark, BOOL firstOnly, NSError **error);
PDFDocument *P1102PDFPass(PDFDocument *input, BOOL backs, BOOL shortEdge, NSError **error);
