# Právní rozbor zveřejnění P1102 Native

Stav k 1. říjnu 2026, připravovaná verze 1.7.1 nad commitem `4b0dd33`. Jde o rešerši nad ověřenými podklady, nikoli stanovisko advokáta, celosvětovou patentovou prověrku ani záruku proti právním nárokům. [Soupis komponent](LEGAL.cs.md) a [technický audit](AUDIT-2026-10-01.md) doplňují tento dokument.

## Potvrzené okolnosti

Vlastník 1. října potvrdil bezplatné zveřejnění z České republiky na GitHubu, bez placené podpory, a oficiální zdroj referenčního ovladače HP. Druhé tvrzení není nezávislým ověřením konkrétní EULA a oprávnění všech provedených úkonů. Přesné datum a URL získání nejsou známy a nevymýšlíme je.

Ve zkoumaném stromu jsou vlastní adaptér, aplikace, syntetické testy, naměřená kalibrace a osm souborů foo2zjs/JBIG-KIT. Není zde program HP, firmware, příručka, logo výrobce ani soukromé dokumenty. Běhový kód nemá síťového klienta ani telemetrii. Metodiku popisuje [TONE_REFERENCE.md](tests/TONE_REFERENCE.md). Závěry neplatí automaticky pro budoucí změny či obchodní model.

## GPL a volné používání

Kodér se linkuje do výsledného filtru. Kombinovaný software zůstává GPL-2.0-or-later: příjemci smí program používat, upravovat a šířit, také komerčně, při dodržení licence. Vlastník nemůže zrušit práva převzatých autorů. Nepřidáváme public-domain tvrzení, zákaz komerčního použití, NDA ani omezující EULA.

