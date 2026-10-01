# Funkce a údaje tiskárny

[English](FEATURES.md)

Verze 1.7 je ve fázi ověřování. Jde o porovnání funkcí, nikoli certifikaci HP nebo příslib totožného chování u všech dokumentů. Cílem zůstává P1102 přes USB, nikoli P1102w či jiné modely.

## Tisk

| Funkce | Nativní řešení |
| --- | --- |
| FastRes 600 a FastRes 1200 | Tiskový dialog; oba režimy přijímají šedý rastr 600 dpi se čtyřmi úrovněmi expozice. Režim 1200 může tisknout pomaleji. |
| EconoMode | Úspora toneru příkazem tiskárně, pro jednotlivou úlohu |
| Sytost 1–5 | Tiskový dialog, výchozí hodnota 3 |
| Obnova po zaseknutí | Vypnuto nebo automatické opakování |
| Formáty | 18 pojmenovaných formátů včetně obálek a pohlednic; vlastní rozměry od 76,2 × 127 do 215,9 × 355,6 mm |
| Druhy papíru | 16 druhů: obyčejný, lehký, středně těžký, těžký, extra těžký, laserové fólie, štítky, obálky, hlavičkový, předtištěný, děrovaný, barevný, kancelářský bond, recyklovaný, hrubý a vellum |
| Podání | Automatické nebo ruční |
| Kopie, řazení, rozsahy stran, měřítko, orientace, obrácené pořadí, více stran na list a předvolby | Systémový tiskový dialog macOS; konkrétní nabídka závisí také na aplikaci |
| Obálka dokumentu na jiném papíru | Samostatný tisk rozsahu stran obálky a těla s jiným typem papíru. Automatický průvodce vkládáním obálek zatím není. |
| Ruční oboustranný tisk | Nástroj pro PDF v P1102 Utility; samostatný líc/rub, dlouhá/krátká vazba a doplnění prázdného rubu. Nejde o automatický duplex ani přímou volbu v dialogu všech aplikací. Čtyřstránkový test na zde připojené tiskárně potvrdil páry 1/2 a 3/4 i orientaci při otáčení jako kniha. Stoh se přenáší z výstupu do vstupu bez otočení. |
| Brožury | PDF na šířku A4, vazba vlevo/vpravo, doplnění na násobek čtyř stran, náhled. Čtyřstránková brožura s vazbou vlevo a vodoznakem fyzicky potvrzena na jedné P1102. |
| Vodoznak | Vlastní text na všech výstupních stranách nebo jen první; náhled a export PDF |
| Jemný posun | Výchozí geometrie z 1.6 zůstává zachována. Pokročilé volby CUPS `P1102ShiftX` (-15…68) a `P1102ShiftY` (-31…0) posouvají obraz v existujícím bílém okraji po bodech 600 dpi. Neopravují mechanické kolísání podání. |

Nástroje PDF přijímají odemčené dokumenty s povoleným tiskem do 200 MB a 2 000 stran. Vytvářejí samostatné zploštělé PDF, zdrojový soubor nemění. Tisknutelné anotace zůstávají ve vzhledu zachovány, interaktivita formulářů, odkazy a platnost digitálních podpisů se do upravené kopie nepřenášejí. Důležité dokumenty vždy zkontroluj v náhledu. Ruční duplex vynucuje jednu kopii a jednu výstupní stranu na list; brožura už má stránky rozložené v připraveném PDF.

## P1102 Utility

Otevři **Aplikace, P1102 Utility**, případně tlačítko nástroje tiskárny, pokud ho macOS nabízí. Rozhraní sleduje jazyk Macu, češtinu nebo angličtinu. Obnovení čte tiskárnu přímo přes USB. Při chybě zobrazí nedostupné údaje, nikoli stará procenta. Aplikace nemá trvale běžící službu, telemetrii ani internetové připojení.

