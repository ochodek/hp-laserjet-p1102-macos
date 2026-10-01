# Bezpečnost

[English](SECURITY.md) | **Česky**

Kontrola provedena 1. října 2026. Jde o vibe-coded projekt vyvíjený s pomocí AI.

Kontrola nenalezla záměrně škodlivé chování. Není to nezávislý bezpečnostní audit ani záruka nepřítomnosti všech chyb.

## Omezení rozsahu

Instalovaný program obsahuje CUPS adaptér, ZjStream enkodér a JBIG enkodér. Dynamicky se váže pouze na systémové `libcups.2.dylib` a `libSystem.B.dylib`. Nemá síťový klient, telemetrii, aktualizátor, shellové příkazy, stahování, přístup ke klíčence ani službu na pozadí. Neinstaluje kernel extension. USB přenos zajišťuje macOS.

Linker odstranil nepoužívané CLI, barevné vstupní parséry a JBIG dekodér. Ve výsledném programu nejsou symboly pro spouštění procesů, sockety, připojení k síti ani JBIG dekódování. Volba souboru na vstupu pochází z rozhraní CUPS; program nevytváří vlastní dočasné soubory. Názvy úloh ani uživatelů se nevkládají do tiskového protokolu.

Filtr nemá setuid bit. Instaluje se jako root:wheel s právy 0755, aby jej běžný uživatel nemohl přepsat. Ochrany CUPS, Gatekeeperu a SIP se nemění. Instalační skript hledá připojenou USB P1102 a založí její novou frontu. Při aktualizaci obnoví PPD a rozlišení pouze vlastní fronty HP_LaserJet_P1102_Native. Původní frontu HP ani výchozí tiskárnu nepřepisuje. URI předává jako citovaný argument, nikdy jej nevyhodnocuje jako příkaz.

## Provedené kontroly

* Vlastní C kód se překládá s `-Wall -Wextra -Werror`; jeho kontrola pomocí Clang Static Analyzer neohlásila nález.
* Ověřen ARM64 strojový kód a platnost jeho ad-hoc podpisu.
* Zdrojové závislosti mají zaznamenaný původ, revizi a SHA-256.
* Testy rozbalují skutečná výstupní JBIG data a porovnávají všechny pixely dvou stránek: souřadnice po přesném posunu o 15 sloupců a 31 řádků, zachování posledního řádku, bílé doplnění všech čtyř stran obrazu při zachování přenášených rozměrů A4 z verze 1.4, polaritu, pořadí a počet kopií. Pokrývají 1bitové i 8bitové bílé/černé barevné prostory. U všech 256 šedých ploch se přesně porovnávají počty čtyř úrovní tiskového bodu s měřením referenčního ovladače HP. Další test po oddělení bílého kalibračního okraje porovnává celý dekódovaný obraz s referenčním výstupem HP na proměnlivých odstínech a tenkých čarách, které nebyly použity ke kalibraci. Jde o kontrolu dat; fyzický výtisk je nutné posoudit samostatně.
* Desetinné okraje z CUPS Raster v2 musí zachovat všechny čtyři rohy obrazu a bílé doplnění. Nečíselné, nekonečné, obrácené a mimostránkové souřadnice se odmítají ještě před kódováním stránky.
* Prázdné a zkrácené vstupy musí skončit chybou. Extrémní hodnoty v 17 polích hlavičky musí být odmítnuty bez pádu (celkem 34 mutací).
* Stejné testy prošly i pod AddressSanitizerem a UndefinedBehaviorSanitizerem. Kontrola úniků paměti je v tomto běhu vypnutá.
* Celý lokální převod Apple rasterizer + nový filtr prošel a dvě požadované kopie vytvořily právě dvě stránky.

## Nálezy v převzatém kódu a hranice kontroly

Samostatná statická analýza celého `jbig.c` hlásí 13 kandidátů: nepoužitá přiřazení, obecný případ nulového počtu prvků v alokátoru, analýzu indexované inicializace a problémy v dekódovacích větvích. Dekodér není do instalovaného filtru zahrnut. Enkodér dostává výhradně kladné rozměry z povolených formátů, jednu obrazovou rovinu, pevnou velikost pásu 128 a pevné pořadí komprese. Nulové rozměry a neplatné hlavičky filtr odmítá před voláním enkodéru. Indexová tabulka pro používané pořadí inicializuje všechny tři prvky smyčky. Tyto kandidáty se v používané cestě nepodařilo reprodukovat; nejsou zde prezentovány jako automaticky vyřešené chyby celé knihovny.

Při překladu testovací varianty kompilátor upozorňuje na historická volání `sprintf` v nepoužívaných barevných větvích foo2zjs. Tyto větve a volání nejsou ve výsledném instalovaném programu. Převzaté zdroje zůstávají nezměněné, aby se daly porovnat s uvedenou revizí.

Testy nepokrývají všechny možné obrázky a úlohy. Funkčnost a bezpečnost systémových knihoven macOS jsou závislostí tohoto ovladače. Instalační balíček není podepsaný Developer ID certifikátem a není notarizovaný; kontrolní součet slouží ke kontrole integrity přeneseného souboru, ne jako náhrada nezávislého potvrzení identity autora.
