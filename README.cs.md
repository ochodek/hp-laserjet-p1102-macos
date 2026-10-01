# P1102 Native: ovladač pro HP LaserJet P1102 na macOS

[English](README.md) | **Česky**

Nezávislý otevřený USB ovladač pro **HP LaserJet Professional P1102** a **Macy s Apple Silicon (M1 a novější)**. Tiskový filtr běží nativně jako ARM64. K tisku nepotřebuje Rosettu, původní software HP, Homebrew ani připojení k internetu.

**Jde o vibe-coded projekt:** vznikal postupně s pomocí AI asistenta, automatických kontrol a skutečných zkušebních výtisků. Je to komunitní experiment, nikoli nezávisle auditovaný nebo výrobcem certifikovaný ovladač. Co se skutečně ověřilo, popisují [rozsah ověření](#kompatibilita-a-ověření) a [bezpečnostní poznámky](SECURITY.cs.md).

Projekt vznikl po aktualizaci macOS, kdy původní tisková fronta HP hlásila **„The printer software is not compatible with this device“** a **„Filter failed“**. Nabízí samostatnou nativní cestu tisku přes CUPS pro tento konkrétní model. Stejná hlášení mohou mít i jiné příčiny; nejde o univerzální opravu všech tiskáren HP.

**[Stáhnout instalátor](https://github.com/ochodek/hp-laserjet-p1102-macos/releases/latest)** | [Instalace](#instalace) | [Kompatibilita](#kompatibilita-a-ověření) | [Nahlásit problém](https://github.com/ochodek/hp-laserjet-p1102-macos/issues)

## Vývojová verze 1.7

Tato větev přidává nativní nástroj pro toner a stav tiskárny, volby papíru a kvality, tichý režim, časovače a PDF nástroje pro brožury, vodoznaky a ruční duplex. Podrobnosti najdete v [přehledu funkcí](FEATURES.cs.md) a [zprávě z kontroly kódu](REVIEW.md). Jde o kandidáta k ověření, nikoli o plně prověřenou náhradu každého postupu HP. Publikovaná 1.6 zůstává stabilním základem popsaným níže. [Testovací vydání 1.7](https://github.com/ochodek/hp-laserjet-p1102-macos/releases/tag/v1.7-rc1) obsahuje `HP-P1102-Native-1.7.pkg`, odpovídající zdroje a kontrolní součty. Instalace má stejný postup jako níže; model tiskárny pak uvádí verzi 1.7.

## Instalace

1. V části [Releases](https://github.com/ochodek/hp-laserjet-p1102-macos/releases/latest) stáhněte `HP-P1102-Native-1.6.pkg`. Nic nemusíte kompilovat.
2. Připojte zapnutou P1102 přes USB, případně funkční USB adaptér. Vložte papír A4.
3. Otevřete balíček a dokončete instalaci. macOS vyžádá oprávnění správce.
4. V tiskovém dialogu vyberte **HP LaserJet P1102 Native**. Pokud chcete, nastavte ji jako výchozí v **Nastavení systému, Tiskárny a skenery**.
5. Ověřte výsledek tiskem jedné stránky.

Instalátor vytvoří vlastní frontu, pokud najde připojenou P1102. Jestliže byla při instalaci odpojená, přidejte ji v **Tiskárnách a skenerech**, v nabídce **Použít: Vybrat software** zvolte **HP LaserJet P1102 Native ARM64, 1.6**. Případně znovu spusťte instalátor s připojenou tiskárnou. Aktualizace obnoví pouze frontu tohoto ovladače a její rozlišení. Původní fronta HP i volba výchozí tiskárny zůstávají zachované.

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

Podporovaný výstup: černobílý jednostranný tisk, 600 × 600 dpi, A4/A5/A6/Letter/Legal, více stránek a kopie. Výchozí formát je A4. Ovladač neobsahuje sledování toneru, nástroje HP, automatický aktualizátor, duplex, stahování ani úpravy firmwaru.

Ovladač stále závisí na podpoře filtrů CUPS, PPD, vykreslování rastru a USB backendu v macOS. Odstranění závislosti na Rosettě samo o sobě nezaručuje funkčnost po budoucích změnách tiskového systému macOS.

Šedé přechody byly vizuálně porovnány s ovladačem HP 6.9 a potvrzeny jako shodné. Datové testy porovnávají všech 256 odstínů a celý samostatný referenční obraz. Verze 1.6 dokončila jednostránkovou úlohu přes nainstalovaný filtr; vzhled posledního listu zatím nebyl samostatně potvrzen uživatelem.

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

`./build.sh` v této větvi sestaví filtr, příkazový nástroj, CLI a obslužnou aplikaci. `./package.sh` spustí testy a vytvoří instalátor, zdrojový archiv a kontrolní součty ve složce `dist/`. Dvanáct rastrových/protokolových testů a sady pro USB/XML a PDF ověřují dekódovaný obraz, kopie, šedé odstíny, geometrii a neplatné vstupy. Místní kontroly paměti a analýzu adaptéru popisuje [SECURITY.cs.md](SECURITY.cs.md).

macOS vykreslí dokument do rastru; `src/rastertop1102.c` ověří jeho parametry a převede odstíny na čtyři úrovně tiskového bodu. Nezměněný kód **foo2zjs/JBIG-KIT** vytvoří ZjStream a systémový USB backend jej odešle do tiskárny. Instalovaný filtr se váže pouze na systémové `libcups` a `libSystem`. Viz [metoda měření odstínů](tests/TONE_REFERENCE.md) a [původ závislostí](vendor/UPSTREAM.txt).

## Odinstalace

Nechte dokončit čekající úlohy a ze zdrojového adresáře spusťte:

```sh
sudo ./uninstall.sh
```

Skript odstraní pouze nativní frontu a její soubory. Pokud byla výchozí, následně vyberte jinou tiskárnu. Původní software HP a Rosetta zůstávají zachované.

## Licence a poděkování

[GPL-2.0-or-later](LICENSE). Projekt používá práci Ricka Richardsona, Roberta Szalaie, Markuse Kuhna a dalších přispěvatelů foo2zjs a JBIG-KIT. Původní licenční upozornění a konkrétní revize zdrojů jsou zachované ve složce `vendor/`.

Jde o komunitní projekt, nikoli produkt HP nebo Apple. Neobsahuje proprietární program ovladače HP ani firmware tiskárny. Viz [přehled vydání](CHANGELOG.md).

Soupis licencí, dodání zdrojů, použití ochranných známek a meze kontroly najdete v [LEGAL.cs.md](LEGAL.cs.md). Autory a distribuční oznámení uvádí [NOTICE](NOTICE). Projekt nezaručuje vyloučení právních nároků.