Binární distribuce používá GPLv2 čl. 3(a): instalátor nese úplné odpovídající zdroje včetně kodéru a skriptů sestavení a instalace. Samostatný archiv vydání musí být totožný. Licence, oznámení a označení změn zůstávají zachované; systémové knihovny macOS se nebalí. Nová vydání nesmějí přidávat další omezení příjemcům. [GPLv2](https://www.gnu.org/licenses/old-licenses/gpl-2.0.html), [úplné místní znění](LICENSE).

Nový `SOURCE_MANIFEST` a skutečné sestavení bez `.git` opravují překážku reprodukce upraveného balíčku, nikoli potvrzené porušení licence již vydaným softwarem. Obecné „vzdávám se všech práv“ není náhradou licence a neruší cizí ani nezadatelná osobnostní práva. [Autorský zákon č. 121/2000 Sb.](https://e-sbirka.gov.cz/sb/2000/121).

## Pozorování a interoperabilita

Český § 66 odst. 1 písm. d) a čl. 5 odst. 3 směrnice 2009/24/ES upravují zkoumání programu oprávněným uživatelem při úkonech, k nimž je oprávněn. Dekompilace má zvláštní podmínky. Popsaná metoda je pozorování výstupu při vlastních vstupech, nikoli dekompilace HP programu; výjimka pro dekompilaci proto není automatickým právním základem měření. § 66 odst. 6 chrání zákonný minimální rozsah před smluvním zúžením s uvedenou výjimkou pro písm. b). To samo neřeší oprávnění ke konkrétní kopii a způsobu spuštění. [Autorský zákon](https://e-sbirka.gov.cz/sb/2000/121), [směrnice](https://eur-lex.europa.eu/legal-content/EN/TXT/?uri=CELEX:32009L0024).

Rozsudek SAS Institute, C-406/10, odlišuje funkcionalitu, programovací jazyk a formáty dat od chráněného vyjádření programu. Podporuje vlastní kompatibilní implementaci, ne kopírování kódu nebo originálního textu příruček. Jiné chráněné prvky tím nejsou automaticky vypořádány. [Rozsudek ze dne 2. května 2012, ECLI:EU:C:2012:259](https://eur-lex.europa.eu/legal-content/EN/TXT/PDF/?uri=CELEX:62010CJ0406).

Měřené prahy a hashe pocházejí z vlastních syntetických vstupů. Distribuovaný HP kód nebyl nalezen, což snižuje konkrétní riziko šíření jeho programu. Neprokazuje to však práva ke každému odvozenému prvku. Postup nenazýváme právně ověřeným clean-room. Pro případ formální prověrky uchovejte soukromě původ instalátoru HP, oprávnění k užití a přesnou metodiku; proprietární instalátor se nepřikládá k vydání.

## Historický původ a patenty

Osm souborů odpovídá [připnuté revizi OpenPrinting](https://github.com/OpenPrinting/foo2zjs/tree/80499ed5bf6caa2963ad337e37cfda78a80aab1e). Bajtová shoda prokazuje bezprostřední zdroj, nikoli celý řetězec práv. `zjs.h` nemá samostatnou licenční hlavičku a zmiňuje historický `zjrca.h`. `jbig_ar.h` obsahuje autora, nikoli samostatný úplný grant. Hlavičky se posuzují v kontextu GPL balíčku a JBIG-KIT; netvrdíme, že každá obsahuje vlastní úplnou licenci.

Potvrzený konflikt nebyl nalezen, není proto důvod licenci přepisovat nebo oznámení odstraňovat. Historické komentáře a `COPYING` zůstávají. Pro formální jistotu je potřeba doložit starší původ `zjs.h` u upstreamu. Nahrazení odhadem by právní jistotu nezaručilo a mohlo poškodit tisk.

Autor JBIG-KIT uvádí, že poslední z uvedených patentů JBIG1 vypršel v dubnu 2012. To není celosvětové prověření všech tiskových technologií a protokolů. [Informace autora](https://www.cl.cam.ac.uk/~mgk25/jbigkit/).

## Označení a ikona

P1102 Native je hlavní název. HP LaserJet a Apple/macOS označují kompatibilitu, nikoli původ či schválení projektu. Loga a reklamní fotografie výrobců se nepoužívají. Historické názvy fronty a souborů zůstávají pro kontinuitu. NOTICE uvádí Apple Inc. Ikona je vlastní programová kresba obecné tiskárny, bez převzatých symbolů; zdroj se distribuuje s projektem. [Pravidla HP](https://www.hp.com/us-en/terms-of-use.html), [pravidla Apple](https://www.apple.com/legal/intellectual-property/guidelinesfor3rdparties.html).

Kompatibilita má být prezentována méně výrazně než vlastní produkt a bez dojmu podpory výrobce. Tato pravidla neposkytují všeobecnou licenci k logům a disclaimer není zárukou proti nároku z ochranné známky.

## Odpovědnost a evropské změny

Bezplatnost neznamená nulovou odpovědnost. GPL vylučuje záruky jen v rozsahu dovoleném právem. README neslibuje profesionální podporu ani certifikaci; Issues nejsou sjednaný servis. Český § 2898 omezuje předběžné vyloučení náhrady újmy. Konkrétní aplikace závisí na vztahu stran, tato rešerše neuzavírá všechny smluvní ani mimosmluvní nároky. [Občanský zákoník](https://e-sbirka.gov.cz/sb/2012/89).

Směrnice 2024/2853 zahrnuje software; čl. 2 vymezuje výrobky uvedené na trh či do provozu po 9. prosinci 2026 a výjimku pro open source mimo komerční činnost. Výjimka neruší jiné odpovědnostní předpisy. Pro pozdější vydání je nutné znovu ověřit českou transpozici i obchodní kontext. [Primární znění](https://eur-lex.europa.eu/legal-content/EN/TXT/PDF/?uri=CELEX:32024L2853).

CRA podle aktuálních podkladů Komise nepodřazuje každé nekomerční open-source úložiště povinnostem výrobce. Nulová cena sama nestačí, záleží na monetizaci a obchodním kontextu. Sdělené bezplatné komunitní zveřejnění bez placené podpory a telemetrie podporuje závěr, že zde nebyl identifikován komerční model. Jde o aplikaci na známé skutečnosti, ne rozhodnutí úřadu. Při prodeji, obchodním balení či monetizaci se posouzení opakuje. [Komise: open source a CRA](https://digital-strategy.ec.europa.eu/en/policies/cra-open-source).

Ohlašovací povinnosti dotčených subjektů se uplatňují od 11. září 2026, hlavní povinnosti od 11. prosince 2027. Z tohoto podmíněného posouzení neplyne požadavek přidat nyní CE označení projektu, ale ani všeobecná certifikace či výjimka pro libovolný budoucí model. [Aktuální přehled Komise](https://digital-strategy.ec.europa.eu/en/policies/cyber-resilience-act), [nařízení 2024/2847](https://eur-lex.europa.eu/eli/reg/2024/2847/oj/eng).

## Závěr a otevřené body

| Oblast | Závěr |
| --- | --- |
| Potvrzený licenční konflikt | V kontrolovaných součástech nenalezen. Zachovat GPL a autory. |
| Odpovídající zdroje | Manifest, bajtová kontrola a skutečné sestavení jsou povinná brána. |
| Volné používání | Naplnit GPL, ne nepřípustným zrušením cizích práv. |
| Proprietární HP materiály | Nedodávají se; nepřidávat je. |
| Historický `zjs.h` | Neuzavřený řetězec práv, ne potvrzené porušení. |
| Měření a EULA | Metodika popsaná, přesné oprávnění reference není právně uzavřené. |
| Patenty a jiné země | Celosvětová prověrka neproběhla. |
| Příspěvky AI | Přiznání pomoci nedokazuje originalitu ani vlastnictví každého výstupu. |
| Formální jistota | Advokát pro software/IP musí prověřit konkrétní vydání a otevřené podklady. |

Koordinátor ověřoval kód a primární zdroje. Hermes nezávisle prověřil licence a veřejné archivy 1.7; následný širší pokus po 600 sekundách nedodal výstup a není počítán jako hotový rozbor. Claude následně přečetl licence a aktuální podklady CRA, část právních zdrojů mu nebyla dostupná. Jeho návrhy z paměti koordinátor nepřevzal bez další kontroly: například evropské články a novou směrnici o odpovědnosti ověřoval zvlášť.

Některé přímé stránky GNU a EUR-Lex blokovaly načtení. GPL byla kontrolována místně, rozsudek C-406/10 přímo z EUR-Lex, CRA přímo od Komise a § 66 v oficiálně indexovaném aktuálním znění e-Sbírky. Nová směrnice o odpovědnosti byla dostupná v indexovaném primárním znění, její PDF endpoint blokoval automatické čtení. Tyto limity jsou důvodem neprezentovat dokument jako advokátní prověrku.
