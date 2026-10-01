# Code review and security review, 1.7 candidate

Date: 1 October 2026. This is an internal review performed by the same AI coding agent that implemented the change, not an independent audit, penetration-test certificate or vendor approval. Open items below are release gates, not successful tests.

## Scope and method

Reviewed the complete native raster adapter and job header, the USB transport, HTTP/XML processing, supply and settings API, CUPS command filter, CLI, Cocoa utility, PDF transformations, PPD, build, installer and removal scripts. Reviewed the dependency boundary to the unchanged pinned foo2zjs/JBIG sources and retained the prior findings described in SECURITY.md. No proprietary HP binary is included in the build.

The functional review followed data from print options through CUPS raster headers into decoded ZjStream, then compared the default printer stream with installed 1.6. A separate security pass covered untrusted raster input, USB responses, XML expansion, command injection, file handling, identifier disclosure, privilege boundaries, resource limits and installer payloads. The UI was exercised through actual application controls, not inferred from source alone.

## Findings and fixes

| Finding | Impact | Resolution and evidence |
| --- | --- | --- |
| Unavailable optional supply metadata could fail a CUPS command job | Misleading filter-failure indication despite working printing | Emit unknown (-2) and an explicit warning while completing the metadata command. CLI errors remain failures. A nonexistent-device contract test verifies this. |
| Concurrent utility/CUPS refreshes competed for the management interface | A refresh could mark toner unknown despite a connected printer | Retry busy/exclusive-open errors for at most 0.5 seconds; no forced claim. A transient USB write may reopen and repeat one read-only GET, with a fixed error allowlist and one retry. Permission/disconnection errors, HTTP/XML errors and state-changing PJL commands are not replayed. Fault-injection tests verify these boundaries. Twenty-two overlapping installed-CUPS/CLI status pairs passed before the additional write-recovery change, and three more passed against the final installed binaries (jobs 69–71), with no snapshot warnings; the earlier single write failure was not reproduced and its exact OS cause is unconfirmed. |
| CUPS serializes boolean choices as bare `EconoMode` / `noEconoMode` | Explicit economy selections failed before printing | Accept case-insensitive true/false from `cupsParseOptions`, retaining rejection of invalid values. A regression test first reproduced all four failures, then passed for scheduler syntax and explicit case variants, including jam recovery. |
| Long utility labels could extend beyond the tab | Important instructions were clipped | Constrain wrapping labels to a stack anchored inside a tab container. Both complete PDF instructions were visually checked in the running app. |
| Installer distribution advertised 1.6 while its component was 1.7 | Inconsistent installer metadata | Set both versions to 1.7 and assert agreement in the expanded package. |
| Notices were only inside the source archive | Credits/licence were hard for users to find | Add installed NOTICE, app licence resources and an About/licence action. Verify every public project source is included in the archive. |
| USB reads can leave the requested byte count unchanged on error | Could copy uninitialized buffer bytes into a response | Ignore the count and buffer on every failed read. The public transport sets output length to zero before calling IOKit. |
| HTTP fragments can end inside a header, chunk length, payload or terminator | Partial or misframed supply values | Strict bounded framing parser; every proper prefix of a representative chunked message remains incomplete, not successful. Conflicting and duplicate framing headers are rejected. |
| Untrusted XML can declare entities or excessive nesting | File access or memory exhaustion | UTF-8 only, no DTD/entity declarations, external entities disabled, message/depth/node/text limits. Malicious entity fixtures and depth-limit tests pass. |
| Toner placeholders, out-of-range numbers or duplicate fields | Could display an invented percentage | Require exactly one unsigned integer in 0–100; otherwise omit the level. UI says unavailable; CUPS receives unknown (-2). |
| Current and previous cartridges reuse field names | Wrong usage count | Extract exact XML paths. A fixture with a much larger previous-cartridge counter confirms the current value is used. |
| Local autorelease pool could invalidate the PDF error out-parameter | Use-after-free when reporting certain PDF failures | Hold the error in a strong variable outside the per-page pool; assign it to the caller only after the pool. Clang analysis is clean after repair. |
| Raw CoreGraphics page rendering drops PDF annotations | Missing visible document content | Use PDFKit's page drawing, retaining annotation appearance. A free-text annotation survives the prepared PDF test. |
| CUPS queue ID differs from the human-readable NSPrinter name | Utility incorrectly said the installed printer was missing | Resolve the native queue by PrintCore printer ID. The UI now selects the installed native queue and cancellation leaves duplex unarmed. |
| NSPrintOperation copies NSPrintInfo | Changes applied to the old object would not control the real job | Edit `op.printInfo`. Manual passes force one copy, all pages, one page per sheet and normal output order; saving instead of printing does not advance duplex state. |
| Odd page count and output-stack reversal | Mismatched fronts/backs | Pad the missing final back; fronts ascend and backs descend, following foo2zjs manual-duplex ordering. Pairing and rotation are tested; physical long-edge duplex and left-bound booklet refeeding were confirmed by the user. |
| Ambiguous multiple identical USB printers | Could act on a different device | Require a unique VID/PID match or exact serial; never seize/reset a USB interface. GUI reports ambiguity; CLI accepts an explicit serial. |
| Export of full raw device responses | Exposure of serials and document metadata | GUI diagnostic export has a fixed field allowlist; raw USB responses stay in ignored development diagnostics. CLI identity output is explicitly documented as private. |
| Installer application destination | Relocation must not select a developer checkout | Confirmed that inferred metadata was already non-relocatable; explicit component metadata and a package assertion retain that property. |
| Old package-root contents could be carried into an update | Unintended installed files | Use a separate 1.7 staging directory; verify expanded payload before installation/release. |

