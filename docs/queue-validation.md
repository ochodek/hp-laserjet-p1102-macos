# Localized macOS upgrade/removal fix, 1.7.2

## Cause and impact

Version 1.7.1's `scripts/check-queue` and `uninstall.sh` compared the entire
human-readable `lpstat -v` line with an English prefix. On the Czech macOS
27.0.1 used for validation, `LC_ALL=C LANG=C /usr/bin/lpstat -v
HP_LaserJet_P1102_Native` still emitted `zařízení pro …`, not `device for …`.
The correct USB P1102 was therefore reported as a queue-name conflict.
The package stopped in preinstall, before replacing the payload. Removal had
the same false rejection. The previous hook tests only mocked English text.

The actual 1.7.1 installation was completed by backing up and recreating its
idle native queue, retaining the URI, default-printer choice, A4 and 600 dpi.
The user subsequently confirmed one correct test page. That workaround is
not required by the new implementation and is not part of the installer.

## Implementation and safety decisions

`p1102-queue-check` is a small ARM64, read-only libcups client. It sends
Get-Printer-Attributes for exactly `HP_LaserJet_P1102_Native` and checks
typed, single-valued `printer-name`, `device-uri` and `printer-type` attributes.
It requires the exact supported USB model prefix and rejects a printer class,
different queue/model, missing metadata, duplicate/mistyped attributes and
unescaped control/space characters.

A review regression also verifies that job attributes in an operation/printer
group are rejected rather than interpreted as an idle queue.

Only the explicit IPP not-found status means `absent`. Connection, policy,
authentication, malformed-response and substituted-attribute errors stop the
operation. An existing owned queue must also have no incomplete jobs: Get-Jobs
requests all users' `not-completed` jobs with a limit of one and no document
metadata. Held/stopped jobs therefore also block replacement/removal.

The helper connects to macOS's `/private/var/run/cupsd` domain socket, with
bounded connection/read timeouts. It does not need a TCP listener, USB access,
Rosetta, Python or downloaded dependencies. `CUPS_SERVER`, `IPP_PORT` and
`CUPS_USER` cannot redirect its query; the requesting user comes from the
effective OS UID. Administrative/discovery commands use the same explicit
socket with `-h`, so the guard and mutations address the same scheduler.

The component's Scripts archive includes the freshly built helper. Preinstall
can therefore validate an older installation that has no helper yet. Postinstall
checks again before choosing update versus creation, and after potentially slow
USB discovery before any creation. A newly appeared owned queue is updated
without rebinding; a new conflict, pending job or service error stops the hook.
An update only refreshes
the PPD; it does not delete/recreate the queue, override existing quality
options or change the default printer. The installed uninstaller runs the
same helper and removes it among its explicitly named owned files.

The guard performs no configuration or deletion itself. It reports only
`present`/`absent` on successful stdout and generic errors on stderr, without
device URIs, printer serials or job titles. Unexpected shell-protocol results
also stop the hooks before mutations.

Building in the user's iCloud Documents folder also exposed FinderInfo being
attached to generated app bundles. The build assembles and signs the application
in a private system temporary directory, then copies the result without HFS
metadata/resource forks, xattrs, ACLs or quarantine metadata (`ditto --norsrc
--noextattr --noacl --noqtn`). The application's icon is an ordinary bundled
resource and remains included.
Packaging also stages the payload outside file-provider folders, so newly added
Finder metadata does not enter the package. Package checks
verify the complete app signature as well as the helper signatures.

