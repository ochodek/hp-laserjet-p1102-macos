/* SPDX-License-Identifier: GPL-2.0-or-later */
#ifndef P1102_USB_H
#define P1102_USB_H
#include <stddef.h>
#include <stdint.h>
typedef struct p1102_usb p1102_usb;
/* Only USB 03f0:002a, vendor interface ff/02/10. Never seize or reset. */
p1102_usb *p1102_usb_open(const char *serial, char *error, size_t capacity);
p1102_usb *p1102_usb_open_print(const char *serial, char *error, size_t capacity);
int p1102_usb_write(p1102_usb *, const void *, size_t);
int p1102_usb_read(p1102_usb *, void *, size_t, size_t *);
void p1102_usb_close(p1102_usb *);
#endif
