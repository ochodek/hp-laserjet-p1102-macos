/* SPDX-License-Identifier: GPL-2.0-or-later */
#import <Foundation/Foundation.h>
/* Incomplete HTTP returns nil with no error. Invalid data returns an error. */
NSData *P1102HTTPBody(NSData *data, NSInteger *status, NSError **error);
NSDictionary<NSString *, NSArray<NSString *> *> *P1102XMLValues(NSData *data, NSError **error);
NSDictionary *P1102Snapshot(NSString *serial, NSError **error);
NSDictionary *P1102Supplies(NSString *serial, NSError **error);
NSDictionary *P1102QuietMode(NSString *serial, NSError **error);
BOOL P1102Set(NSString *serial, NSString *setting, NSString *value, NSError **error);
BOOL P1102InternalPage(NSString *serial, NSString *kind, NSError **error);
NSString *P1102SerialFromURI(NSString *uri);
