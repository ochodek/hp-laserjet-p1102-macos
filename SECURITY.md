# Security

**English** | [Česky](SECURITY.cs.md)

Local review performed on 1 October 2026. This vibe-coded project was developed with AI assistance. The checks below found no intentionally malicious behavior, but they are not an independent security audit or a guarantee that every defect has been found.

## Installed code and permissions

The installed program contains the CUPS adapter, ZjStream encoder, and JBIG encoder. It links only to system `libcups.2.dylib` and `libSystem.B.dylib`. It contains no network client, telemetry, updater, shell commands, downloads, keychain access, or background service. It installs no kernel extension and modifies no printer firmware. macOS handles USB transport.

Unused CLI paths, color-input parsers, and the JBIG decoder are removed by the linker. The release filter was checked for process-launching, network/socket, and decoder symbols. It creates no temporary files; CUPS supplies the raster input path. Usernames and job titles are not inserted into the printer protocol.

The filter is installed as `root:wheel`, mode `0755`, without a setuid bit. The installer discovers a connected USB P1102 and creates its own queue; updates refresh only that queue's PPD and resolution. It does not replace the HP queue or select a new default. Device URIs are quoted arguments, never evaluated as shell commands. CUPS protections, Gatekeeper, and SIP are not disabled.

Apart from the standard installer receipt and CUPS queue configuration, the payload contains:

* `/Library/Printers/P1102Native/rastertop1102`
* `/Library/Printers/P1102Native/LICENSE`
* `/Library/Printers/P1102Native/Source.tar.gz`
* `/Library/Printers/PPDs/Contents/Resources/HP-P1102-Native.ppd`

## Checks performed

* Adapter compilation with `-Wall -Wextra -Werror`; Clang Static Analyzer reported no findings in that adapter.
* Native ARM64 architecture and valid ad-hoc code signature.
* Pinned vendored-source revision and SHA-256 checksums; expanded package contents and installed files compared with the build.
* Eight tests decode actual JBIG output and check complete images, white padding, edge preservation, copy counts, polarity, and printer mode. All 256 tone populations and a separate image are compared with measured HP output.
* Fractional CUPS Raster v2 geometry is covered. Nonfinite, inverted, out-of-page and extreme header values, empty jobs, and truncated raster data are rejected.
* The same tests passed under AddressSanitizer and UndefinedBehaviorSanitizer. Leak detection was disabled in that run.
* The local Apple rasterizer and filter path was exercised for all five paper sizes. Actual A4 prints were compared; data tests do not establish physical alignment on every printer.

## Vendored-code findings and limits

Analysis of the complete `jbig.c` reported 13 candidates involving unused assignments, general zero-size allocations, indexed initialization, and decoder paths. The decoder is not linked into the installed filter. The encoder receives validated positive dimensions, one plane, fixed strip height and ordering. The relevant indexed initialization fills all three entries. These candidates were not reproduced in the used path; this is not a claim that the entire library is defect-free.

The compiler also warns about historical `sprintf` calls in unused color paths of foo2zjs. Those paths and calls are absent from the installed program. Vendored source files are retained unchanged for comparison with the pinned revision.

The installer is **not Developer ID signed or notarized**. Ad-hoc signing is not publisher verification. Release checksums establish file integrity, not independent trust in the author. macOS system libraries and the printing stack remain dependencies. Tests do not cover every possible document or malformed input.
