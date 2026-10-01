# P1102 Native: ovladač pro HP LaserJet P1102 na macOS

[English](README.md) | **Česky**

Nezávislý otevřený USB ovladač pro **HP LaserJet Professional P1102** a **Macy s Apple Silicon (M1 a novější)**. Tiskový filtr běží nativně jako ARM64. K tisku nepotřebuje Rosettu, původní software HP, Homebrew ani připojení k internetu.

**Jde o vibe-coded projekt:** vznikal postupně s pomocí AI asistenta, automatických kontrol a skutečných zkušebních výtisků. Je to komunitní experiment, nikoli nezávisle auditovaný nebo výrobcem certifikovaný ovladač. Co se skutečně ověřilo, popisují [rozsah ověření](#kompatibilita-a-ověření) a [bezpečnostní poznámky](SECURITY.cs.md).

Projekt vznikl po aktualizaci macOS, kdy původní tisková fronta HP hlásila **„The printer software is not compatible with this device“** a **„Filter failed“**. Nabízí samostatnou nativní cestu tisku přes CUPS pro tento konkrétní model. Stejná hlášení mohou mít i jiné příčiny; nejde o univerzální opravu všech tiskáren HP.

**[Stáhnout instalátor](https://github.com/ochodek/hp-laserjet-p1102-macos/releases/latest)** | [Instalace](#instalace) | [Kompatibilita](#kompatibilita-a-ověření) | [Nahlásit problém](https://github.com/ochodek/hp-laserjet-p1102-macos/issues)

## Verze 1.7.2

Verze 1.7.2 opravuje aktualizaci a odinstalaci na lokalizovaném macOS pomocí strukturovaných údajů CUPS a bezpečně zastaví změny při čekajících nativních úlohách nebo neověřitelné tiskové službě. Podrobnosti uvádí [vysvětlení a ověření opravy](docs/queue-validation.md#česky). Rastrový filtr a tiskový protokol se nemění. Fyzické postupy níže popisují verzi 1.7; uživatel navíc potvrdil jednu správně vytištěnou stránku s nainstalovanou verzí 1.7.1.

Nativní nástroj pro toner a stav tiskárny, volby papíru a kvality, tichý režim, časovače a PDF nástroje pro brožury, vodoznaky a ruční duplex. [Přehled funkcí](FEATURES.cs.md) a [zpráva z kontroly kódu](REVIEW.md) uvádějí ověřené chování i jeho meze. Instalátor obsahuje české a anglické pokyny, licenci GPL, kontroly aktualizace a odinstalaci.

## Instalace

1. V části [Releases](https://github.com/ochodek/hp-laserjet-p1102-macos/releases/latest) stáhněte `HP-P1102-Native-1.7.2.pkg`. Nic nemusíte kompilovat.
2. Připojte zapnutou P1102 přes USB, případně funkční USB adaptér. Vložte papír A4.
3. Otevřete balíček a dokončete instalaci. macOS vyžádá oprávnění správce.
4. V tiskovém dialogu vyberte **HP LaserJet P1102 Native**. Pokud chcete, nastavte ji jako výchozí v **Nastavení systému, Tiskárny a skenery**.
5. Ověřte výsledek tiskem jedné stránky.

Před aktualizací ukončete P1102 Utility a dokončete čekající úlohy. Instalátor vytvoří vlastní frontu, pokud najde právě jednu připojenou P1102. Jestliže byla při instalaci odpojená, přidejte ji v **Tiskárnách a skenerech**, v nabídce **Použít: Vybrat software** zvolte **HP LaserJet P1102 Native ARM64** s verzí nainstalovaného balíčku. Případně znovu spusťte instalátor s připojenou tiskárnou. Aktualizace obnoví PPD tohoto ovladače a zachová zvolené nastavení kvality. Pokud název fronty patří jiné tiskárně, čekají v ní úlohy nebo nelze ověřit místní CUPS, instalace se zastaví. Při více připojených P1102 vyberte zamýšlenou tiskárnu ručně. Původní fronta HP i volba výchozí tiskárny zůstávají zachované.

### Bezpečnostní upozornění macOS

Balíček **není podepsaný certifikátem Developer ID ani notarizovaný**. Nativní program má ad-hoc podpis, který nepotvrzuje totožnost vydavatele ani nepřítomnost škodlivého kódu. Před instalací si můžete prohlédnout zdroje a [popis bezpečnostní kontroly](SECURITY.cs.md).

Pokud macOS instalaci zablokuje a balíčku důvěřujete, Apple popisuje výjimku **Soukromí a zabezpečení, Přesto otevřít**. Nevypínejte Gatekeeper ani SIP. Viz [návod Apple](https://support.apple.com/en-ie/102445).

Každé vydání obsahuje zdrojový archiv a soubor `SHA256SUMS`. Stažený instalátor, zdrojový archiv a kontrolní součty umístěte do stejné složky a ověřte jejich integritu:

```sh
shasum -a 256 -c SHA256SUMS
```

Kontrolní součty odhalí změněné soubory; nenahrazují ověření totožnosti vydavatele.

## Kompatibilita a ověření

| Součást | Stav |
| --- | --- |
| HP LaserJet Professional P1102 přes USB | Fyzicky ověřeno na jednom kusu |
| Apple Silicon, ARM64 | Nativní běh bez Rosetty |
| macOS 27.0.1 | Ověřena místní instalace a tisk |
| macOS 11 a novější | Cíl sestavení; ostatní verze nebyly fyzicky ověřeny |
| macOS 28 | Neověřeno; budoucí kompatibilita není zaručená |
| Intel Macy, P1102w, jiné modely HP, Wi-Fi/AirPrint | Tento balíček je neověřuje ani nepodporuje |

Podporovaný výstup zahrnuje FastRes 600/1200, volby médií a sytosti, více stránek a kopie i ruční duplex prostřednictvím P1102 Utility. Výchozí nastavení je A4, FastRes 600, vypnutý EconoMode a sytost 3. Stav toneru je dostupný v aplikaci i v Nastavení systému. Viz [všechny funkce](FEATURES.cs.md). Tiskárna nemá automatický duplex; software neobsahuje automatický aktualizátor ani úpravy firmwaru.

Ovladač stále závisí na podpoře filtrů CUPS, PPD, vykreslování rastru a USB backendu v macOS. Odstranění závislosti na Rosettě samo o sobě nezaručuje funkčnost po budoucích změnách tiskového systému macOS.

Šedé přechody byly vizuálně porovnány s ovladačem HP 6.9 a potvrzeny jako shodné. Datové testy porovnávají všech 256 odstínů a celý samostatný referenční obraz. Fyzické zkoušky 1.7 potvrdily ruční duplex s otáčením jako kniha, brožuru s vodoznakem, FastRes 1200, údaj o toneru i konfigurační, ukázkovou a čisticí stránku. Při EconoMode se sytostí 1 zmizelo nejsvětlejší ne bílé pole; tento režim používejte pro koncepty, nikoli jemnou grafiku. Běžný režim zachoval všech devět ne bílých polí a všech šest zkušebních čar.

Poloha obrazu je kalibrovaná podle průměru tří stejných výtisků A4 na jedné tiskárně. Naměřená poloha středu se mezi listy lišila až o **0,81 mm vodorovně a 0,63 mm svisle**. Pevná softwarová korekce neodstraní kolísání mezi listy ani nejistotu měření. Tisknutelná plocha má záměrně větší rezervu; na jiném kusu tiskárny mohou být okraje odlišné.

## Řešení problémů

* **Stále se zobrazuje „Filter failed“ nebo hlášení o nekompatibilitě?** Vyberte **HP LaserJet P1102 Native**, nikoli původní frontu HP. V modelu fronty má být uveden nativní ovladač ARM64.
* **Tiskárna chybí nebo je offline?** Zkontrolujte napájení, USB kabel, adaptér a případnou žádost macOS o povolení příslušenství. Ovladač neopraví chybějící USB spojení.
* **Chyba papíru?** Doplňte zásobník a před pokračováním zkontrolujte průchod papíru.
* **Nesouměrné okraje?** Porovnejte několik stejných stránek. Rozdíly jednotlivých listů mohou souviset s podáváním papíru nebo měřením.

Pro pomoc [založte issue](https://github.com/ochodek/hp-laserjet-p1102-macos/issues) s přesným modelem tiskárny, verzí macOS, čipem Macu, verzí ovladače, typem připojení a chybovým hlášením. Z logů a fotografií odstraňte sériová čísla tiskárny, uživatelská jména, názvy a obsah soukromých dokumentů.

## Sestavení a testy

Vyžaduje Apple Silicon Mac, Xcode Command Line Tools a Python 3. Zdrojové závislosti jsou přiložené a ověřují se pomocí SHA-256; při sestavení se nestahují.

```sh
git clone https://github.com/ochodek/hp-laserjet-p1102-macos.git
cd hp-laserjet-p1102-macos
./test.sh
./tests/sanitize.sh
./package.sh
```

`./build.sh` sestaví filtr, příkazový nástroj, CLI a obslužnou aplikaci. `./package.sh` spustí testy a vytvoří instalátor, zdrojový archiv a kontrolní součty v `dist/`. Rastrové/protokolové testy a sady USB/XML, PDF a instalace/odinstalace ověřují obraz, kopie, odstíny, geometrii a neplatné vstupy. Archiv lze stejně sestavit bez `.git`; inventář určuje `SOURCE_MANIFEST`. Kontroly paměti a analýzu popisuje [SECURITY.cs.md](SECURITY.cs.md).

macOS vykreslí dokument do rastru; `src/rastertop1102.c` ověří jeho parametry a převede odstíny na čtyři úrovně tiskového bodu. Nezměněný kód **foo2zjs/JBIG-KIT** vytvoří ZjStream a systémový USB backend jej odešle do tiskárny. Instalovaný filtr se váže pouze na systémové `libcups` a `libSystem`. Viz [metoda měření odstínů](tests/TONE_REFERENCE.md) a [původ závislostí](vendor/UPSTREAM.txt).

## Odinstalace

Ukončete P1102 Utility a nechte dokončit čekající úlohy. Ve Finderu zvolte **Otevřít, Otevřít složku** a zadejte `/Library/Printers/P1102Native`. Otevřete `Uninstall.command`, po výzvě napište `REMOVE` a potvrďte oprávnění přímo na Macu. Případně spusťte `sudo ./uninstall.sh` z odpovídajících zdrojů. Odinstalace odmítne pokračovat při čekajících nativních úlohách nebo pokud fronta mezitím patří jiné tiskárně.

Skript odstraní pouze nativní frontu, její soubory a obslužnou aplikaci. Pokud byla výchozí, následně vyberte jinou tiskárnu. Původní software HP a Rosetta zůstávají zachované.

## Licence a poděkování

[GPL-2.0-or-later](LICENSE). Projekt používá práci Ricka Richardsona, Roberta Szalaie, Markuse Kuhna a dalších přispěvatelů foo2zjs a JBIG-KIT. Původní licenční upozornění a konkrétní revize zdrojů jsou zachované ve složce `vendor/`.

Jde o komunitní projekt, nikoli produkt HP nebo Apple. Neobsahuje proprietární program ovladače HP ani firmware tiskárny. Viz [přehled vydání](CHANGELOG.md).

Autory a distribuční oznámení uvádí [NOTICE](NOTICE). Kompletní odpovídající zdroje jsou součástí instalátoru i samostatně u vydání. Software je poskytován bez záruky v rozsahu přípustném právem; příjemcům zůstávají práva podle GPL.
