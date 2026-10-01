/* SPDX-License-Identifier: GPL-2.0-or-later */
#ifndef P1102_QUEUE_CHECK_H
#define P1102_QUEUE_CHECK_H
#include <cups/ipp.h>

#define P1102_QUEUE_NAME "HP_LaserJet_P1102_Native"
#ifndef P1102_CUPS_SOCKET
#define P1102_CUPS_SOCKET "/private/var/run/cupsd"
#endif
#define P1102_DEVICE_PREFIX "usb://Hewlett-Packard/HP%20LaserJet%20Professional%20P1102?"

typedef enum {
    P1102_QUEUE_ERROR = -1,
    P1102_QUEUE_ABSENT,
    P1102_QUEUE_PRESENT,
    P1102_QUEUE_FOREIGN,
    P1102_QUEUE_BUSY
} P1102QueueState;

P1102QueueState P1102InspectQueue(ipp_t *response);
P1102QueueState P1102InspectJobs(ipp_t *response);
#endif
