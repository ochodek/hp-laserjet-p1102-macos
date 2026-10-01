/* SPDX-License-Identifier: GPL-2.0-or-later */
#include "queue-check.h"
#include <cups/cups.h>
#include <stdio.h>
#include <string.h>

P1102QueueState P1102InspectQueue(ipp_t *response)
{
    if (!response) return P1102_QUEUE_ERROR;
    if (ippGetStatusCode(response) == IPP_STATUS_ERROR_NOT_FOUND)
        return P1102_QUEUE_ABSENT;
    if (ippGetStatusCode(response) != IPP_STATUS_OK) return P1102_QUEUE_ERROR;

    const char *name = NULL, *uri = NULL;
    int have_type = 0, type = 0;
    for (ipp_attribute_t *a = ippFirstAttribute(response); a; a = ippNextAttribute(response)) {
        const char *key = ippGetName(a);
        if (!key) continue;
        if (!strcmp(key, "printer-name") || !strcmp(key, "device-uri") || !strcmp(key, "printer-type")) {
            if (ippGetGroupTag(a) != IPP_TAG_PRINTER || ippGetCount(a) != 1)
                return P1102_QUEUE_ERROR;
            if (!strcmp(key, "printer-name")) {
                if (name || ippGetValueTag(a) != IPP_TAG_NAME) return P1102_QUEUE_ERROR;
                name = ippGetString(a, 0, NULL);
                if (!name) return P1102_QUEUE_ERROR;
            } else if (!strcmp(key, "device-uri")) {
                if (uri || ippGetValueTag(a) != IPP_TAG_URI) return P1102_QUEUE_ERROR;
                uri = ippGetString(a, 0, NULL);
                if (!uri) return P1102_QUEUE_ERROR;
            } else {
                if (have_type || ippGetValueTag(a) != IPP_TAG_ENUM) return P1102_QUEUE_ERROR;
                have_type = 1;
                type = ippGetInteger(a, 0);
            }
        }
    }
    if (!name || !have_type || type < 0) return P1102_QUEUE_ERROR;
    if (strcmp(name, P1102_QUEUE_NAME) || (type & CUPS_PRINTER_CLASS))
        return P1102_QUEUE_FOREIGN;
    if (!uri) return P1102_QUEUE_ERROR;
    size_t prefix = strlen(P1102_DEVICE_PREFIX);
    if (strncmp(uri, P1102_DEVICE_PREFIX, prefix) || !uri[prefix])
        return P1102_QUEUE_FOREIGN;
    for (const unsigned char *p = (const unsigned char *)uri; *p; p++)
        if (*p <= 32 || *p >= 127) return P1102_QUEUE_ERROR;
    return P1102_QUEUE_PRESENT;
}

P1102QueueState P1102InspectJobs(ipp_t *response)
{
    if (!response || ippGetStatusCode(response) != IPP_STATUS_OK)
        return P1102_QUEUE_ERROR;
    for (ipp_attribute_t *a = ippFirstAttribute(response); a; a = ippNextAttribute(response)) {
        if (ippGetGroupTag(a) == IPP_TAG_JOB) return P1102_QUEUE_BUSY;
        const char *key = ippGetName(a);
        if (ippGetGroupTag(a) != IPP_TAG_OPERATION || (key && !strncmp(key, "job-", 4)))
            return P1102_QUEUE_ERROR;
    }
    return P1102_QUEUE_PRESENT;
}

#ifndef P1102_QUEUE_CHECK_TESTS
#include <pwd.h>
#include <sys/socket.h>
#include <unistd.h>

static const char *no_password(const char *prompt, http_t *connection,
                               const char *method, const char *resource, void *data)
{
    (void)prompt; (void)connection; (void)method; (void)resource; (void)data;
    return NULL; /* A guard must fail closed instead of prompting for credentials. */
}

static ipp_t *query(http_t *connection, ipp_op_t operation)
{
    ipp_t *request = ippNewRequest(operation);
    if (!request) return NULL;
    struct passwd *user = getpwuid(geteuid());
    if (!user) { ippDelete(request); return NULL; }
    ippAddString(request, IPP_TAG_OPERATION, IPP_TAG_URI, "printer-uri", NULL,
                 "ipp://localhost:631/printers/" P1102_QUEUE_NAME);
    ippAddString(request, IPP_TAG_OPERATION, IPP_TAG_NAME, "requesting-user-name", NULL, user->pw_name);
    if (operation == IPP_OP_GET_PRINTER_ATTRIBUTES) {
        const char *attributes[] = {"printer-name", "device-uri", "printer-type"};
        ippAddStrings(request, IPP_TAG_OPERATION, IPP_TAG_KEYWORD, "requested-attributes", 3, NULL, attributes);
    } else {
        ippAddString(request, IPP_TAG_OPERATION, IPP_TAG_KEYWORD, "requested-attributes", NULL, "job-id");
        ippAddString(request, IPP_TAG_OPERATION, IPP_TAG_KEYWORD, "which-jobs", NULL, "not-completed");
        ippAddBoolean(request, IPP_TAG_OPERATION, "my-jobs", 0);
        ippAddInteger(request, IPP_TAG_OPERATION, IPP_TAG_INTEGER, "limit", 1);
    }
    return cupsDoRequest(connection, request, "/");
}

int main(int argc, char **argv)
{
    (void)argv;
    if (argc != 1) { fputs("Usage: p1102-queue-check\n", stderr); return 1; }
    cupsSetPasswordCB2(no_password, NULL);
    /* Pin the macOS domain socket: no TCP listener or inherited CUPS_SERVER is needed. */
    http_t *connection = httpConnect2(P1102_CUPS_SOCKET, 0, NULL, AF_UNSPEC,
                                     HTTP_ENCRYPTION_IF_REQUESTED, 1, 5000, NULL);
    P1102QueueState state = P1102_QUEUE_ERROR;
    if (connection) {
        httpSetTimeout(connection, 5.0, NULL, NULL);
        ipp_t *response = query(connection, IPP_OP_GET_PRINTER_ATTRIBUTES);
        state = P1102InspectQueue(response);
        ippDelete(response);
        if (state == P1102_QUEUE_PRESENT) {
            response = query(connection, IPP_OP_GET_JOBS);
            state = P1102InspectJobs(response);
            ippDelete(response);
        }
        httpClose(connection);
    }
    if (state == P1102_QUEUE_ABSENT) { puts("absent"); return 0; }
    if (state == P1102_QUEUE_PRESENT) { puts("present"); return 0; }
    if (state == P1102_QUEUE_FOREIGN)
        fputs("The native queue name is used by another printer or class. No queue changes were made.\n", stderr);
    else if (state == P1102_QUEUE_BUSY)
        fputs("Finish or cancel pending native print jobs before installing or uninstalling.\n", stderr);
    else
        fputs("Cannot verify the native queue with local CUPS. Check the printing service before retrying.\n", stderr);
    return 1;
}
#endif
