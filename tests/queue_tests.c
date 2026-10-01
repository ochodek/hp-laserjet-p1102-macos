/* SPDX-License-Identifier: GPL-2.0-or-later */
#include "../src/queue-check.h"
#include <cups/cups.h>
#include <stdio.h>
#include <stdlib.h>

static unsigned checks;
#define CHECK(expression) do { checks++; if (!(expression)) { \
    fprintf(stderr, "Queue check failed at line %d: %s\n", __LINE__, #expression); exit(1); \
} } while (0)

static ipp_t *response(ipp_status_t status, const char *language)
{
    ipp_t *r = ippNew();
    ippSetStatusCode(r, status);
    ippAddString(r, IPP_TAG_OPERATION, IPP_TAG_CHARSET, "attributes-charset", NULL, "utf-8");
    ippAddString(r, IPP_TAG_OPERATION, IPP_TAG_LANGUAGE, "attributes-natural-language", NULL, language);
    return r;
}

static ipp_t *queue(const char *name, const char *uri, int type, const char *language)
{
    ipp_t *r = response(IPP_STATUS_OK, language);
    if (name) ippAddString(r, IPP_TAG_PRINTER, IPP_TAG_NAME, "printer-name", NULL, name);
    if (uri) ippAddString(r, IPP_TAG_PRINTER, IPP_TAG_URI, "device-uri", NULL, uri);
    if (type >= 0) ippAddInteger(r, IPP_TAG_PRINTER, IPP_TAG_ENUM, "printer-type", type);
    return r;
}

static void expect_queue(ipp_t *r, P1102QueueState state)
{
    CHECK(P1102InspectQueue(r) == state);
    ippDelete(r);
}