The command-filter analyzer also flagged a possible open stream leak because it could not distinguish `stdin` by pointer identity. Closing the file explicitly when the filename argument was used resolved the finding.

## Automated evidence

* Strict compiler warnings (`-Wall -Wextra -Werror`) for all first-party release sources.
* Clang Static Analyzer: no reported findings in first-party sources after the fixes. This is a bounded tool result, not proof of safety.
* Twelve raster/protocol contract tests: full-image and 256-tone regressions, fractional geometry, copies, polarity, job settings, paper/media/quality codes, malformed and truncated input.
* HTTP/XML/device contracts: fragmented messages, malformed framing, mutation corpus, size/depth/entity restrictions, unknown/duplicate levels, scoped counters, command allowlists and URI identity validation.
* PDF contracts: booklet order and padding, front/back pairing, binding rotation, source preservation, first-page watermark, printed annotations, page rotation and limits.
* These suites run under AddressSanitizer and UndefinedBehaviorSanitizer. Leak detection is disabled; system frameworks are not rebuilt or audited by these checks.
* Installer expanded to exactly the expected payload; all runtime binaries are ARM64 with valid ad-hoc signatures and non-setuid modes. Source archive content matched the source tree. Installation succeeded on the local Mac.
* UI checks covered fresh toner, quiet-mode reading, PDF opening/preview, native printer selection, cancelling the first pass without enabling the second, and complete line-wrapped instructions. System Settings, Options & Supplies, Supply Levels visibly displayed a 60% bar after a fresh CUPS command. The installed About dialog and its View licence button opened the bundled GPL text successfully.
* Default ZjStream matches the installed 1.6 output byte-for-byte after normalizing the job timestamp on the held-out raster fixture.
* Live native USB: supplies, usage, product settings, capability resources and event information read successfully. Sleep, auto-off and quiet-mode settings were changed to different allowed values, confirmed by read-back and then restored to their original values, again confirmed. Live USB status was also read under ASan/UBSan without findings.
* Direct and installed-scheduler `commandtop1102 ReportLevels` both returned fresh marker attributes. Scheduler job 37 completed and the native queue exposed 60% black toner with a new marker-change-time, idle state and no error.

The macOS 27 `pkgbuild` tool printed four `write: Permission denied` diagnostics while returning success. The cause has not been established. Expanded payload bytes, source completeness, code signatures, installation and installed runtime bytes all passed verification; the diagnostics are retained in the local build log, not silently described as a warning-free build.

## Security properties and residual risks

There is no shell execution, network client, telemetry, automatic downloader, persistent agent, kernel extension, firmware updater, factory-reset operation or credential access in the runtime code. HTTP is a framing format on USB, not an internet connection. PJL values and operations come from fixed allowlists. Both USB interfaces use normal exclusive opens, bounded transfers, no force-claim and no reset.

The app reads PDFs the user selects and writes only explicit exports; system printing manages its own spool. The CLI and command filter have no file-writing feature. No setuid executable is installed. The installer needs administrator permission to place driver files and configure its own queue; the GUI does not need administrator privileges. Shared CUPS, IOKit, PDFKit and OS parsing remain dependencies, and malformed PDFs may still stress or expose defects in those frameworks.

The supplied package uses ad-hoc code signatures. There is no Developer ID signing or notarization. Bounds and tests lower risk but do not prove that the driver is free of every vulnerability. Existing vendor-code findings and unsigned-package limitations are described in SECURITY.md.

## Remaining release gates

* A four-page manual duplex test through the installed GUI printed fronts 1/3 and backs 4/2. The user confirmed correct 1/2 and 3/4 pairing and upright book-style turning on 1 October 2026. A four-page left-bound booklet with a watermark was then printed on one sheet through both passes; the user confirmed page order, orientation and watermark. Both quality modes, toner-saving/density effects and internal pages still need physical confirmation. Do not trigger cleaning automatically merely to satisfy a test count.
* Validate actual paper feeding before claiming envelope/heavy-stock support beyond protocol parity. Do not test inappropriate media in the printer.
* Second Mac and older macOS releases remain untested; macOS 28 compatibility cannot be promised.

Development captures can contain hardware identifiers and remain excluded by `.gitignore`. This review does not publish them or the user's photographed documents.
