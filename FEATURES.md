# Features and device data

[Česky](FEATURES.cs.md)

Version 1.7 is being validated. This is a functional comparison, not a claim of HP certification or identical behavior on every document. The target remains the USB P1102, not P1102w or other models.

## Printing

| Function | Native implementation |
| --- | --- |
| FastRes 600 / FastRes 1200 | Print dialog; both use 600 dpi grayscale input and four exposure levels. The 1200 quality mode can be slower. |
| EconoMode | Print dialog, job-scoped printer toner-saving command |
| Density 1–5 | Print dialog; default 3 |
| Recovery after a paper jam | Print dialog; off or automatic reprint |
| Paper selection | 18 named formats, including envelopes/postcards, and custom 76.2 × 127 to 215.9 × 355.6 mm |
| Paper type | 16 types, including plain, light, mid-weight, heavy, extra heavy, laser transparency, labels, envelope, letterhead, preprinted, prepunched, colored, bond, recycled, rough and vellum |
| Paper source | Automatic or manual feed |
| Copies, collating, page ranges, scaling, orientation, reverse order, N-up, saved presets | macOS print dialog, subject to the printing application's options |
| Different paper for covers | Print cover and body page ranges separately, choosing the appropriate paper type for each job. There is no automatic cover-insertion workflow. |
| Manual two-sided printing | P1102 Utility, PDF workflow with separate front/back passes, long/short-edge binding and blank-back padding. Not an automatic duplexer or an in-dialog duplex implementation for every application. A four-page test on the connected printer confirmed pairs 1/2 and 3/4 with upright book-style turning after transferring the stack unchanged. |
| Booklets | Utility prepares A4 landscape PDFs for left/right binding and pads to multiples of four pages; preview before printing. Physical four-page, left-bound booklet with watermark confirmed on one P1102. |
| Watermarks | Utility adds custom text on all output pages or the first output page, with preview and PDF export |
| Fine placement | Existing 1.6 geometry is preserved. Advanced CUPS options `P1102ShiftX` (-15…68) and `P1102ShiftY` (-31…0) move pixels within the reserved white padding, at 600 dpi. Not a mechanical alignment correction. |

PDF tools accept printable, unlocked PDFs up to 200 MB and 2,000 pages. They create a separate flattened output PDF; they do not edit the source. Printed annotations are retained, but interactive fields, links and digital signature validity are not preserved in the generated copy. Always inspect the preview for important documents. Manual duplex forces one copy and one page per sheet for each pass; booklet imposition is already in the prepared PDF.

## P1102 Utility

Open **Applications → P1102 Utility**, or the printer's utility button if macOS exposes it. The interface follows the Mac's preferred language (English or Czech). Refresh reads the printer directly over USB. A failed refresh shows unavailable data, not an old percentage. The utility runs only while open; there is no background agent, telemetry or internet service.

* Live estimated black-toner percentage, cartridge model, cartridge state and last successful read time.
* Lifetime and current-cartridge page counts, printer-estimated remaining pages, jam/misfeed counts, event codes, firmware date and configured tray media.
* Sleep timer, automatic power-off timer and quiet mode, each confirmed by a read-back. Reading status does not change these settings.
* Configuration, supplies, demo and cleaning-page commands with an explicit user action. Cleaning requires appropriate plain copier paper and takes several minutes. The user physically confirmed the supplies page and its 60% toner reading; configuration, demo and cleaning pages remain untested.
* Diagnostic JSON export using a fixed field allowlist, excluding device and cartridge serial numbers, usernames, paths and document contents.
* Native CLI `/Library/Printers/P1102Native/p1102ctl` for `status`, `supplies`, `set`, and `page`. CLI status includes the device serial, so redact it before sharing. With multiple connected P1102s, supply the USB serial to the CLI; the GUI refuses an ambiguous selection.
* CUPS `ReportLevels` command for macOS supply information. The last CUPS value can remain cached; the utility's timestamp distinguishes a fresh USB read. The installed scheduler successfully executed ReportLevels and published a fresh marker value on macOS 27.0.1.

## What the tested printer actually returned

The USB device exposes two interfaces: printing (`07/01/02`) and a vendor management interface (`ff/02/10`). The latter transports HTTP-framed XML **over USB**, without opening a network connection. On 1 October 2026, native reads returned:

| Data | Observed availability |
| --- | --- |
| Toner | Estimated percentage, state, brand, CE285A product number, nominal capacity and unit, manufacture/last-use dates; cartridge identification fields also exist |
| Usage | Lifetime pages, current cartridge pages, estimated remaining pages, jam/misfeed counts, previous-cartridge usage and dates |
| Identity | Model, product number, serial, firmware date, controller/board identifiers, service identifier and memory fields |
| State | Ready/sleep/processing and advertised categories for jams, open cover, paper feed, manual duplex, full output, memory and cartridge problems |
| Events | Event codes and page counts at recorded events |
| Settings/capabilities | Paper formats/types, tray defaults, density, jam recovery, quality modes, sleep/power-off intervals, available internal pages and languages |

Some fields describe configured defaults, not sensors. For example, the reported tray size does not prove which paper was physically loaded. Toner and remaining pages are firmware estimates, not measurements of toner weight. Not all advertised fault states were physically induced. Old-cartridge fields must not be mistaken for current-cartridge values. Raw identifiers and unsupported maintenance controls are intentionally not exposed as routine user controls.

## Limits and possible later work

The P1102 has no scanner, color engine, automatic duplex mechanism, or built-in Wi-Fi. Software cannot add that hardware. Network sharing through the Mac is a separate macOS feature; this package does not install an AirPrint bridge, internet print service, firmware updater or security-reset function.

Further bounded additions could include a guided multi-sheet alignment calibration, opt-in notifications while the utility is open, job-cost estimates with user-supplied prices, a cover/body printing wizard, and a separately reviewed IPP/AirPrint bridge. These are not included or claimed as working.

Sources: [HP P1100 user guide](https://h10032.www1.hp.com/ctg/Manual/c04697535.pdf), the locally installed HP 6.9 PPD and observed offline output, [OpenPrinting foo2zjs](https://github.com/OpenPrinting/foo2zjs), and read-only capability responses from the connected printer. Windows guidance informed the booklet/watermark workflows; no Windows, HP macOS or HPLIP proprietary binary is redistributed.
