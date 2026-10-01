# P1102 Native: driver for HP LaserJet P1102 on macOS

**English** | [Česky](README.cs.md)

An independent, open-source USB printer driver for the **HP LaserJet Professional P1102** on **Apple Silicon Macs (M1 or newer)**. The filter runs natively as ARM64, without Rosetta, the original HP software, Homebrew, or an internet connection at print time.

**This is a vibe-coded project:** it was developed iteratively with an AI coding assistant, automated checks, and real print tests. It is a community experiment, not an independently audited or vendor-certified driver. See [validation](#compatibility-and-validation) and [security notes](SECURITY.md) for what was actually checked.

The project started after a macOS upgrade left the legacy HP queue reporting **“The printer software is not compatible with this device”** and **“Filter failed”**. It provides a separate native CUPS printing path for this specific printer. Those messages can have other causes; this is not a general fix for every HP printer.

**[Download the installer](https://github.com/ochodek/hp-laserjet-p1102-macos/releases/latest)** | [Installation](#installation) | [Compatibility](#compatibility-and-validation) | [Report a problem](https://github.com/ochodek/hp-laserjet-p1102-macos/issues)

## Version 1.7.1

Version 1.7.1 improves handling of incomplete raster input, USB/XML responses and source packaging, and adds an application icon. Physical print results below describe version 1.7; version 1.7.1 has automated validation.

Native toner/status utility, paper and quality options, quiet/power settings, PDF booklets, watermarks and manual duplex. See the [feature comparison](FEATURES.md) and [review findings](REVIEW.md) for verified behavior and limits. The installer includes English/Czech guidance, GPL licence, upgrade checks and an explicit uninstaller.

## Installation

1. Open [Releases](https://github.com/ochodek/hp-laserjet-p1102-macos/releases/latest) and download `HP-P1102-Native-1.7.1.pkg`. No compilation is needed.
2. Connect the powered-on P1102 by USB, directly or through a working adapter. Load A4 paper.
3. Open the package and complete installation. macOS requires administrator authorization.
4. Select **HP LaserJet P1102 Native** in the application's print dialog. Set it as your default in **System Settings, Printers & Scanners** if desired.
5. Print one page to check your printer's output.

Quit P1102 Utility and finish pending jobs before updating. The installer creates its own queue when it finds exactly one connected P1102. If the printer was disconnected during installation, add it in **Printers & Scanners**, choose **Use: Select Software**, and select **HP LaserJet P1102 Native ARM64, 1.7.1**. Re-running the installer with the printer connected is another option. Updates refresh this driver's PPD while retaining existing quality choices. A queue-name conflict with another printer stops installation; with multiple P1102 devices, choose the intended one manually. The original HP queue and default printer selection are preserved.

### macOS security prompts

The package is **not Developer ID signed or notarized**. The executable has an ad-hoc code signature, which does not certify its publisher or establish that it is malware-free. Review the source and [security notes](SECURITY.md) before installing.

If macOS blocks installation and you trust the downloaded package, Apple documents the **Privacy & Security, Open Anyway** exception. Do not disable Gatekeeper or SIP. See [Apple's instructions](https://support.apple.com/en-ie/102445).

Each release includes a source archive and `SHA256SUMS`. Place the installer, source archive, and checksum file in the same folder to check their integrity:

```sh
shasum -a 256 -c SHA256SUMS
```

Checksums detect changed downloads; they do not replace verifying the publisher.

## Compatibility and validation

| Component | Status |
| --- | --- |
| HP LaserJet Professional P1102 via USB | Physically tested on one printer |
| Apple Silicon, ARM64 | Native; no Rosetta dependency |
| macOS 27.0.1 | Local installation and printing tested |
| macOS 11 or newer | Build target; other releases have not been physically validated |
| macOS 28 | Untested; future compatibility is not guaranteed |
| Intel Macs, P1102w, other HP models, Wi-Fi/AirPrint | Not validated or supported by this package |

Supported output includes FastRes 600/1200, media and density choices, multiple pages and copies, and manual duplex through P1102 Utility. A4, FastRes 600, EconoMode off and density 3 are the defaults. Toner is available in the utility and macOS Supply Levels. See [all features](FEATURES.md). There is no automatic duplex hardware, updater or firmware modification.

The driver still depends on macOS providing CUPS filters, PPD support, the rasterizer, and the USB backend. Removing its Rosetta dependency does not make it independent of future macOS printing changes.

Gray gradients were visually compared with HP driver 6.9 and accepted as matching. Digital tests compare all 256 tones and a complete separate reference image. Physical 1.7 tests confirmed long-edge duplex, a watermarked booklet, FastRes 1200, toner reporting and internal configuration/demo/cleaning pages. EconoMode with density 1 lost the lightest nonwhite gray field; use it for drafts, not faint graphics or fine detail. The normal mode retained all nine nonwhite fields and all six test lines.

Page placement is calibrated to the average of three A4 prints from one printer. Identical data produced measured center-position ranges of **0.81 mm horizontally and 0.63 mm vertically**. A fixed software correction cannot eliminate variation between sheets or measurement uncertainty. The printable area is intentionally conservative, and margins on another printer may differ.

## Troubleshooting

* **Still seeing “Filter failed” or the compatibility warning?** Select **HP LaserJet P1102 Native**, not the old HP queue. Check that its model shows the native ARM64 driver.
* **Printer missing or offline?** Check power, USB cable and adapter, and any macOS accessory-approval prompt. The driver cannot fix an absent USB connection.
* **Paper error?** Load the tray and clear any paper obstruction before resuming the job.
* **Unexpected placement?** Compare several identical pages before adjusting margins; single-sheet differences can come from paper registration or measurement.

[Open an issue](https://github.com/ochodek/hp-laserjet-p1102-macos/issues) with the exact printer model, macOS version, Mac chip, driver version, connection type, and error. Redact printer serial numbers, usernames, document names, and document contents from logs or photos.

## Build and test

Requires an Apple Silicon Mac, Xcode Command Line Tools, and Python 3. Vendored dependencies are included and checked against SHA-256; the build does not download them.

```sh
git clone https://github.com/ochodek/hp-laserjet-p1102-macos.git
cd hp-laserjet-p1102-macos
./test.sh
./tests/sanitize.sh
./package.sh
```

`./build.sh` builds the filter, command helper, CLI and utility. `./package.sh` runs tests and produces the installer, source archive and checksums in `dist/`. Raster/protocol, device/PDF and installation/removal suites cover image content, copies, tones, geometry and malformed input. The source archive supports this workflow without `.git`; `SOURCE_MANIFEST` defines its inventory. See [SECURITY.md](SECURITY.md) for sanitizer and analyzer checks.

macOS rasterizes the document; `src/rastertop1102.c` validates the raster and maps grayscale into four exposure levels. Unmodified **foo2zjs/JBIG-KIT** code encodes ZjStream, and the system USB backend sends it to the printer. The installed filter links only to system `libcups` and `libSystem`. See the [tone measurement method (Czech)](tests/TONE_REFERENCE.md) and [upstream provenance](vendor/UPSTREAM.txt).

## Uninstall

Quit P1102 Utility and let pending jobs finish. In Finder, choose **Go, Go to Folder** and open `/Library/Printers/P1102Native`. Open `Uninstall.command`, type `REMOVE` when prompted and authorize locally. Alternatively, run `sudo ./uninstall.sh` from the matching source directory. The uninstaller refuses pending native jobs and a queue reassigned to another printer.

This removes the native queue and its driver files and utility only. If it was your default printer, select another one afterward. The original HP software and Rosetta are retained.

## License and credits

[GPL-2.0-or-later](LICENSE). Includes foo2zjs and JBIG-KIT work by Rick Richardson, Robert Szalai, Markus Kuhn, and other contributors. Original notices and the pinned source revision are preserved in `vendor/`.

This is a community project, not an HP or Apple product. No proprietary HP driver executable or printer firmware is distributed. See [release history](CHANGELOG.md).

See [NOTICE](NOTICE) for attribution and distribution notices. Matching complete source is included with the installer and available alongside each release. The software is provided without warranty to the extent permitted by law; recipients retain their rights under the GPL.