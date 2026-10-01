/* SPDX-License-Identifier: GPL-2.0-or-later */
#import "device.h"
#include "usb.h"
#include <time.h>

static const NSUInteger limit = 512 * 1024;
static void failure(NSError **error, NSString *message)
{
    if (error) *error = [NSError errorWithDomain:@"P1102" code:1 userInfo:@{NSLocalizedDescriptionKey: message}];
}
static BOOL number(NSString *text, NSUInteger maximum, NSUInteger *result, unsigned base)
{
    if (!text.length || text.length > 16) return NO;
    NSUInteger value = 0;
    for (NSUInteger i = 0; i < text.length; i++) {
        unichar c = [text characterAtIndex:i];
        unsigned digit = c >= '0' && c <= '9' ? c - '0' : c >= 'a' && c <= 'f' ? c - 'a' + 10 : c >= 'A' && c <= 'F' ? c - 'A' + 10 : 99;
        if (digit >= base || digit > maximum || value > (maximum - digit) / base) return NO;
        value = value * base + digit;
    }
    *result = value; return YES;
}
static NSRange separator(NSData *data, const char *text, NSUInteger offset)
{
    return [data rangeOfData:[NSData dataWithBytes:text length:strlen(text)] options:0 range:NSMakeRange(offset, data.length - offset)];
}
NSData *P1102HTTPBody(NSData *data, NSInteger *status, NSError **error)
{
    if (data.length > limit) { failure(error, @"USB response exceeds the size limit."); return nil; }
    NSRange split = separator(data, "\r\n\r\n", 0);
    if (split.location == NSNotFound) {
        if (data.length > 8192) failure(error, @"HTTP header exceeds the size limit.");
        return nil;
    }
    if (split.location > 8192) { failure(error, @"HTTP header exceeds the size limit."); return nil; }
    NSString *header = [[NSString alloc] initWithData:[data subdataWithRange:NSMakeRange(0, split.location)] encoding:NSASCIIStringEncoding];
    NSArray *lines = [header componentsSeparatedByString:@"\r\n"];
    NSArray *first = [lines.firstObject componentsSeparatedByString:@" "];
    NSUInteger code = 0;
    if (first.count < 2 || (![first[0] isEqual:@"HTTP/1.1"] && ![first[0] isEqual:@"HTTP/1.0"]) ||
        !number(first[1], 599, &code, 10) || code < 200) { failure(error, @"Invalid HTTP status."); return nil; }
    *status = (NSInteger)code;
    NSString *transfer = nil, *lengthText = nil;
    for (NSUInteger i = 1; i < lines.count; i++) {
        NSString *line = lines[i]; NSRange colon = [line rangeOfString:@":"];
        if (!colon.length) { failure(error, @"Invalid HTTP header."); return nil; }
        NSString *key = [[line substringToIndex:colon.location] lowercaseString];
        NSString *value = [[line substringFromIndex:colon.location + 1] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
        if ([key isEqual:@"transfer-encoding"]) {
            if (transfer) { failure(error, @"Duplicate HTTP framing header."); return nil; } transfer = value.lowercaseString;
        }
        if ([key isEqual:@"content-length"]) {
            if (lengthText) { failure(error, @"Duplicate HTTP framing header."); return nil; } lengthText = value;
        }
    }
    NSUInteger offset = NSMaxRange(split);
    if (transfer && lengthText) { failure(error, @"Ambiguous HTTP framing."); return nil; }
    if (code == 204 && !transfer && !lengthText) return [NSData data];
    if (transfer) {
        if (![transfer isEqual:@"chunked"]) { failure(error, @"Unsupported HTTP transfer encoding."); return nil; }
        NSMutableData *body = [NSMutableData data];
        while (offset <= data.length) {
            NSRange end = separator(data, "\r\n", offset);
            if (end.location == NSNotFound) {
                if (data.length - offset > 16) failure(error, @"Invalid chunk length."); return nil;
            }
            NSString *sizeText = [[NSString alloc] initWithData:[data subdataWithRange:NSMakeRange(offset, end.location - offset)] encoding:NSASCIIStringEncoding];
            NSUInteger size;
            if (!number(sizeText, limit, &size, 16) || size > limit - body.length) { failure(error, @"Invalid chunk length."); return nil; }
            offset = NSMaxRange(end);
            if (data.length - offset < size + 2) return nil;
            const unsigned char *bytes = data.bytes;
            if (bytes[offset + size] != '\r' || bytes[offset + size + 1] != '\n') { failure(error, @"Invalid chunk terminator."); return nil; }
            if (!size) return body;
            [body appendData:[data subdataWithRange:NSMakeRange(offset, size)]];
            offset += size + 2;
        }
        return nil;
    }
    NSUInteger length;
    if (!number(lengthText, limit, &length, 10)) { failure(error, @"Missing or invalid HTTP content length."); return nil; }
    if (data.length - offset < length) return nil;
    return [data subdataWithRange:NSMakeRange(offset, length)];
}

@interface P1102XML : NSObject <NSXMLParserDelegate>
@property NSMutableArray<NSString *> *path;
@property NSMutableArray<NSMutableString *> *text;
@property NSMutableDictionary<NSString *, NSMutableArray<NSString *> *> *values;
@property NSString *root;
@property NSUInteger nodes;
@end
@implementation P1102XML
- (instancetype)init { if ((self = [super init])) { _path = [NSMutableArray array]; _text = [NSMutableArray array]; _values = [NSMutableDictionary dictionary]; } return self; }
- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)name namespaceURI:(NSString *)uri qualifiedName:(NSString *)q attributes:(NSDictionary *)attributes
{
    (void)uri; (void)q; (void)attributes;
    if (_path.count >= 32 || ++_nodes > 4096 || name.length > 128) { [parser abortParsing]; return; }
    if (!_path.count) _root = name;
    [_path addObject:name]; [_text addObject:[NSMutableString string]];
}
- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string
{
    if (_text.lastObject.length + string.length > 4096) [parser abortParsing];
    else [_text.lastObject appendString:string];
}
- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)name namespaceURI:(NSString *)uri qualifiedName:(NSString *)q
{
    (void)parser; (void)name; (void)uri; (void)q;
    if (!_path.count) return;
    NSString *text = [_text.lastObject stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (text.length) {
        NSString *key = [_path componentsJoinedByString:@"/"];
        if (!_values[key]) _values[key] = [NSMutableArray array];
        [_values[key] addObject:text];
    }
    [_path removeLastObject]; [_text removeLastObject];
}
@end
static P1102XML *parseXML(NSData *data, NSError **error)
{
    /* LEDM is UTF-8 and needs no DTD. Reject declarations even though external
       entity resolution is disabled, also preventing internal entity expansion. */
    NSString *source = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if (!source || data.length > limit || [data rangeOfData:[NSData dataWithBytes:"\0" length:1] options:0 range:NSMakeRange(0, data.length)].length || [source rangeOfString:@"<!DOCTYPE" options:NSCaseInsensitiveSearch].length ||
        [source rangeOfString:@"<!ENTITY" options:NSCaseInsensitiveSearch].length) { failure(error, @"Unsupported XML declaration or encoding."); return nil; }
    NSUInteger offset = [source hasPrefix:@"\ufeff"] ? 1 : 0;
    if (source.length > offset + 5 && [[source substringWithRange:NSMakeRange(offset, 5)] isEqual:@"<?xml"] &&
        [[NSCharacterSet whitespaceAndNewlineCharacterSet] characterIsMember:[source characterAtIndex:offset + 5]]) {
        NSRange end = [source rangeOfString:@"?>" options:0 range:NSMakeRange(offset + 5, source.length - offset - 5)];
        NSString *declaration = end.location == NSNotFound ? nil : [source substringWithRange:NSMakeRange(offset, NSMaxRange(end) - offset)];
        NSRegularExpression *encoding = [NSRegularExpression regularExpressionWithPattern:@"(?i)(?:^|\\s)encoding\\s*=\\s*(['\"])([^'\"]*)\\1" options:0 error:nil];
        NSTextCheckingResult *match = [encoding firstMatchInString:declaration ?: @"" options:0 range:NSMakeRange(0, declaration.length)];
        if (!declaration || (match && [[declaration substringWithRange:[match rangeAtIndex:2]] caseInsensitiveCompare:@"UTF-8"] != NSOrderedSame)) { failure(error, @"Unsupported XML declaration or encoding."); return nil; }
    }
    NSXMLParser *parser = [[NSXMLParser alloc] initWithData:data];
    P1102XML *delegate = [P1102XML new];
    parser.delegate = delegate; parser.shouldProcessNamespaces = YES; parser.shouldResolveExternalEntities = NO;
    if (![parser parse]) { failure(error, @"Malformed or excessive printer XML."); return nil; }
    return delegate;
}
NSDictionary *P1102XMLValues(NSData *data, NSError **error)
{
    P1102XML *xml = parseXML(data, error);
    return xml ? xml.values : nil;
}
static double monotonic(void) { struct timespec t; clock_gettime(CLOCK_MONOTONIC, &t); return t.tv_sec + t.tv_nsec / 1e9; }
static NSData *request(NSString *serial, NSString *resource, NSError **error)
{
    char message[256];
    p1102_usb *usb = p1102_usb_open(serial.UTF8String, message, sizeof(message));
    if (!usb) { failure(error, @(message)); return nil; }
    NSString *header = [NSString stringWithFormat:@"GET /DevMgmt/%@.xml HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\nContent-Length: 0\r\n\r\n", resource];
    NSMutableData *wire = [[header dataUsingEncoding:NSUTF8StringEncoding] mutableCopy];
    NSData *result = nil;
    int sent = p1102_usb_write(usb, wire.bytes, wire.length);
    /* A backend starting up can invalidate a USB transfer. Only this GET is
       safe to repeat; PJL settings and page requests must never be replayed. */
    if (sent == P1102_USB_TRANSIENT) {
        p1102_usb_close(usb);
        struct timespec delay = {0, 100000000}; nanosleep(&delay, NULL);
        usb = p1102_usb_open(serial.UTF8String, message, sizeof(message));
        if (!usb) { failure(error, @(message)); return nil; }
        sent = p1102_usb_write(usb, wire.bytes, wire.length);
    }
    if (sent) failure(error, @"Cannot send the USB request.");
    else {
        NSMutableData *response = [NSMutableData data]; double deadline = monotonic() + 5;
        while (monotonic() < deadline && response.length < limit) {
            unsigned char bytes[16384]; size_t size;
            if (p1102_usb_read(usb, bytes, sizeof(bytes), &size) || !size) { failure(error, @"Printer did not return a complete response."); break; }
            [response appendBytes:bytes length:size];
            NSInteger status = 0; NSError *parseError = nil;
            result = P1102HTTPBody(response, &status, &parseError);
            if (parseError) { if (error) *error = parseError; break; }
            if (result) {
                if (status < 200 || status >= 300) { failure(error, [NSString stringWithFormat:@"Printer returned HTTP %ld.", (long)status]); result = nil; }
                break;
            }
        }
        if (!result && error && !*error) failure(error, @"Printer response timed out or exceeded the size limit.");
    }
    p1102_usb_close(usb); return result;
}
static NSDictionary *readXML(NSString *serial, NSString *resource, NSError **error)
{
    NSData *data = request(serial, resource, error);
    P1102XML *xml = data ? parseXML(data, error) : nil;
    if (!xml) return nil;
    if (![xml.root isEqual:resource]) { failure(error, @"Printer returned the wrong XML resource."); return nil; }
    return xml.values;
}
static NSString *one(NSDictionary *xml, NSString *path) { NSArray *values = xml[path]; return values.count == 1 ? values[0] : nil; }
static void copyText(NSMutableDictionary *out, NSString *key, NSDictionary *xml, NSString *path)
{
    NSString *value = one(xml, path); if (value) out[key] = value;
}
static void copyNumber(NSMutableDictionary *out, NSString *key, NSDictionary *xml, NSString *path, NSUInteger maximum)
{
    NSUInteger value; if (number(one(xml, path), maximum, &value, 10)) out[key] = @(value);
}
NSDictionary *P1102Supplies(NSString *serial, NSError **error)
{
    NSDictionary *xml = readXML(serial, @"ConsumableConfigDyn", error); if (!xml) return nil;
    NSMutableDictionary *out = [NSMutableDictionary dictionary];
    NSString *base = @"ConsumableConfigDyn/ConsumableInfo/";
    copyNumber(out, @"tonerPercent", xml, [base stringByAppendingString:@"ConsumablePercentageLevelRemaining"], 100);
    copyText(out, @"tonerState", xml, [base stringByAppendingString:@"ConsumableLifeState/ConsumableState"]);
    copyText(out, @"cartridge", xml, [base stringByAppendingString:@"ProductNumber"]);
    copyText(out, @"lastUsed", xml, [base stringByAppendingString:@"ConsumableLastUsedDate"]);
    copyText(out, @"brand", xml, [base stringByAppendingString:@"ConsumableLifeState/Brand"]);
    out[@"readAt"] = @([NSDate date].timeIntervalSince1970);
    return out;
}
NSDictionary *P1102Snapshot(NSString *serial, NSError **error)
{
    NSMutableDictionary *out = [P1102Supplies(serial, error) mutableCopy]; if (!out) return nil;
    NSMutableArray *warnings = [NSMutableArray array];
    NSArray *resources = @[@"ProductStatusDyn", @"ProductUsageDyn", @"ProductConfigDyn", @"ProductLogsDyn", @"MediaHandlingDyn", @"ProductConfigCap", @"InternalPrintCap"];
    for (NSString *resource in resources) {
        NSError *local = nil; NSDictionary *xml = readXML(serial, resource, &local);
        if (!xml) { [warnings addObject:[NSString stringWithFormat:@"%@: %@", resource, local.localizedDescription]]; continue; }
        if ([resource isEqual:@"ProductStatusDyn"]) {
            out[@"states"] = xml[@"ProductStatusDyn/Status/StatusCategory"] ?: @[];
            out[@"alerts"] = xml[@"ProductStatusDyn/Alert/ProductStatusAlertID"] ?: @[];
        } else if ([resource isEqual:@"ProductUsageDyn"]) {
            copyNumber(out, @"totalPages", xml, @"ProductUsageDyn/PrinterSubunit/TotalImpressions", UINT32_MAX);
            copyNumber(out, @"jams", xml, @"ProductUsageDyn/PrinterSubunit/JamEvents", UINT32_MAX);
            copyNumber(out, @"mispicks", xml, @"ProductUsageDyn/PrinterSubunit/MispickEvents", UINT32_MAX);
            copyNumber(out, @"cartridgePages", xml, @"ProductUsageDyn/ConsumableSubunit/Consumable/TotalImpressions", UINT32_MAX);
            copyNumber(out, @"estimatedPagesRemaining", xml, @"ProductUsageDyn/ConsumableSubunit/Consumable/EstimatedPagesRemaining", UINT32_MAX);
        } else if ([resource isEqual:@"ProductConfigDyn"]) {
            NSDictionary *paths = @{@"model": @"ProductInformation/MakeAndModel", @"serial": @"ProductInformation/SerialNumber", @"firmwareDate": @"ProductInformation/Version/Date", @"product": @"ProductInformation/ProductNumber", @"sleep": @"ProductSettings/PowerSaveTimeout", @"autoOff": @"ProductSettings/AutoOffTime", @"language": @"ProductSettings/ProductLanguage/DeviceLanguage"};
            for (NSString *key in paths) copyText(out, key, xml, [@"ProductConfigDyn/" stringByAppendingString:paths[key]]);
        } else if ([resource isEqual:@"ProductLogsDyn"]) {
            out[@"eventCodes"] = xml[@"ProductLogsDyn/EventLog/Event/EventCode"] ?: @[];
        } else if ([resource isEqual:@"MediaHandlingDyn"]) {
            copyText(out, @"trayMedia", xml, @"MediaHandlingDyn/InputTray/MediaType");
            copyText(out, @"traySize", xml, @"MediaHandlingDyn/InputTray/MediaSizeName");
        } else if ([resource isEqual:@"ProductConfigCap"]) {
            out[@"capabilities"] = xml;
        } else if ([resource isEqual:@"InternalPrintCap"]) {
            out[@"internalPages"] = xml[@"InternalPrintCap/JobTypesSupport/JobType"] ?: @[];
        }
    }
    if (warnings.count) out[@"warnings"] = warnings;
    return out;
}
static NSString *pjl(NSString *serial, NSString *command, NSString *expected, NSError **error)
{
    char message[256];
    p1102_usb *usb = p1102_usb_open_print(serial.UTF8String, message, sizeof(message));
    if (!usb) { failure(error, @(message)); return nil; }
    NSData *wire = [[NSString stringWithFormat:@"\033%%-12345X%@\033%%-12345X", command] dataUsingEncoding:NSASCIIStringEncoding];
    NSMutableData *response = [NSMutableData data]; NSString *value = nil;
    if (p1102_usb_write(usb, wire.bytes, wire.length)) failure(error, @"Cannot send PJL request.");
    else if (!expected) value = @"sent";
    else {
        double deadline = monotonic() + 4;
        while (monotonic() < deadline && response.length < 16384) {
            unsigned char bytes[4096]; size_t size;
            if (p1102_usb_read(usb, bytes, sizeof(bytes), &size) || !size) break;
            [response appendBytes:bytes length:size];
            NSString *text = [[NSString alloc] initWithData:response encoding:NSASCIIStringEncoding];
            NSRange start = [text rangeOfString:[NSString stringWithFormat:@"@PJL INQUIRE %@\r\n", expected]];
            if (text && start.length) {
                NSString *tail = [text substringFromIndex:NSMaxRange(start)];
                NSRange end = [tail rangeOfString:@"\r\n\f"];
                if (end.length && end.location <= 32) { value = [tail substringToIndex:end.location]; break; }
            }
        }
        if (!value) failure(error, @"Printer did not confirm its PJL setting.");
    }
    p1102_usb_close(usb); return value;
}
NSDictionary *P1102QuietMode(NSString *serial, NSError **error)
{
    NSString *value = pjl(serial, @"@PJL INQUIRE QUIETMODE\r\n", @"QUIETMODE", error);
    if (![@[@"ON", @"OFF"] containsObject:value ?: @""]) { if (value) failure(error, @"Unknown quiet mode value."); return nil; }
    return @{@"quiet": @([value isEqual:@"ON"])};
}
BOOL P1102Set(NSString *serial, NSString *setting, NSString *value, NSError **error)
{
    NSDictionary *mapping = @{@"PowerSaveTimeout": @{@"1minute": @"1", @"5minutes": @"5", @"15minutes": @"15", @"30minutes": @"30", @"1hour": @"60"}, @"AutoOffTime": @{@"never": @"0", @"30minutes": @"30", @"1hour": @"60", @"2hours": @"120", @"4hours": @"240", @"8hours": @"480", @"24hours": @"1440"}, @"QuietMode": @{@"ON": @"ON", @"OFF": @"OFF"}};
    NSDictionary *variables = @{@"PowerSaveTimeout": @"POWERSAVETIME", @"AutoOffTime": @"INACTIVEOFFTIME", @"QuietMode": @"QUIETMODE"};
    NSString *encoded = mapping[setting][value], *variable = variables[setting];
    if (!encoded || !variable) { failure(error, @"Unsupported setting or value."); return NO; }
    NSString *command = [NSString stringWithFormat:@"@PJL SET %@=%@\r\n@PJL INQUIRE %@\r\n", variable, encoded, variable];
    NSString *actual = pjl(serial, command, variable, error);
    if (!actual) return NO;
    if (![actual isEqual:encoded]) { failure(error, @"Printer rejected the setting."); return NO; }
    return YES;
}
BOOL P1102InternalPage(NSString *serial, NSString *kind, NSError **error)
{
    if (![@[@"configurationPage", @"demoPage", @"suppliesStatusPage", @"cleaningPage"] containsObject:kind]) { failure(error, @"Unsupported internal page."); return NO; }
    NSDictionary *caps = readXML(serial, @"InternalPrintCap", error); if (!caps) return NO;
    if (![caps[@"InternalPrintCap/JobTypesSupport/JobType"] containsObject:kind]) { failure(error, @"Printer does not advertise this internal page."); return NO; }
    NSDictionary *pages = @{@"configurationPage": @"SELFTEST", @"demoPage": @"DEMOPAGE", @"suppliesStatusPage": @"SUPPLIES"};
    NSString *command = [kind isEqual:@"cleaningPage"] ? @"@PJL CLEANPRINTER\r\n" : [NSString stringWithFormat:@"@PJL SET TESTPAGE=%@\r\n", pages[kind]];
    return pjl(serial, command, nil, error) != nil;
}
NSString *P1102SerialFromURI(NSString *uri)
{
    NSURLComponents *parts = [NSURLComponents componentsWithString:uri];
    if (![parts.scheme isEqual:@"usb"] || ![parts.host isEqual:@"Hewlett-Packard"] || ![parts.path isEqual:@"/HP LaserJet Professional P1102"]) return nil;
    NSString *serial = nil;
    for (NSURLQueryItem *item in parts.queryItems) if ([item.name isEqual:@"serial"]) { if (serial) return nil; serial = item.value; }
    if (!serial.length || serial.length > 255 || [serial rangeOfCharacterFromSet:NSCharacterSet.controlCharacterSet].length) return nil;
    return serial;
}
