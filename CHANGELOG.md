# Changelog / Přehled vydání

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
