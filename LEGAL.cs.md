# Kontrola licencí a zveřejnění

[English](LEGAL.md). Kontrola verze 1.7 ze dne 1. října 2026. Jde o kontrolu zdrojů a balíčku provedenou AI asistentem tohoto projektu, nikoli právní stanovisko nebo nezávislé prověření všech práv. Nezaručuje, že nikdo nevznese nárok. Projekt je nezávislý a veřejně dostupný komunitní software.

## Co zveřejňujeme

| Součást | Původ a licence |
| --- | --- |
| Nativní filtr, aplikace, komunikace USB, PDF, skripty a PPD | Kód projektu pod GPL-2.0-or-later. Použití AI je přiznané; neprohlašujeme výhradní lidské autorství výstupů AI. |
| foo2zjs a JBIG-KIT | Osm nezměněných souborů z konkrétní revize OpenPrinting. Zachované původní licence a oznámení, při sestavení kontrolované součty. Viz [původ](vendor/UPSTREAM.txt) a [NOTICE](NOTICE). |
| Hlavička úlohy v `src/job.h` | Úprava rámování foo2zjs pod stejnou GPL, s uvedením původu a data. |
| Kalibrace odstínů a referenční hashe | Měření vlastních testovacích vstupů přes místně nainstalovaný ovladač HP. Viz [metodika](tests/TONE_REFERENCE.md). Program HP ani surové záznamy tisku se nezveřejňují. |
| Systémové závislosti | CUPS a knihovny macOS poskytuje operační systém. Jejich programy, SDK ani hlavičkové soubory nejsou součástí balíčku. |
| Testovací materiály | Vlastní testovací data. Ve veřejných zdrojích ani balíčku nejsou uživatelské dokumenty, fotografie, příručky či loga HP ani firmware. |

Soubor `zjs.h` nemá samostatnou licenční hlavičku a obsahuje poznámku původního autora o starším protokolovém souboru. OpenPrinting jej distribuuje jako součást GPL balíčku foo2zjs. Poznámku zachováváme a netvrdíme, že jsme nezávisle prokázali celý historický řetězec práv. Jeho původ a práva k naměřeným kompatibilním datům jsou konkrétní body pro právníka, pokud je potřeba formální prověření.

## Splnění distribučních podmínek GPL

Instalátor obsahuje úplnou licenci, oznámení a odpovídající `Source.tar.gz`, včetně závislostí a skriptů sestavení a instalace. U vydání je stejný archiv také samostatně. Test balíčku ověřuje úplnost zdrojů proti veřejným souborům projektu. Jde o postup s přiloženými zdroji podle GPLv2, článku 3(a). Nepřidáváme zákaz komerčního použití, NDA ani další EULA. Viz [GPLv2](https://www.gnu.org/licenses/old-licenses/gpl-2.0.html).

Další vydání musí zachovat licence a autory, označit úpravy převzatých souborů a přiložit zdroje odpovídající skutečnému programu. Pouhý odkaz na GitHub není zde používaný způsob dodání zdrojů. Stažený zdrojový archiv vydání 1.6 obsahuje všechny soubory z odpovídajícího Git tagu, včetně oznámení a skriptů; jeho zveřejněné soubory se skrytě nenahrazují.

## Název a kompatibilita

Název projektu je **P1102 Native**. HP LaserJet označuje podporovanou tiskárnu. Historické identifikátory fronty, souborů a adresa repozitáře zůstávají kvůli aktualizacím a dohledatelnosti, ne jako tvrzení, že jde o výrobek HP. Nepoužíváme loga výrobců ani převzaté reklamní obrázky. Nezávislost uvádí README, instalátor i aplikace. [Pravidla HP pro ochranné známky](https://www.hp.com/us-en/terms-of-use.html) upozorňují na záměnu původu a schválení výrobku; tato stránka nám licenci k ochranné známce neuděluje.

Podkladem implementace jsou otevřené zdroje, popisy protokolu, odpovědi tiskárny a pozorované chování místního ovladače. Směrnice 2009/24/ES upravuje pozorování a testování oprávněným uživatelem a zvlášť výjimky pro interoperabilitu. **To samo nepotvrzuje oprávněnost každého možného postupu, převzatého prvku nebo smluvní situace.** Projekt neobsahuje obcházení ochran, extrakci firmwaru ani distribuci proprietárních programů. Viz [směrnice](https://eur-lex.europa.eu/legal-content/EN/TXT/?uri=CELEX:32009L0024).

## Co nelze touto kontrolou zaručit

Autor JBIG-KIT uvádí, že poslední z patentů uvedených pro JBIG1 vypršel v dubnu 2012. To není celosvětová patentová rešerše tisku, protokolů ani rastrování. Taková rešerše neproběhla. Viz [informace autora JBIG-KIT](https://www.cl.cam.ac.uk/~mgk25/jbigkit/).

Vyloučení záruk a odpovědnosti platí jen v rozsahu dovoleném právem. Nezabrání podání žaloby a neruší kogentní práva. Kontrola nepotvrzuje původ každé části výstupu AI, nevykládá konkrétní smlouvy uživatele s HP či Apple a nehodnotí budoucí obchodní model. Pro závazné právní posouzení je potřeba právník pro software a duševní vlastnictví, který zkontroluje přesné vydání a uvedené otevřené body. Ovladač proto neoznačujeme jako právně bezrizikový, certifikovaný ani schválený výrobcem.
