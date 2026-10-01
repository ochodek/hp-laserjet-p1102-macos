/* SPDX-License-Identifier: GPL-2.0-or-later */
#import "../src/device.h"
#include "../src/usb.h"
#include <assert.h>
#include <stdio.h>
static NSData *mock;
static NSUInteger cursor, writes;
static unsigned failWrites;
static int writeError;
static NSString *level = @"60";
p1102_usb *p1102_usb_open(const char *serial, char *error, size_t capacity)
{ (void)serial; (void)error; (void)capacity; return (p1102_usb *)1; }
p1102_usb *p1102_usb_open_print(const char *serial, char *error, size_t capacity)
{ return p1102_usb_open(serial,error,capacity); }
int p1102_usb_write(p1102_usb *usb, const void *bytes, size_t length)
{
    (void)usb; writes++; cursor = 0;
    if (failWrites) { failWrites--; return writeError; }
    NSString *request = [[NSString alloc] initWithBytes:bytes length:length encoding:NSASCIIStringEncoding];
    NSString *xml = [request containsString:@"ConsumableConfigDyn"] ? [NSString stringWithFormat:@"<ConsumableConfigDyn><ConsumableInfo><ConsumablePercentageLevelRemaining>%@</ConsumablePercentageLevelRemaining><ProductNumber>CE285A</ProductNumber><ConsumableLifeState><ConsumableState>ok</ConsumableState></ConsumableLifeState></ConsumableInfo></ConsumableConfigDyn>",level] : @"<ProductUsageDyn><PrinterSubunit><TotalImpressions>1000</TotalImpressions></PrinterSubunit><ConsumableSubunit><Consumable><TotalImpressions>99</TotalImpressions><EstimatedPagesRemaining>300</EstimatedPagesRemaining><PreviousCartridgeData><TotalImpressions>999999</TotalImpressions></PreviousCartridgeData></Consumable></ConsumableSubunit></ProductUsageDyn>";
    NSData *body = [xml dataUsingEncoding:NSUTF8StringEncoding];
    NSMutableData *response = [[NSString stringWithFormat:@"HTTP/1.1 200 OK\r\nContent-Length: %lu\r\n\r\n",(unsigned long)body.length] dataUsingEncoding:NSASCIIStringEncoding].mutableCopy;
    [response appendData:body]; mock = response; return 0;
}
int p1102_usb_read(p1102_usb *usb, void *buffer, size_t capacity, size_t *length)
{ (void)usb; *length = MIN(MIN(capacity, 17), mock.length - cursor); memcpy(buffer,(const char *)mock.bytes+cursor,*length); cursor+=*length; return *length ? 0 : -1; }
void p1102_usb_close(p1102_usb *usb) { (void)usb; }
static NSData *D(NSString *text) { return [text dataUsingEncoding:NSUTF8StringEncoding]; }
int main(void)
{
 @autoreleasepool {
    NSString *response = @"HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n0003\r\nabc\r\n2\r\nde\r\n0\r\n\r\n";
    NSData *wire = D(response); NSError *error = nil; NSInteger status;
    for (NSUInteger n=0; n<wire.length; n++) {
        NSData *body=P1102HTTPBody([wire subdataWithRange:NSMakeRange(0,n)],&status,&error);
        assert(!body && !error); /* Fragmented USB must never become a partial success. */
    }
    assert([P1102HTTPBody(wire,&status,&error) isEqual:D(@"abcde")] && status==200);
    for (NSString *bad in @[@"HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\nContent-Length: 0\r\n\r\n", @"HTTP/1.1 200 OK\r\nContent-Length: -1\r\n\r\n", @"HTTP/1.1 200 OK\r\nContent-Length: 9999999999999999\r\n\r\n", @"HTTP/1.1 200 OK\r\nContent-Length: 0\r\nContent-Length: 0\r\n\r\n", @"HTTP/1.1 200 OK\r\nTransfer-Encoding: gzip\r\n\r\n", @"HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\nffffffffffffffff\r\n", @"HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n1\r\nx!!"]) {
        error=nil; assert(!P1102HTTPBody(D(bad),&status,&error) && error);
    }
    error=nil; NSDictionary *xml=P1102XMLValues(D(@"<r xmlns:x='urn:x'><x:a>1</x:a><x:a>2</x:a><other><x:a>3</x:a></other></r>"),&error);
    assert((!error && [xml[@"r/a"] isEqual:@[@"1",@"2"]] && [xml[@"r/other/a"] isEqual:@[@"3"]]));
    for (NSString *bad in @[@"<!DOCTYPE r [<!ENTITY x SYSTEM 'file:///etc/passwd'>]><r>&x;</r>",@"<!DOCTYPE r [<!ENTITY x 'abc'>]><r>&x;</r>",@"<r><a></r>"]){error=nil;assert(!P1102XMLValues(D(bad),&error)&&error);}
    NSMutableString *deep=[NSMutableString string]; for(int i=0;i<33;i++)[deep appendString:@"<r>"];for(int i=0;i<33;i++)[deep appendString:@"</r>"];
    error=nil; assert(!P1102XMLValues(D(deep),&error)&&error);
    error=nil; NSDictionary *s=P1102Supplies(nil,&error); assert(!error&&[s[@"tonerPercent"] isEqual:@60]&&[s[@"tonerState"] isEqual:@"ok"]);
    for(NSString *bad in @[@"-1",@"101",@"unknown",@"60.0",@"",@"999999999999999999999",@"60</ConsumablePercentageLevelRemaining><ConsumablePercentageLevelRemaining>10"]){level=bad;error=nil;s=P1102Supplies(nil,&error);assert(s&&!s[@"tonerPercent"]);}
    level=@"60";error=nil; s=P1102Snapshot(nil,&error); assert([s[@"totalPages"] isEqual:@1000]&&[s[@"cartridgePages"] isEqual:@99]&&[s[@"estimatedPagesRemaining"] isEqual:@300]);
    /* A transient read-query write can recover once, without masking a
       persistent failure or replaying a state-changing PJL command. */
    NSUInteger count=writes; failWrites=1; writeError=P1102_USB_TRANSIENT; error=nil;
    assert(P1102Supplies(nil,&error)&&!error&&writes==count+2);
    count=writes; failWrites=3; error=nil;
    assert(!P1102Supplies(nil,&error)&&error&&writes==count+2);
    count=writes; failWrites=1; writeError=-1; error=nil;
    assert(!P1102Supplies(nil,&error)&&error&&writes==count+1);
    count=writes; failWrites=1; writeError=P1102_USB_TRANSIENT; error=nil;
    assert(!P1102Set(nil,@"QuietMode",@"OFF",&error)&&error&&writes==count+1);
    NSUInteger before=writes;error=nil;assert(!P1102Set(nil,@"QuietMode",@"ON\r\n@PJL RESET",&error)&&error&&writes==before);
    error=nil;assert(!P1102InternalPage(nil,@"factoryReset",&error)&&error&&writes==before);
    assert([P1102SerialFromURI(@"usb://Hewlett-Packard/HP%20LaserJet%20Professional%20P1102?serial=TEST") isEqual:@"TEST"]);
    for(NSString *bad in @[@"http://localhost/?serial=TEST",@"usb://Hewlett-Packard/Other?serial=TEST",@"usb://Hewlett-Packard/HP%20LaserJet%20Professional%20P1102?serial=A&serial=B",@"usb://Hewlett-Packard/HP%20LaserJet%20Professional%20P1102?serial=%0A"]){assert(!P1102SerialFromURI(bad));}
    /* Bounded mutation corpus: malformed framing must never crash or overread. */
    for(NSUInteger i=0;i<wire.length;i++) for(unsigned byte=0;byte<256;byte+=17){NSMutableData *mut=wire.mutableCopy;((unsigned char *)mut.mutableBytes)[i]=byte;error=nil;P1102HTTPBody(mut,&status,&error);}
    puts("Device contracts passed: fragmented HTTP, bounds, XML entities, unknown supplies, scoped counters, command allowlists, USB identity.");
 } return 0;
}