* Živý odhad zbývajícího černého toneru, model a stav kazety, čas úspěšného načtení.
* Celkový počet stran, strany s aktuální kazetou, odhad zbývajících stran, počty zaseknutí a chyb podání, kódy událostí, datum firmwaru a nastavený papír v zásobníku.
* Uspávání, automatické vypnutí a tichý režim; každou změnu potvrzuje zpětné přečtení. Samotné čtení stavu nastavení nemění.
* Příkazy pro konfigurační stránku, stav spotřebního materiálu, ukázku a čištění. Spouštějí se výslovným tlačítkem. Čištění vyžaduje vhodný kancelářský papír a trvá několik minut. Uživatel fyzicky potvrdil stránku spotřebního materiálu s údajem 60 % toneru; konfigurační, ukázková a čisticí stránka zatím ověřené nejsou.
* Export diagnostiky do JSON z pevně vybraných polí, bez sériových čísel, uživatelských jmen, cest a obsahu dokumentů.
* Nativní příkazový nástroj `/Library/Printers/P1102Native/p1102ctl`: `status`, `supplies`, `set`, `page`. Výpis CLI obsahuje sériové číslo tiskárny, před sdílením ho odstraň. Při více připojených P1102 lze CLI zadat konkrétní sériové číslo USB; grafická aplikace nejednoznačný výběr odmítne.
* Příkaz CUPS `ReportLevels` pro údaje o náplni v macOS. CUPS může držet starší hodnotu; čas v obslužné aplikaci ukazuje čerstvé čtení z USB. Instalovaná fronta na macOS 27.0.1 úspěšně spustila ReportLevels a zveřejnila čerstvou hodnotu. Ukazatel byl ověřen i přímo v Nastavení systému, Volby a spotřební materiál, Úrovně náplní.

## Co tento kus tiskárny skutečně poskytl

Zařízení má tiskové USB rozhraní `07/01/02` a servisní rozhraní `ff/02/10`. Druhé přenáší XML ve zprávách HTTP přímo přes USB, bez síťového spojení. Nativní čtení 1. října 2026 poskytlo:

| Oblast | Dostupné údaje |
| --- | --- |
| Toner | Odhad procent, stav, značka, označení CE285A, jmenovitá kapacita a jednotka, datum výroby/posledního použití; existují také identifikátory kazety |
| Používání | Celkový počet stran, aktuální kazeta, odhad zbývajících stran, chyby podání a zaseknutí, údaje o předchozí kazetě |
| Identifikace | Model, produktové a sériové číslo, datum firmwaru, označení řídicích desek, servisní identifikátor a paměťová pole |
| Stav | Připravenost, spánek, zpracování a inzerované stavy zaseknutí, otevřeného krytu, podání papíru, ručního duplexu, plného výstupu, paměti a kazety |
| Protokol | Kódy událostí a počty stran při jejich vzniku |
| Nastavení a schopnosti | Formáty/druhy papíru, zásobník, sytost, obnova po zaseknutí, kvalita, časovače, interní stránky a jazyky |

Některá pole popisují nastavení, nikoli čidla. Hlášený formát zásobníku tedy nedokazuje, jaký papír je skutečně vložen. Procenta a zbývající strany jsou odhady firmwaru, nikoli měření hmotnosti toneru. Ne všechny inzerované poruchy byly fyzicky vyvolány. Údaje předchozí kazety se nesmějí zaměnit za současnou. Surové identifikátory a nepodložené servisní zásahy nejsou běžnými ovládacími prvky aplikace.

## Omezení a další možnosti

P1102 nemá skener, barevný tisk, mechanismus automatického duplexu ani vestavěnou Wi-Fi. Ovladač tento hardware nepřidá. Sdílení přes Mac je samostatná funkce macOS. Balík neinstaluje most AirPrint, internetový tisk, aktualizátor firmwaru ani reset zabezpečení.

Další samostatná rozšíření mohou být průvodce kalibrací z více listů, volitelná upozornění během otevření aplikace, výpočet nákladů se zadanými cenami, průvodce tiskem obálky dokumentu a odděleně prověřený most IPP/AirPrint. V této verzi je nevydáváme za hotové funkce.

Podklady: [manuál HP P1100](https://h10032.www1.hp.com/ctg/Manual/c04697535.pdf), místní PPD ovladače HP 6.9 a jeho pozorovaný výstup, [OpenPrinting foo2zjs](https://github.com/OpenPrinting/foo2zjs) a odpovědi připojené tiskárny. Windows posloužily jako inspirace pro brožury a vodoznak. Žádný proprietární ovladač HP se nešíří.
