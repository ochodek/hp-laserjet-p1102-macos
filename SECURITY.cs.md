# Bezpečnost, kandidát 1.7

[English](SECURITY.md) | **Česky**

Jde o vibe-coded projekt vyvíjený s pomocí AI. Interní kontrola kódu a bezpečnosti proběhla 1. října 2026. Nálezy, opravy, důkazy a zbývající podmínky vydání jsou v [REVIEW.md](REVIEW.md). Nejde o nezávislý audit ani záruku nalezení všech chyb.

## Běh a oprávnění

Nativní rastrový filtr kontroluje černobílý vstup CUPS a používá připnutou verzi kodéru foo2zjs/JBIG. Odkazuje na systémové libcups a libSystem. Nový příkazový filtr a CLI používají Foundation a IOKit, obslužná aplikace navíc Cocoa, PDFKit a PrintCore. Všechny dodávané programy jsou ARM64.

Běhový kód neobsahuje síťového klienta, telemetrii, aktualizátor, spouštění shellu, stahování, přístup k heslům či klíčence, trvalou službu, rozšíření jádra, změnu firmwaru ani tovární reset. Zprávy HTTP jsou přenášeny po USB. Aplikace otevírá dvě rozhraní konkrétního modelu běžným způsobem, bez vynuceného převzetí nebo resetu. Příkazy a hodnoty nastavení pocházejí z pevných seznamů. Uživatelská jména ani názvy dokumentů se nevkládají do příkazů tiskárně.

Instalátor potřebuje správce kvůli souborům ovladače, aplikaci a vlastní frontě CUPS. Programy mají práva 0755, bez setuid. Původní fronta HP i výchozí tiskárna zůstávají zachované. Aplikace běží pod přihlášeným uživatelem a při běžném použití správce nepotřebuje. Tiskové soubory spravuje macOS. Odinstalační skript odstraňuje pouze známé soubory a kontroluje identitu balíčku aplikace.

Balík obsahuje rastrový filtr, `commandtop1102`, `p1102ctl`, licenci a úplný zdrojový archiv v `/Library/Printers/P1102Native`, PPD v `/Library/Printers/PPDs/Contents/Resources` a `/Applications/P1102 Utility.app`. Nepřidává trvale spouštěnou službu. Oprávnění pro automatizaci rozhraní použité při vývoji není požadavkem ovladače.

## Vstupy a soukromí

* Rastr prochází kontrolou geometrie, rozměrů, bitové hloubky, formátu, typu a zdroje papíru, kvality, kopií a rozsahů voleb. Paměť stránky je omezená podporovanými fyzickými rozměry. Neúplná stránka končí chybou.
* Přenosy USB mají časové limity. Při chybě čtení se nepoužije nevyplněná paměť. HTTP má limit celé zprávy 512 KiB a hlavičky 8 KiB, s kontrolou délek a bloků. Neznámá nebo duplicitní hodnota toneru se nevydává za procenta.
* XML musí být UTF-8. Deklarace DTD a entit jsou odmítány, načítání externích entit je vypnuto. Kontroluje se hloubka, počet uzlů a délky textů. Aktuální a předchozí kazeta mají oddělené cesty k údajům.
* PDF vybírá uživatel; dokument musí být odemčený a mít povolený tisk. Platí limity velikosti, počtu stran a výstupu. Příprava nepřepisuje originál. Export vyžaduje ukládací dialog, tisk používá systémovou frontu. Interní implementace PDFKit a macOS není součástí tohoto auditu.
* Grafický export diagnostiky používá vybraná pole a vynechává sériová čísla, uživatelská jména, cesty a obsah dokumentů. CLI naopak vypisuje identitu tiskárny, před sdílením ji odstraň. Vývojové USB záznamy, tiskové soubory a fotografie jsou vynechány z Gitu i zdrojového balíčku.

## Ověření a omezení

Vlastní zdrojové soubory procházejí přísnými varováními kompilátoru a Clang Static Analyzerem. Testy rastru, protokolu, HTTP/XML a PDF běží i s AddressSanitizerem a UndefinedBehaviorSanitizerem; kontrola úniků paměti je při tomto běhu vypnuta. Skutečné výsledky i rozdíl mezi přímým USB testem, integrací fronty a fyzickým tiskem uvádí REVIEW.md.

Připnuté zdroje závislostí a jejich kontrolní součty zůstávají stejné. Linker odstraňuje nepoužívané CLI, barevné parsery a dekodér JBIG. Starší analýza celého `jbig.c` ohlásila 13 kandidátů v oblastech nepoužitých přiřazení, nulových alokací, inicializace a dekodéru. Použitý kodér dostává ověřené kladné rozměry, jednu rovinu a pevná nastavení JBIG; příslušná inicializace plní všechny položky. Nálezy se v použité cestě nepodařilo reprodukovat. Historická varování `sprintf` patří do nepoužitých barevných větví, které ve výsledném filtru nejsou. Neznamená to, že celá knihovna nemá žádné chyby.

Balíček **nemá podpis Developer ID ani notarizaci**. Ad-hoc podpis nepotvrzuje vydavatele. SHA-256 ověřuje neporušenost souboru, nikoli nezávislou důvěryhodnost autora. Kvůli instalaci nevypínej Gatekeeper ani SIP. Budoucí kompatibilita závisí na podpoře CUPS/PPD, rasterizace, IOKit a USB v macOS. Každý druh papíru, chybový stav a verze systému nebyly fyzicky otestovány.
