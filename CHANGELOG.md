# Changelog / Přehled vydání

## 1.7, 2026-10-01 (driver version 1.7)

Stable release following 1.7-rc1. Adds an English/Czech guided installer, upgrade and removal safeguards, cropped-PDF correctness, a hard serialized-PDF output limit and expanded package/installer tests. The final review corrected the economy-mode validation: EconoMode with density 1 can lose the lightest gray detail.

Stabilní vydání po 1.7-rc1 přidává český a anglický instalátor, ochrany při aktualizaci a odinstalaci, správný výřez PDF a limit celého výstupu. Úsporný režim se sytostí 1 může ztratit nejsvětlejší šedé detaily.

Native USB toner/status utility and CUPS ReportLevels; additional media, paper sizes, custom sizes, FastRes quality, EconoMode, density and jam recovery. Native power/quiet controls, internal-page commands, privacy-limited diagnostics, PDF watermark/booklet and manual duplex. Default print data retain 1.6 calibration. Physical validation and remaining coverage limits are tracked in [REVIEW.md](REVIEW.md).

The installed GUI passed physical manual-duplex and watermarked-booklet tests. Both quality/economy scheduler jobs completed after fixing CUPS boolean serialization; the user confirmed readable output, lighter economy printing and the internal supplies page showing 60% toner on 1 October 2026. Long utility instructions wrap, and macOS Supply Levels showed a fresh toner value. Licence notices, complete matching source, package checks accompany the installer.

Nativní nástroj doplňuje toner, nastavení tiskárny a PDF postupy. Uživatel fyzicky potvrdil ruční duplex a brožuru s vodoznakem. Opravené zalamování textu, volby CUPS a balení licencí prošly kontrolami; uživatel potvrdil i poslední zkoušky kvality, světlejší úsporný tisk a interní stránku se stavem toneru 60 %. Podrobnosti uvádí REVIEW.md.

## 1.6, 2026-10-01

First public release of this vibe-coded community project.

* Native ARM64 CUPS filter and USB installation package for HP LaserJet Professional P1102 on Apple Silicon.
* No Rosetta or original HP driver required at runtime. No firmware is distributed or changed.
* 600 dpi monochrome printing, A4/A5/A6/Letter/Legal, multiple pages and copies.
* Four exposure levels calibrated against measured HP 6.9 output. Page placement uses the mean of three physical A4 measurements; variation between sheets remains.
* Eight contract tests, sanitizer checks, source provenance, complete corresponding source archive and SHA-256 checksums.
* English and Czech documentation, installation instructions, security notes and limitations.

Physically tested on one P1102 with macOS 27.0.1. Other printers and macOS releases are not physically validated. The package is unsigned by Developer ID and not notarized. The public package refreshes documentation and packaging; the filter binary matches the locally installed 1.6 build.

První veřejné vydání komunitního projektu vytvořeného metodou vibe coding. Nabízí nativní ARM64 tisk přes USB bez Rosetty, instalační balíček, kompletní zdroje, testy a českou i anglickou dokumentaci. Fyzicky byl ověřen jeden kus P1102 na macOS 27.0.1; přesně stejné okraje na každém listu nejsou zaručené. Veřejný balíček aktualizuje dokumentaci a její zabalení, program filtru odpovídá místně nainstalované verzi 1.6.