int main(void)
{
    const char *uri = P1102_DEVICE_PREFIX "serial=TEST";
    for (unsigned i = 0; i < 4; i++) {
        const char *languages[] = {"en", "cs", "de", "ja"};
        expect_queue(queue(P1102_QUEUE_NAME, uri, CUPS_PRINTER_LOCAL, languages[i]), P1102_QUEUE_PRESENT);
        ipp_t *r = response(IPP_STATUS_ERROR_NOT_FOUND, languages[i]);
        ippAddString(r, IPP_TAG_OPERATION, IPP_TAG_TEXT, "status-message", NULL, "Fronta neexistuje.");
        expect_queue(r, P1102_QUEUE_ABSENT);
    }
    expect_queue(NULL, P1102_QUEUE_ERROR);
    expect_queue(response(IPP_STATUS_ERROR_NOT_AUTHORIZED, "cs"), P1102_QUEUE_ERROR);
    expect_queue(response(IPP_STATUS_ERROR_SERVICE_UNAVAILABLE, "en"), P1102_QUEUE_ERROR);
    expect_queue(response(IPP_STATUS_OK_IGNORED_OR_SUBSTITUTED, "en"), P1102_QUEUE_ERROR);
    expect_queue(queue("Unrelated", uri, 0, "en"), P1102_QUEUE_FOREIGN);
    expect_queue(queue(P1102_QUEUE_NAME, uri, CUPS_PRINTER_CLASS, "en"), P1102_QUEUE_FOREIGN);
    expect_queue(queue(P1102_QUEUE_NAME, NULL, CUPS_PRINTER_CLASS, "en"), P1102_QUEUE_FOREIGN);
    const char *foreign[] = {
        "ipp://example.invalid/printer",
        "usb://Hewlett-Packard/HP%20LaserJet%20Professional%20P1102w?serial=TEST",
        "usb://Other/HP%20LaserJet%20Professional%20P1102?serial=TEST",
        "usb://Hewlett-Packard/HP%20LaserJet%20Professional%20P1102",
        P1102_DEVICE_PREFIX,
        ""
    };
    for (unsigned i = 0; i < sizeof(foreign) / sizeof(foreign[0]); i++)
        expect_queue(queue(P1102_QUEUE_NAME, foreign[i], 0, "cs"), P1102_QUEUE_FOREIGN);
    expect_queue(queue(NULL, uri, 0, "en"), P1102_QUEUE_ERROR);
    expect_queue(queue(P1102_QUEUE_NAME, NULL, 0, "en"), P1102_QUEUE_ERROR);
    expect_queue(queue(P1102_QUEUE_NAME, uri, -1, "en"), P1102_QUEUE_ERROR);
    expect_queue(queue(P1102_QUEUE_NAME, P1102_DEVICE_PREFIX "serial=TEST\n", 0, "en"), P1102_QUEUE_ERROR);
    ipp_t *r = queue(P1102_QUEUE_NAME, uri, 0, "en");
    ippAddString(r, IPP_TAG_PRINTER, IPP_TAG_URI, "device-uri", NULL, uri);
    expect_queue(r, P1102_QUEUE_ERROR);
    r = queue(P1102_QUEUE_NAME, uri, 0, "en");
    ippAddString(r, IPP_TAG_PRINTER, IPP_TAG_NAME, "printer-name", NULL, P1102_QUEUE_NAME);
    expect_queue(r, P1102_QUEUE_ERROR);
    r = queue(P1102_QUEUE_NAME, uri, 0, "en");
    ippAddInteger(r, IPP_TAG_PRINTER, IPP_TAG_ENUM, "printer-type", 0);
    expect_queue(r, P1102_QUEUE_ERROR);
    r = queue(P1102_QUEUE_NAME, NULL, 0, "en");
    ippAddString(r, IPP_TAG_PRINTER, IPP_TAG_TEXT, "device-uri", NULL, uri);
    expect_queue(r, P1102_QUEUE_ERROR);
    r = queue(P1102_QUEUE_NAME, NULL, 0, "en");
    ippAddString(r, IPP_TAG_OPERATION, IPP_TAG_URI, "device-uri", NULL, uri);
    expect_queue(r, P1102_QUEUE_ERROR);
    r = queue(P1102_QUEUE_NAME, NULL, 0, "en");
    const char *uris[] = {uri, uri};
    ippAddStrings(r, IPP_TAG_PRINTER, IPP_TAG_URI, "device-uri", 2, NULL, uris);
    expect_queue(r, P1102_QUEUE_ERROR);
    r = queue(P1102_QUEUE_NAME, uri, -1, "en");
    ippAddInteger(r, IPP_TAG_PRINTER, IPP_TAG_INTEGER, "printer-type", 0);
    expect_queue(r, P1102_QUEUE_ERROR);
    CHECK(P1102InspectJobs(NULL) == P1102_QUEUE_ERROR);
    r = response(IPP_STATUS_ERROR_NOT_FOUND, "cs");
    CHECK(P1102InspectJobs(r) == P1102_QUEUE_ERROR);
    ippDelete(r);
    r = response(IPP_STATUS_OK, "cs");
    CHECK(P1102InspectJobs(r) == P1102_QUEUE_PRESENT);
    ippAddInteger(r, IPP_TAG_JOB, IPP_TAG_INTEGER, "job-id", 243);
    CHECK(P1102InspectJobs(r) == P1102_QUEUE_BUSY);
    ippDelete(r);
    r = response(IPP_STATUS_OK, "en");
    ippAddString(r, IPP_TAG_JOB, IPP_TAG_NAME, "job-name", NULL, "Held job");
    CHECK(P1102InspectJobs(r) == P1102_QUEUE_BUSY);
    ippDelete(r);
    r = response(IPP_STATUS_OK, "en");
    ippAddInteger(r, IPP_TAG_PRINTER, IPP_TAG_INTEGER, "job-id", 243);
    CHECK(P1102InspectJobs(r) == P1102_QUEUE_ERROR);
    ippDelete(r);
    r = response(IPP_STATUS_OK, "en");
    ippAddInteger(r, IPP_TAG_OPERATION, IPP_TAG_INTEGER, "job-id", 243);
    CHECK(P1102InspectJobs(r) == P1102_QUEUE_ERROR);
    ippDelete(r);
    printf("%u structured queue/job checks passed.\n", checks);
    return 0;
}
