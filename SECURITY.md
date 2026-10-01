# Security, 1.7.2

**English** | [Česky](SECURITY.cs.md)

This vibe-coded project was developed with AI assistance. An internal code and security review was performed on 1 October 2026; findings, fixes, evidence and coverage limits are in [REVIEW.md](REVIEW.md). It is not an independent audit or a guarantee that every defect has been found.

## Runtime and permissions

The native raster filter validates monochrome CUPS input and uses the pinned foo2zjs/JBIG encoder. It links to system libcups and libSystem. The command filter and CLI use Foundation and IOKit; P1102 Utility additionally uses Cocoa, PDFKit and PrintCore. Version 1.7.2 adds a read-only libcups queue guard for installation/removal. All release executables are ARM64.

Runtime code has no internet client, telemetry, updater, shell execution, download logic, credential/keychain access, persistent background agent, kernel extension, firmware modification or factory reset. The queue guard uses HTTP/IPP only through the fixed local macOS CUPS domain socket; authentication challenges fail instead of prompting for a password. HTTP-framed device management messages travel over USB. The application talks to two model-specific USB interfaces without seizing or resetting them. Commands and settings are allowlisted; users' names and document titles are not put in printer commands.

The installer requires administrator permission for root-owned driver files, the application and its own CUPS queue. Executables use mode 0755 with no setuid bit. It preserves the original HP queue and default printer choice. The application runs as the logged-in user and needs no administrator permission for normal use. macOS handles document spooling. Installation rejects conflicting queues, unrelated utility bundles and symbolic links in owned destinations. The supplied uninstaller removes only named files, checks queue/application identity and refuses pending native jobs. Removal contract tests use mocks; the working installation was not destructively removed during validation.

The payload contains the raster filter, `commandtop1102`, `p1102ctl`, `p1102-queue-check`, license and complete source archive under `/Library/Printers/P1102Native`, the PPD under `/Library/Printers/PPDs/Contents/Resources`, and `/Applications/P1102 Utility.app`. No launch agent/daemon is installed. UI automation permission used during development is not a driver requirement.

The 1.7.2 guard requires typed queue identity and no incomplete jobs before updating or deleting a queue. Only explicit IPP not-found means absence; connection, authentication and protocol failures stop changes. Queries and administration are pinned to the same local socket. Checks are snapshots, so concurrent queue changes or new jobs can still race the final check. Cause, tests and coverage limits are recorded in [queue validation](docs/queue-validation.md).

## Input handling and privacy

* Raster geometry, dimensions, bit depth, page size, media/source/quality codes, copies and print-option ranges are validated before use. Page buffers are bounded by supported physical sizes. Truncated pages fail instead of reporting completion.
* USB transfers have deadlines; failed reads never expose uninitialized buffers. HTTP responses have a 512 KiB total bound, 8 KiB header bound and strict length/chunk framing. Unknown/duplicate toner values are not converted into percentages.
* XML is UTF-8, with DTD/entity declarations rejected, external entity loading disabled, depth/node/text limits and exact paths for current versus previous cartridge data.
* PDF inputs are user-selected, printable and unlocked, with file/page/output limits. The original is not overwritten by preparation. Exports use explicit save dialogs; printing uses system spooling. The 256 MiB serialized-output limit applies to each write and finalization. It is not a total-memory or CPU limit. Cropping is not redaction; clipped content may remain in exports. The app is not App Sandbox isolated. PDFKit and the OS are trusted dependencies whose internals are outside this audit.
* GUI diagnostic export selects specific fields and omits serial numbers, usernames, file paths and document contents. CLI status intentionally includes device identity, so redact it before sharing. Development USB captures, print files and photographs are ignored by Git and excluded from the source package.

## Checks and limits

Strict warnings and Clang Static Analyzer cover first-party source. Raster, protocol, HTTP/XML and PDF contract suites run normally and under AddressSanitizer/UndefinedBehaviorSanitizer, with leak detection disabled. See REVIEW.md for actual outcomes and the distinction between direct USB checks, scheduler integration and physical printing.

The pinned upstream source and hashes remain unchanged. Linker dead stripping removes the unused foo2zjs CLI, color parsers and JBIG decoder from the raster executable. Earlier analysis of all `jbig.c` reported 13 candidates involving dead stores, zero-size allocations, initialization and decoder paths. The used encoder receives validated positive dimensions, one plane and fixed JBIG settings; relevant indexed initialization fills all entries. These candidates were not reproduced in the used path. Historical `sprintf` warnings are in unused color paths absent from the release filter. This is not a claim that the whole upstream library is defect-free.

The package is **not Developer ID signed or notarized**. Ad-hoc signatures do not identify or certify a publisher. SHA-256 checksums detect modified downloads but do not establish independent trust. Do not disable Gatekeeper or SIP to install it. Future macOS support depends on Apple retaining CUPS/PPD, rasterization, IOKit and USB functionality. Physical testing of every medium, error state and supported OS version has not been performed.
