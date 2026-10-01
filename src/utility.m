/* SPDX-License-Identifier: GPL-2.0-or-later */
#import <Cocoa/Cocoa.h>
#import <ApplicationServices/ApplicationServices.h>
#import "device.h"
#import "pdf-tools.h"

static NSString *L(NSString *en, NSString *cs)
{ return [NSLocale.preferredLanguages.firstObject hasPrefix:@"cs"] ? cs : en; }
static NSString *readable(id raw)
{
    if ([raw isKindOfClass:NSArray.class]) { NSMutableArray *parts=[NSMutableArray array]; for(id item in raw)[parts addObject:readable(item)]; return [parts componentsJoinedByString:@", "]; }
    NSDictionary *names=@{@"ok":L(@"OK",@"V pořádku"), @"inPowerSave":L(@"Sleeping",@"Režim spánku"), @"ready":L(@"Ready",@"Připravena"), @"processing":L(@"Printing / processing",@"Tisk / zpracování"), @"closeDoorOrCover":L(@"Close the cover",@"Zavři kryt"), @"trayEmptyOrOpen":L(@"Load paper / close tray",@"Doplň papír / zavři zásobník"), @"jamInPrinter":L(@"Paper jam",@"Zaseknutý papír"), @"plain":L(@"Plain paper",@"Obyčejný papír"), @"iso_a4_210x297mm":@"A4", @"5minutes":L(@"5 minutes",@"5 minut"), @"4hours":L(@"4 hours",@"4 hodiny")};
    return [raw isKindOfClass:NSString.class] ? (names[raw] ?: raw) : [raw description];
}
static NSTextField *label(NSString *text) { return [NSTextField wrappingLabelWithString:text]; }
static NSStackView *stack(NSArray<NSView *> *views)
{
    NSStackView *s = [NSStackView stackViewWithViews:views]; s.orientation = NSUserInterfaceLayoutOrientationVertical;
    s.alignment = NSLayoutAttributeLeading; s.spacing = 12; s.edgeInsets = NSEdgeInsetsMake(18, 18, 18, 18); return s;
}
@interface P1102App : NSObject <NSApplicationDelegate>
@property NSWindow *window, *preview;
@property NSTextField *tonerLabel, *updated, *pdfName, *watermark, *message;
@property NSProgressIndicator *toner;
@property NSTextView *details;
@property NSPopUpButton *sleep, *autoOff, *quiet, *internalPage, *booklet;
@property NSButton *firstOnly, *shortEdge;
@property NSMutableArray<NSControl *> *controls;
@property NSDictionary *snapshot;
@property PDFDocument *inputPDF, *preparedPDF, *duplexPDF;
@property BOOL busy;
@end
@implementation P1102App
- (NSButton *)button:(NSString *)title action:(SEL)action
{ NSButton *b = [NSButton buttonWithTitle:title target:self action:action]; [_controls addObject:b]; return b; }
- (NSPopUpButton *)popup:(NSArray<NSString *> *)titles
{ NSPopUpButton *p = [[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO]; [p addItemsWithTitles:titles]; [_controls addObject:p]; return p; }
- (void)alert:(NSString *)text
{ NSAlert *a = [NSAlert new]; a.messageText = @"P1102 Utility"; a.informativeText = text; [a runModal]; }
- (BOOL)confirm:(NSString *)text
{ NSAlert *a = [NSAlert new]; a.messageText = text; [a addButtonWithTitle:L(@"Continue", @"Pokračovat")]; [a addButtonWithTitle:L(@"Cancel", @"Zrušit")]; return [a runModal] == NSAlertFirstButtonReturn; }
- (void)setWorking:(BOOL)working
{ _busy = working; for (NSControl *c in _controls) c.enabled = !working; _message.stringValue = working ? L(@"Communicating with the printer…", @"Komunikuji s tiskárnou…") : @""; }
- (void)applicationDidFinishLaunching:(NSNotification *)notification
{
    (void)notification; _controls = [NSMutableArray array];
    _window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0,0,790,730) styleMask:NSWindowStyleMaskTitled|NSWindowStyleMaskClosable|NSWindowStyleMaskMiniaturizable backing:NSBackingStoreBuffered defer:NO];
    _window.title = @"P1102 Utility 1.7";
    NSTabView *tabs = [NSTabView new];
    _tonerLabel = label(L(@"Toner: not read yet", @"Toner: zatím nenačten")); _tonerLabel.font = [NSFont boldSystemFontOfSize:24];
    _toner = [[NSProgressIndicator alloc] initWithFrame:NSMakeRect(0,0,600,18)]; _toner.indeterminate = NO; _toner.minValue = 0; _toner.maxValue = 100;
    [_toner.widthAnchor constraintEqualToConstant:680].active = YES;
    _updated = label(@""); _message = label(@"");
    _details = [NSTextView new]; _details.editable = NO; _details.font = [NSFont monospacedSystemFontOfSize:13 weight:NSFontWeightRegular];
    NSScrollView *scroll = [NSScrollView new]; scroll.hasVerticalScroller = YES; scroll.documentView = _details; _details.frame = NSMakeRect(0,0,680,350);
    [scroll.widthAnchor constraintEqualToConstant:680].active = YES; [scroll.heightAnchor constraintEqualToConstant:350].active = YES;
    _details.autoresizingMask = NSViewWidthSizable; _details.textContainer.widthTracksTextView = YES;
    NSStackView *status = stack(@[_tonerLabel, _toner, _updated, [self button:L(@"Refresh from USB", @"Obnovit z USB") action:@selector(refresh:)], scroll, [self button:L(@"Export diagnostics without serial numbers…", @"Export diagnostiky bez sériových čísel…") action:@selector(export:)], _message]);
    _sleep = [self popup:@[@"1 min",@"5 min",@"15 min",@"30 min",@"1 h"]];
    _autoOff = [self popup:@[L(@"Never",@"Nikdy"),@"30 min",@"1 h",@"2 h",@"4 h",@"8 h",@"24 h"]];
    _quiet = [self popup:@[L(@"Off",@"Vypnuto"),L(@"On (slower printing)",@"Zapnuto (pomalejší tisk)")]];
    _internalPage = [self popup:@[L(@"Configuration",@"Konfigurace"),L(@"Supplies",@"Spotřební materiál"),L(@"Demo",@"Ukázková stránka"),L(@"Cleaning",@"Čisticí stránka")]];
    NSStackView *settings = stack(@[label(L(@"Settings are read back after each change. Quiet mode intentionally slows the printer.",@"Každou změnu ověřím zpětným přečtením. Tichý režim záměrně zpomaluje tiskárnu.")), label(L(@"Sleep after",@"Uspat po")), _sleep, [self button:L(@"Apply sleep time",@"Uložit uspávání") action:@selector(applySleep:)], label(L(@"Automatic power off",@"Automatické vypnutí")), _autoOff, [self button:L(@"Apply power-off time",@"Uložit automatické vypnutí") action:@selector(setOff:)], label(L(@"Quiet mode",@"Tichý režim")), _quiet, [self button:L(@"Read quiet mode",@"Načíst tichý režim") action:@selector(readQuiet:)], [self button:L(@"Apply quiet mode",@"Uložit tichý režim") action:@selector(applyQuiet:)], _internalPage, [self button:L(@"Print selected internal page…",@"Vytisknout interní stránku…") action:@selector(internalPrint:)]]);
    _pdfName = label(L(@"No PDF selected",@"Není vybráno PDF"));
    _watermark = [NSTextField new]; _watermark.placeholderString = L(@"Optional watermark, maximum 120 characters",@"Volitelný vodoznak, nejvýše 120 znaků"); [_watermark.widthAnchor constraintEqualToConstant:680].active = YES;
    _firstOnly = [NSButton checkboxWithTitle:L(@"Watermark on first output page only",@"Vodoznak jen na první výstupní stránce") target:nil action:nil];
    _shortEdge = [NSButton checkboxWithTitle:L(@"Short-edge binding (turn pages upward)",@"Vazba na krátké straně (otáčení nahoru)") target:nil action:nil];
    _booklet = [self popup:@[L(@"Original page layout",@"Původní rozložení"),L(@"A4 booklet, left binding",@"Brožura A4, vazba vlevo"),L(@"A4 booklet, right binding",@"Brožura A4, vazba vpravo")]];
    NSStackView *pdf = stack(@[label(L(@"PDF tools work locally. The system print dialog also provides copies, page ranges, scaling, presets and multiple pages per sheet.",@"Nástroje PDF pracují místně. Systémový tiskový dialog nabízí také kopie, rozsahy stránek, měřítko, předvolby a více stránek na list.")), [self button:L(@"Open PDF…",@"Otevřít PDF…") action:@selector(openPDF:)], _pdfName, _booklet, _watermark, _firstOnly, [self button:L(@"Prepare and preview",@"Připravit a zobrazit náhled") action:@selector(prepare:)], [self button:L(@"Save prepared PDF…",@"Uložit připravené PDF…") action:@selector(savePDF:)], [self button:L(@"Print prepared PDF…",@"Vytisknout připravené PDF…") action:@selector(printPDF:)], label(L(@"Manual duplex uses one copy and the whole document. Finish pass 1 before reinserting the stack. Run a four-page orientation test first.",@"Ruční oboustranný tisk používá jednu kopii celého dokumentu. Před vložením stohu zpět vyčkej na dokončení prvního průchodu. Nejdřív ověř orientaci na čtyřech stránkách.")), _shortEdge, [self button:L(@"1. Print front sides…",@"1. Vytisknout přední strany…") action:@selector(fronts:)], [self button:L(@"2. Reinsert stack and print backs…",@"2. Vložit stoh zpět a vytisknout rub…") action:@selector(backs:)]]);
    for (NSArray *entry in @[@[L(@"Printer",@"Tiskárna"),status], @[L(@"Settings",@"Nastavení"),settings], @[L(@"PDF tools",@"Nástroje PDF"),pdf]]) {
        NSTabViewItem *tab = [[NSTabViewItem alloc] initWithIdentifier:entry[0]]; tab.label = entry[0]; tab.view = entry[1]; [tabs addTabViewItem:tab];
    }
    tabs.frame = NSInsetRect(_window.contentView.bounds, 12, 12); tabs.autoresizingMask = NSViewWidthSizable|NSViewHeightSizable; [_window.contentView addSubview:tabs];
    NSMenu *menu = [NSMenu new]; NSMenuItem *app = [NSMenuItem new]; NSMenu *appMenu = [NSMenu new];
    [appMenu addItemWithTitle:L(@"Quit P1102 Utility",@"Ukončit P1102 Utility") action:@selector(terminate:) keyEquivalent:@"q"]; app.submenu = appMenu; [menu addItem:app]; NSApp.mainMenu = menu;
    [_window center]; [_window makeKeyAndOrderFront:nil]; [NSApp activateIgnoringOtherApps:YES]; [self refresh:nil];
}
- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender { (void)sender; return YES; }
- (void)refresh:(id)sender
{
    (void)sender; if (_busy) return; [self setWorking:YES];
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED,0), ^{
        NSError *error = nil; NSDictionary *result = P1102Snapshot(nil, &error);
        dispatch_async(dispatch_get_main_queue(), ^{
            [self setWorking:NO]; self.snapshot = result;
            NSNumber *percent = result[@"tonerPercent"];
            self.tonerLabel.stringValue = percent ? [NSString stringWithFormat:L(@"Black toner: %@ %%",@"Černý toner: %@ %%"),percent] : L(@"Toner: unavailable",@"Toner: nedostupný"); self.toner.doubleValue = percent.doubleValue;
            self.updated.stringValue = result ? [NSString stringWithFormat:L(@"Printer estimate. Read: %@",@"Odhad tiskárny. Načteno: %@"), [NSDateFormatter localizedStringFromDate:[NSDate dateWithTimeIntervalSince1970:[result[@"readAt"] doubleValue]] dateStyle:NSDateFormatterShortStyle timeStyle:NSDateFormatterMediumStyle]] : error.localizedDescription;
            NSMutableString *text = [NSMutableString string];
            NSArray *rows = @[@[@"model",L(@"Printer",@"Tiskárna")],@[@"cartridge",L(@"Cartridge",@"Kazeta")],@[@"tonerState",L(@"Cartridge state",@"Stav kazety")],@[@"totalPages",L(@"Lifetime pages",@"Celkem stran")],@[@"cartridgePages",L(@"Pages with this cartridge",@"Stran s touto kazetou")],@[@"estimatedPagesRemaining",L(@"Estimated pages remaining",@"Odhad zbývajících stran")],@[@"states",L(@"Printer state",@"Stav tiskárny")],@[@"alerts",L(@"Alerts",@"Upozornění")],@[@"jams",L(@"Recorded jams",@"Zaznamenaná zaseknutí")],@[@"mispicks",L(@"Recorded misfeeds",@"Chyby podání")],@[@"eventCodes",L(@"Event log codes",@"Kódy v protokolu")],@[@"firmwareDate",L(@"Firmware date",@"Datum firmwaru")],@[@"trayMedia",L(@"Tray paper type",@"Typ papíru v zásobníku")],@[@"traySize",L(@"Tray paper size",@"Formát v zásobníku")],@[@"sleep",L(@"Sleep delay",@"Uspávání")],@[@"autoOff",L(@"Auto-off delay",@"Automatické vypnutí")]];
            for (NSArray *row in rows) { id value = result[row[0]]; if (value) value = readable(value); [text appendFormat:@"%@: %@\n",row[1],value ?: L(@"not available",@"nedostupné")]; }
            if (result[@"warnings"]) [text appendFormat:@"\n%@\n",[result[@"warnings"] componentsJoinedByString:@"\n"]];
            self.details.string = text;
            NSUInteger sleepIndex = [@[@"1minute",@"5minutes",@"15minutes",@"30minutes",@"1hour"] indexOfObject:result[@"sleep"] ?: @""];
            if (sleepIndex != NSNotFound) [self.sleep selectItemAtIndex:(NSInteger)sleepIndex];
            NSUInteger offIndex = [@[@"never",@"30minutes",@"1hour",@"2hours",@"4hours",@"8hours",@"24hours"] indexOfObject:result[@"autoOff"] ?: @""];
            if (offIndex != NSNotFound) [self.autoOff selectItemAtIndex:(NSInteger)offIndex];
        });
    });
}
- (void)export:(id)sender
{
    (void)sender; if (!_snapshot) { [self alert:L(@"Refresh printer data first.",@"Nejdřív načti údaje tiskárny.")]; return; }
    NSArray *keys = @[@"tonerPercent",@"tonerState",@"cartridge",@"totalPages",@"cartridgePages",@"estimatedPagesRemaining",@"jams",@"mispicks",@"eventCodes",@"states",@"alerts",@"firmwareDate",@"trayMedia",@"traySize",@"sleep",@"autoOff",@"readAt"];
    NSMutableDictionary *safe = [NSMutableDictionary dictionaryWithObject:@"1.7" forKey:@"driverVersion"];
    for (NSString *key in keys) if (_snapshot[key]) safe[key] = _snapshot[key];
    NSSavePanel *panel = [NSSavePanel savePanel]; panel.nameFieldStringValue = @"P1102-diagnostics.json";
    if ([panel runModal] == NSModalResponseOK) { NSError *error = nil; NSData *data = [NSJSONSerialization dataWithJSONObject:safe options:NSJSONWritingPrettyPrinted error:&error]; if (!data || ![data writeToURL:panel.URL options:NSDataWritingAtomic error:&error]) [self alert:error.localizedDescription]; }
}
- (void)apply:(NSString *)setting value:(NSString *)value
{
    if (_busy) return; [self setWorking:YES];
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED,0), ^{
        NSError *error = nil; BOOL ok = P1102Set(nil, setting, value, &error);
        dispatch_async(dispatch_get_main_queue(), ^{ [self setWorking:NO]; [self alert:ok ? L(@"Setting confirmed by the printer.",@"Tiskárna potvrdila nastavení.") : error.localizedDescription]; [self refresh:nil]; });
    });
}
- (void)applySleep:(id)sender { (void)sender; [self apply:@"PowerSaveTimeout" value:@[@"1minute",@"5minutes",@"15minutes",@"30minutes",@"1hour"][_sleep.indexOfSelectedItem]]; }
- (void)setOff:(id)sender { (void)sender; [self apply:@"AutoOffTime" value:@[@"never",@"30minutes",@"1hour",@"2hours",@"4hours",@"8hours",@"24hours"][_autoOff.indexOfSelectedItem]]; }
- (void)applyQuiet:(id)sender { (void)sender; [self apply:@"QuietMode" value:_quiet.indexOfSelectedItem ? @"ON" : @"OFF"]; }
- (void)readQuiet:(id)sender
{
    (void)sender; if (_busy) return; [self setWorking:YES];
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED,0), ^{ NSError *error = nil; NSDictionary *result = P1102QuietMode(nil,&error); dispatch_async(dispatch_get_main_queue(), ^{ [self setWorking:NO]; if (result) [self.quiet selectItemAtIndex:[result[@"quiet"] boolValue] ? 1 : 0]; else [self alert:error.localizedDescription]; }); });
}
- (void)internalPrint:(id)sender
{
    (void)sender; if (_busy) return;
    NSString *kind = @[@"configurationPage",@"suppliesStatusPage",@"demoPage",@"cleaningPage"][_internalPage.indexOfSelectedItem];
    NSString *prompt = [kind isEqual:@"cleaningPage"] ? L(@"Load smooth 70-90 g/m² copier paper. Cleaning takes about three minutes. Start?",@"Vlož hladký kancelářský papír 70-90 g/m². Čištění trvá přibližně tři minuty. Spustit?") : L(@"Load A4 paper and wait for other jobs to finish. Print one internal page?",@"Vlož A4 a vyčkej na dokončení ostatních úloh. Vytisknout jednu interní stránku?");
    if (![self confirm:prompt]) return; [self setWorking:YES];
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED,0), ^{ NSError *error = nil; BOOL ok = P1102InternalPage(nil,kind,&error); dispatch_async(dispatch_get_main_queue(), ^{ [self setWorking:NO]; [self alert:ok ? L(@"Request sent. Check the printer.",@"Požadavek odeslán. Zkontroluj tiskárnu.") : error.localizedDescription]; }); });
}
- (void)openPDF:(id)sender
{
    (void)sender; NSOpenPanel *p = [NSOpenPanel openPanel]; p.allowedFileTypes = @[@"pdf"]; p.allowsMultipleSelection = NO;
    if ([p runModal] != NSModalResponseOK) return;
    NSNumber *size; [p.URL getResourceValue:&size forKey:NSURLFileSizeKey error:nil];
    if (!size || size.unsignedLongLongValue > 200*1024*1024) { [self alert:L(@"PDF size limit is 200 MB.",@"Limit velikosti PDF je 200 MB.")]; return; }
    PDFDocument *pdf = [[PDFDocument alloc] initWithURL:p.URL];
    if (!pdf || pdf.isLocked || !pdf.allowsPrinting || !pdf.pageCount || pdf.pageCount > 2000) { [self alert:L(@"Cannot open this PDF for printing.",@"Toto PDF nelze otevřít k tisku.")]; return; }
    if (_duplexPDF && ![self confirm:L(@"Abandon the unfinished duplex job?",@"Opustit nedokončený oboustranný tisk?")]) return;
    _inputPDF = pdf; _preparedPDF = nil; _duplexPDF = nil; _pdfName.stringValue = [NSString stringWithFormat:@"%@ (%lu)",p.URL.lastPathComponent,(unsigned long)pdf.pageCount];
}
- (void)prepare:(id)sender
{
    (void)sender; if (_duplexPDF) { [self alert:L(@"Complete or reopen the PDF to abandon the duplex job first.",@"Nejdřív dokonči oboustranný tisk, nebo jej opusť opětovným otevřením PDF.")]; return; }
    NSError *error = nil; _preparedPDF = P1102PreparePDF(_inputPDF,_booklet.indexOfSelectedItem,_watermark.stringValue,_firstOnly.state == NSControlStateValueOn,&error);
    if (!_preparedPDF) { [self alert:error.localizedDescription]; return; }
    if (_booklet.indexOfSelectedItem) _shortEdge.state = NSControlStateValueOn;
    [_preview close];
    NSWindow *preview = [[NSWindow alloc] initWithContentRect:NSMakeRect(0,0,650,740) styleMask:NSWindowStyleMaskTitled|NSWindowStyleMaskClosable|NSWindowStyleMaskResizable backing:NSBackingStoreBuffered defer:NO];
    _preview = preview; preview.releasedWhenClosed = NO; preview.title = L(@"Prepared PDF preview",@"Náhled připraveného PDF"); PDFView *view = [PDFView new]; view.document = _preparedPDF; view.autoScales = YES; preview.contentView = view;
    [self.window addChildWindow:preview ordered:NSWindowAbove]; [preview center]; [preview makeKeyAndOrderFront:nil];
}
- (BOOL)hasPrepared
{ if (_preparedPDF) return YES; [self alert:L(@"Prepare the PDF first. Changes to watermark and layout apply when preparing again.",@"Nejdřív připrav PDF. Změny vodoznaku a rozložení se projeví při nové přípravě.")]; return NO; }
- (void)savePDF:(id)sender
{
    (void)sender; if (![self hasPrepared]) return; NSSavePanel *p = [NSSavePanel savePanel]; p.nameFieldStringValue = @"P1102-prepared.pdf";
    if ([p runModal] == NSModalResponseOK && ![_preparedPDF writeToURL:p.URL]) [self alert:L(@"Cannot save the PDF.",@"PDF se nepodařilo uložit.")];
}
- (BOOL)printDocument:(PDFDocument *)doc manual:(BOOL)manual
{
    NSPrintInfo *info = nil;
    for (NSString *name in NSPrinter.printerNames) {
        NSPrintInfo *candidate = [NSPrintInfo.sharedPrintInfo copy]; candidate.printer = [NSPrinter printerWithName:name];
        PMPrinter pm = NULL;
        if (PMSessionGetCurrentPrinter((PMPrintSession)candidate.PMPrintSession, &pm) == noErr && pm &&
            [(__bridge NSString *)PMPrinterGetID(pm) isEqual:@"HP_LaserJet_P1102_Native"]) { info = candidate; break; }
    }
    NSPrinter *printer = info.printer;
    if (!printer) { [self alert:L(@"Install the native printer queue first.",@"Nejdřív nainstaluj nativní tiskovou frontu.")]; return NO; }
    info.printer = printer; info.dictionary[NSPrintCopies] = @1;
    info.leftMargin = info.rightMargin = info.topMargin = info.bottomMargin = 0;
    NSPrintOperation *op = [doc printOperationForPrintInfo:info scalingMode:kPDFPrintPageScaleDownToFit autoRotate:YES];
    if (!op) return NO;
    info = op.printInfo; /* NSPrintOperation copies the supplied settings. */
    if (manual) {
        NSPrintPanel *panel = op.printPanel; panel.options = NSPrintPanelShowsPaperSize | NSPrintPanelShowsOrientation | NSPrintPanelShowsPreview;
        if ([panel runModalWithPrintInfo:info] != NSModalResponseOK) return NO;
        if (![info.printer.name isEqual:printer.name]) { [self alert:L(@"Manual duplex requires the native P1102 queue.",@"Ruční oboustranný tisk vyžaduje nativní frontu P1102.")]; return NO; }
        if (![info.jobDisposition isEqual:NSPrintSpoolJob]) { [self alert:L(@"Use Print for the duplex passes; use Save PDF outside the duplex workflow.",@"Pro průchody duplexu zvol Tisk. Uložení PDF je samostatná funkce.")]; return NO; }
        info.dictionary[NSPrintCopies] = @1; info.dictionary[NSPrintAllPages] = @YES; info.dictionary[NSPrintReversePageOrder] = @NO;
        info.dictionary[NSPrintPagesAcross] = @1; info.dictionary[NSPrintPagesDown] = @1;
        info.dictionary[NSPrintSelectionOnly] = @NO;
        op.showsPrintPanel = NO;
    }
    return [op runOperation];
}
- (void)printPDF:(id)sender { (void)sender; if ([self hasPrepared]) [self printDocument:_preparedPDF manual:NO]; }
- (void)fronts:(id)sender
{
    (void)sender; if (![self hasPrepared]) return;
    if (_duplexPDF) { [self alert:L(@"A duplex job is already waiting for its second pass.",@"Oboustranná úloha již čeká na druhý průchod.")]; return; }
    NSError *error = nil; PDFDocument *front = P1102PDFPass(_preparedPDF,NO,NO,&error);
    if (!front) { [self alert:error.localizedDescription]; return; }
    if ([self printDocument:front manual:YES]) _duplexPDF = _preparedPDF;
}
- (void)backs:(id)sender
{
    (void)sender; if (!_duplexPDF) { [self alert:L(@"Print front sides first.",@"Nejdřív vytiskni přední strany.")]; return; }
    if (![self confirm:L(@"Wait until all fronts have printed. Keep the stack in order and reinsert it printed side down, with its orientation unchanged. Ready to print backs?",@"Vyčkej na vytištění všech předních stran. Ponech pořadí listů a vlož stoh potištěnou stranou dolů, bez změny orientace. Vytisknout rub?")]) return;
    NSError *error = nil; PDFDocument *back = P1102PDFPass(_duplexPDF,YES,_shortEdge.state == NSControlStateValueOn,&error);
    if (!back) { [self alert:error.localizedDescription]; return; }
    if ([self printDocument:back manual:YES]) _duplexPDF = nil;
}
@end
int main(void)
{ @autoreleasepool { NSApplication *app = NSApplication.sharedApplication; P1102App *delegate = [P1102App new]; app.delegate = delegate; [app setActivationPolicy:NSApplicationActivationPolicyRegular]; [app run]; } return 0; }
