# Licence and publication review

[Česky](LEGAL.cs.md). Reviewed 1 October 2026 for the 1.7 candidate. This is a source and packaging compliance review by the project's AI coding agent, not a legal opinion or an independent rights clearance. It cannot guarantee that nobody will make a claim. The project is maintained as independent, publicly available community software.

## Distribution inventory

| Material | Origin and treatment |
| --- | --- |
| Native adapter, utility, USB/PDF code, scripts and PPD | Project code published under GPL-2.0-or-later; AI-assisted development disclosed. Project notices do not assert exclusive human authorship of AI output. |
| foo2zjs and bundled JBIG-KIT | Eight unchanged source/licence files from the pinned OpenPrinting revision; original notices retained, hashes checked on each build. See [provenance](vendor/UPSTREAM.txt) and [NOTICE](NOTICE). |
| P1102 job framing in `src/job.h` | Adaptation of foo2zjs framing under the same GPL, identified and dated in the file and NOTICE. |
| Tone tables and reference hashes | Measurements using project-authored test inputs and the locally installed HP driver; see [method](tests/TONE_REFERENCE.md). No HP executable or raw print capture is distributed. |
| Runtime dependencies | macOS-provided CUPS, libSystem, Foundation, IOKit, Cocoa, PDFKit and PrintCore. Their binaries, SDKs and headers are not redistributed. |
| Test material | Project-generated fixtures; no user document, photograph, HP manual, HP logo or printer firmware in the public source/payload. |

`zjs.h` has no separate per-file licence declaration and contains an upstream note about an older protocol header. It is distributed by OpenPrinting within the GPL foo2zjs source package. We preserve that note rather than assert that its historical chain of title has been independently established. That historical provenance, and rights in measured compatibility data, remain questions for qualified counsel if formal clearance is required.

## GPL delivery

Every installer carries the full licence, notices and the matching `Source.tar.gz`, including vendored source and build/install scripts. Releases also provide that archive beside the installer. The package test checks source completeness against the public project files and verifies payload contents. This follows the accompanying-source route in GPLv2 section 3(a), rather than relying on a promise to supply source later. Recipients may modify and redistribute under the GPL; no noncommercial-only restriction, NDA or extra EULA is imposed. See the [GPLv2 text](https://www.gnu.org/licenses/old-licenses/gpl-2.0.html).

Future releases must retain these materials, preserve third-party notices, identify changed upstream files and publish source corresponding to the actual binary. A GitHub link alone is not the project's source-delivery mechanism. The downloaded source archive of published 1.6 contains every file in its Git tag, including notices and build/install scripts; its immutable files are not silently replaced.

## HP compatibility and naming

The project name is **P1102 Native**. References to HP LaserJet identify the supported printer. Historical queue identifiers, filenames and repository URLs remain for upgrade compatibility and discoverability; they are not a claim to be an HP product. No HP or Apple logos or copied marketing artwork are used. README, installer and utility identify the independent project. HP's [trademark guidance](https://www.hp.com/us-en/terms-of-use.html) cautions against confusing origin or endorsement; that page does not give this project a trademark licence.

The implementation uses documented/open-source protocol information, printer responses and observed behaviour of a locally installed driver. EU Directive 2009/24/EC addresses observation/testing by a person entitled to use the program and, separately, conditional interoperability exceptions. This is relevant context, **not a finding that every possible use, copied element, licence agreement or jurisdiction is covered**. No circumvention, firmware extraction or proprietary binary redistribution is part of this project. See the [Directive](https://eur-lex.europa.eu/legal-content/EN/TXT/?uri=CELEX:32009L0024).

## Patents, warranty and unresolved legal scope

The JBIG-KIT author states that the last patents listed for JBIG1 expired in April 2012. This is useful evidence about that codec, not a search of all patents potentially relevant to printing, protocols or halftoning. No independent worldwide patent clearance has been performed. See [JBIG-KIT licensing and patent information](https://www.cl.cam.ac.uk/~mgk25/jbigkit/).

GPL warranty/liability terms apply only as permitted by applicable law. A disclaimer does not prevent litigation or waive mandatory rights. This review does not certify copyright ownership of every AI-generated passage, interpret the user's particular HP/Apple agreements, or assess a future commercial distribution model. If a formal legal assurance is required, an IP/software lawyer should review those points and the exact release. Do not market the driver as certified, legally risk-free, vendor-approved or compatible with untested future macOS releases.