The structured interfaces and local-socket transport are documented in the
[CUPS programming manual](https://openprinting.github.io/cups/doc/cupspm.html).
Apple's [Get-Printer-Attributes implementation](https://github.com/apple/cups/blob/master/scheduler/ipp.c)
uses [destination lookup](https://github.com/apple/cups/blob/master/scheduler/printers.c)
for both printers and classes; the returned type is checked explicitly.

## Validation

* `tests/queue_tests.c`: genuine in-memory IPP responses exercise queue identity,
  locales, absence, classes, malformed attributes, errors and incomplete jobs.
* `tests/test_queue_transport.py`: the compiled production client and real
  libcups talk to an isolated Unix-socket HTTP/IPP server. Tests inspect the
  exact read-only operations, all-user job selection, locale independence,
  scheduler failures and resistance to inherited CUPS settings.
* Installer/removal tests mock every mutation and verify that conflicts,
  pending jobs, missing helpers, unexpected output and service errors do not
  reconfigure queues or remove files. Existing hardware, symlink, application
  ownership, unique-device discovery and cancellation checks remain covered.
* Package checks compare the exact helper bytes/signature/mode in both the
  payload and component Scripts, and include all corresponding source/tests.
* `./package.sh` runs the full suite and builds/checks the candidate package;
  `./tests/sanitize.sh` adds ASan/UBSan validation.

On the Czech macOS 27.0.1 validation host, 39 native queue/job checks, six
real-libcups transport test methods, twelve installer methods and seven
removal methods passed. The existing seventeen raster methods, device and
PDF contracts, and three source/icon methods also passed. The queue parser,
raster, device and PDF suites passed ASan/UBSan with leak detection disabled;
the new production source passed Clang Static Analyzer without diagnostics.
The candidate package passed its expanded payload/source/signature checks.

The packaged helper returned `present` for the actual idle native queue.
Packaged preinstall, postinstall and removal scripts then passed using actual
read-only CUPS/OS metadata with every mutating command replaced by a logger.
The postinstall logger received only a PPD update; the removal logger received
only the exact native queue and named project files. Installed PPD/filter
hashes and default-printer output were unchanged before and after. This is
an integration check, not an actual privileged installation or removal.

`pkgbuild` still emitted four `write: Permission denied` diagnostics while
returning success. The same OS-tool behavior was already recorded for a
minimal text-only package in [the prior review](../REVIEW.md). Its underlying
cause remains unresolved; successful archive/byte/signature checks do not
justify describing the build as free of warnings.

This is internal implementation/review work by the same coding agent, not an
independent audit or a claim that a separate team reviewed the code.

## Coverage limits

A real installation of 1.7.2, a physical print with this version, and a
destructive uninstall have not been performed in this review. Automated
contracts and read-only live integration do not replace those checks.
Validation on a disposable macOS installation should include upgrading an
existing native queue with non-default quality options and a default printer,
printing one page, then removal. Older macOS versions remain untested. The
second Mac report establishes the 1.7.1 locale failure, not a completed 1.7.2
installation test.

The checks are snapshots, not an atomic transaction with CUPS administration.
Another administrator or a newly submitted job can race the last check.
Finish jobs, close the utility and avoid concurrent queue administration during
installation/removal. A custom scheduler socket location is intentionally not
accepted; this package targets the standard macOS printing service.

## Česky

Příčinou byl překlad výpisu `lpstat`: původní kontrola vyžadovala anglickou větu,
ale český macOS vracel českou i při `LC_ALL=C LANG=C`. Správná tiskárna proto
vypadala jako cizí fronta. Stejná chyba byla v odinstalaci a anglické testovací
vstupy ji nezachytily.

Nový společný nástroj čte přímo strukturované údaje CUPS. Rozlišuje chybějící
frontu, správnou nečinnou P1102, cizí tiskárnu/skupinu, čekající úlohy a chybu
služby. Při neúplných nebo neověřitelných datech změny zastaví. Instalace
aktualizuje PPD existující fronty bez rušení a obnovení nastavení; odinstalace
ověří stejnou identitu a odstraní pouze vyjmenované soubory tohoto projektu.

Vydání 1.7.2 ověřují testy se skutečnou knihovnou CUPS, izolovaným IPP serverem
a simulacemi systémových změn. Dodatečná kontrola opravila i chybnou odpověď,
která obsahuje údaje o úloze v nesprávné skupině IPP; ta nyní změny zastaví.
Fyzický tisk, skutečná instalace 1.7.2 a úplná odinstalace v této kontrole
neproběhly. Zpráva z druhého Macu dokládá problém verze 1.7.1, nikoli úspěšnou
instalaci 1.7.2. Kontrola není atomická vůči jinému správci nebo novým úlohám.
