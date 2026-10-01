/* SPDX-License-Identifier: GPL-2.0-or-later */
#include "usb.h"
#include <CoreFoundation/CoreFoundation.h>
#include <IOKit/IOKitLib.h>
#include <IOKit/IOCFPlugIn.h>
#include <IOKit/usb/IOUSBLib.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

struct p1102_usb { IOUSBInterfaceInterface182 **interface; UInt8 input, output; };

static p1102_usb *open_interface(const char *serial, int printing, char *error, size_t capacity)
{
    snprintf(error, capacity, "P1102 is disconnected, busy or USB access was denied.");
    CFMutableDictionaryRef match = IOServiceMatching(kIOUSBDeviceClassName);
    if (!match) return NULL;
    int vid = 0x03f0, pid = 0x002a;
    CFNumberRef v = CFNumberCreate(NULL, kCFNumberIntType, &vid);
    CFNumberRef p = CFNumberCreate(NULL, kCFNumberIntType, &pid);
    if (!v || !p) { if (v) CFRelease(v); if (p) CFRelease(p); CFRelease(match); return NULL; }
    CFDictionarySetValue(match, CFSTR(kUSBVendorID), v);
    CFDictionarySetValue(match, CFSTR(kUSBProductID), p);
    CFRelease(v); CFRelease(p);
    io_iterator_t devices = 0;
    if (IOServiceGetMatchingServices(kIOMasterPortDefault, match, &devices)) return NULL;
    io_service_t device, selected = 0;
    unsigned count = 0;
    while ((device = IOIteratorNext(devices))) {
        int matches = !serial || !*serial;
        if (!matches) {
            CFTypeRef value = IORegistryEntryCreateCFProperty(device, CFSTR("USB Serial Number"), NULL, 0);
            char actual[256];
            matches = value && CFGetTypeID(value) == CFStringGetTypeID() &&
                CFStringGetCString(value, actual, sizeof(actual), kCFStringEncodingUTF8) && !strcmp(serial, actual);
            if (value) CFRelease(value);
        }
        if (matches) { ++count; if (!selected) { selected = device; continue; } }
        IOObjectRelease(device);
    }
    IOObjectRelease(devices);
    if (count != 1) {
        if (selected) IOObjectRelease(selected);
        if (count > 1) snprintf(error, capacity, "Multiple P1102 printers connected; select one by USB serial.");
        return NULL;
    }
    IOCFPlugInInterface **plugin = NULL;
    IOUSBDeviceInterface **dev = NULL;
    SInt32 score = 0;
    IOReturn result = IOCreatePlugInInterfaceForService(selected, kIOUSBDeviceUserClientTypeID,
        kIOCFPlugInInterfaceID, &plugin, &score);
    IOObjectRelease(selected);
    if (result || !plugin) return NULL;
    (*plugin)->QueryInterface(plugin, CFUUIDGetUUIDBytes(kIOUSBDeviceInterfaceID), (LPVOID *)&dev);
    IODestroyPlugInInterface(plugin);
    if (!dev) return NULL;
    IOUSBFindInterfaceRequest request = {printing ? 7 : 255, printing ? 1 : 2, printing ? 2 : 16, kIOUSBFindInterfaceDontCare};
    io_iterator_t interfaces = 0;
    result = (*dev)->CreateInterfaceIterator(dev, &request, &interfaces);
    (*dev)->Release(dev);
    if (result) return NULL;
    p1102_usb *usb = NULL;
    io_service_t service;
    while ((service = IOIteratorNext(interfaces))) {
        IOUSBInterfaceInterface182 **interface = NULL;
        plugin = NULL;
        result = IOCreatePlugInInterfaceForService(service, kIOUSBInterfaceUserClientTypeID,
            kIOCFPlugInInterfaceID, &plugin, &score);
        IOObjectRelease(service);
        if (result || !plugin) continue;
        (*plugin)->QueryInterface(plugin, CFUUIDGetUUIDBytes(kIOUSBInterfaceInterfaceID182), (LPVOID *)&interface);
        IODestroyPlugInInterface(plugin);
        if (!interface) continue;
        /* The utility and CUPS can refresh at the same instant. Let a short
           read-only exchange finish instead of reporting a false unknown level.
           Never force ownership, and never retry permission/device errors. */
        for (unsigned attempt = 0; attempt < 11; attempt++) {
            result = (*interface)->USBInterfaceOpen(interface);
            if ((result != kIOReturnExclusiveAccess && result != kIOReturnBusy) || attempt == 10) break;
            struct timespec delay = {0, 50000000}; nanosleep(&delay, NULL);
        }
        if (result) { (*interface)->Release(interface); continue; }
        UInt8 endpoints = 0, input = 0, output = 0;
        if (!(*interface)->GetNumEndpoints(interface, &endpoints)) {
            for (unsigned i = 1; i <= endpoints; i++) {
                UInt8 direction, number, type, interval; UInt16 packet;
                if ((*interface)->GetPipeProperties(interface, i, &direction, &number, &type, &packet, &interval)) continue;
                if (type == kUSBBulk) { if (direction == kUSBIn) input = i; else if (direction == kUSBOut) output = i; }
            }
        }
        if (input && output && (usb = calloc(1, sizeof(*usb)))) {
            usb->interface = interface; usb->input = input; usb->output = output; break;
        }
        (*interface)->USBInterfaceClose(interface); (*interface)->Release(interface);
    }
    IOObjectRelease(interfaces);
    return usb;
}

int p1102_usb_write(p1102_usb *usb, const void *bytes, size_t length)
{
    if (!usb || length > 8192) return -1;
    IOReturn result = (*usb->interface)->WritePipeTO(usb->interface, usb->output, (void *)bytes, (UInt32)length, 1500, 2000);
    if (result == kIOReturnBusy || result == kIOReturnNotOpen || result == kIOReturnAborted ||
        result == kIOReturnTimeout || result == kIOReturnNotResponding) return P1102_USB_TRANSIENT;
    return result ? -1 : 0;
}

int p1102_usb_read(p1102_usb *usb, void *bytes, size_t capacity, size_t *length)
{
    *length = 0;
    if (!usb || capacity > 16384) return -1;
    UInt32 size = (UInt32)capacity;
    IOReturn result = (*usb->interface)->ReadPipeTO(usb->interface, usb->input, bytes, &size, 1000, 1500);
    /* On error IOUSBLib may leave size unchanged. Never expose that buffer. */
    if (result || size > capacity) return -1;
    *length = size;
    return 0;
}

void p1102_usb_close(p1102_usb *usb)
{
    if (!usb) return;
    (*usb->interface)->USBInterfaceClose(usb->interface);
    (*usb->interface)->Release(usb->interface);
    free(usb);
}

p1102_usb *p1102_usb_open(const char *serial, char *error, size_t capacity)
{ return open_interface(serial, 0, error, capacity); }
p1102_usb *p1102_usb_open_print(const char *serial, char *error, size_t capacity)
{ return open_interface(serial, 1, error, capacity); }
