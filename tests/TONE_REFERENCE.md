# Měření šedých odstínů

Referenční data byla získána 1. října 2026 z lokálně nainstalovaného ovladače HP LaserJet Professional P1100 verze 6.9. Použit byl jeho režim FastRes 600, A6, běžný papír, hustota 3 a vypnutý EconoMode. Žádný program, kód ani tabulka extrahovaná z programu HP není součástí tohoto projektu. Referencí je naměřená odezva výstupu na vlastních kontrolních plochách, nikoli rozbor programu HP.

`raster_fixture 8 0 ramp` vytvoří jednu stránku CUPS raster s 256 plochami o rozměru 128 × 128 pixelů. Jsou v mřížce 16 × 16 s počátkem (100, 100). Hodnoty vstupního množství černé rostou po řádcích od 0 do 255. Barevný prostor W používá opačnou číselnou polaritu. Rozlišení rastru je 600 × 600 dpi; hodnota cupsCompression 401 odpovídá referenční volbě HP.

Tentýž raster se zpracoval lokálním filtrem HP do souboru, bez odeslání na tiskárnu. Filtr dostal data na standardním vstupu a uzavřený zpětný kanál přes `/dev/null`. Výstup se rozbalil nástrojem zjsdecode z přiložených zdrojů foo2zjs. Při měření byl oddělen úvodní PJL text od ZjStream.

Z každé plochy se spočítaly čtyři úrovně v oblasti 96 × 96 pixelů, odsazené o 16 pixelů od začátku plochy. Všechny počty byly násobkem 64. Soubor `hp-tone-reference.csv` obsahuje počty vydělené 64, tedy poměry na 144 pixelů. Úroveň 0 znamená bílou, úroveň 3 plnou černou. Dekodér PGM má opačnou polaritu. Součet každého řádku je 144, kumulativní počty rostou monotónně s tmavostí vstupu.

Verze 1.2 používala naměřené počty úrovní a vlastní geometrické rozmístění bodů. Fyzický výtisk se však stále mírně lišil. Nová kalibrace proto zaznamenává také odezvu každé pozice ve vzoru 12 × 12: souřadnice se berou modulo 12 v rámci celé tisknutelné plochy. U všech 256 ploch se ověřilo, že se tento vzor přesně opakuje v celé vnitřní oblasti 96 × 96 pixelů a že odezva každé pozice roste s tmavostí monotónně.

`src/halftone.h` obsahuje pro každou ze 144 pozic tři prahy: nejnižší vstupní hodnotu, při které naměřená úroveň dosáhne 1, 2 a 3. Filtr porovná vstupní hodnotu s těmito třemi prahy. Dřívější přibližný geometrický rastr byl nahrazen, nepoužívá se souběžně. Tabulka vznikla měřením vstupů a výstupů, nikoli extrakcí dat ze souboru programu HP.

Test počtů dále pokrývá všech 256 odstínů v prostorech W i K. Samostatný test `verification` používá jiný obraz se směsí proměnlivých odstínů a tenkých čar, který nebyl použit ke stanovení prahů. Jeho referenční obraz vytvořil HP ovladač stejným lokálním postupem. `hp-spatial-reference.json` obsahuje rozměry a SHA-256 všech dekódovaných pixelů. Nový filtr musí vytvořit přesně stejný obraz v obou vstupních polaritách. Před porovnáním se oddělí 31 bílých řádků korekce polohy, 15 bílých sloupců vlevo a bílé doplnění napravo a dole; všechny bílé oblasti se také kontrolují. Žádné pixely vlastního referenčního obrazu se nevynechávají. Při vývoji se navíc ověřila úplná shoda dekódované standardní A4 testovací stránky při stejném vstupním rastru.

Tato kontrola dokládá shodu dat na ověřených obrazech. Neprokazuje sama o sobě mechanickou registraci papíru ani shodný fyzický tisk ve všech podmínkách.

Původní HP program není zapotřebí k sestavení, testování ani provozu ovladače. Měření slouží pouze jako reference pro reprodukovatelné testy. macOS 28 ani jiná konkrétní tiskárna zde nebyly ověřeny.
