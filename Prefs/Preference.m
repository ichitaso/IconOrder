#import <QuartzCore/QuartzCore.h>
#import <UIKit/UIKit.h>
#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>
#import <Preferences/PSSwitchTableCell.h>
#import <Preferences/PSTableCell.h>
#import <Preferences/PSEditableTableCell.h>
#import <Preferences/PSListItemsController.h>
#import <Preferences/PSSliderTableCell.h>
#import <SafariServices/SafariServices.h>
#import <spawn.h>
#import "../Common.h"

static void easy_spawn(const char * args[]) {
    pid_t pid;
    int status;
    posix_spawn(&pid, args[0], NULL, NULL, (char * const*)args, NULL);
    waitpid(pid, &status, WEXITED);
}

#pragma mark - Preference file helpers

static NSString *const kBackupSpecifierKey = @"ico_backup";

static NSMutableDictionary *ICOLoadPrefs(void) {
    NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:PREF_PATH];
    return prefs ? [prefs mutableCopy] : [NSMutableDictionary dictionary];
}

static BOOL ICOSavePrefs(NSDictionary *prefs) {
    return [prefs writeToFile:PREF_PATH atomically:YES];
}

// Only keeps well-formed entries: { "2026-10-17" : <icon state dictionary> }
static NSMutableDictionary *ICOBackupsFromPrefs(NSDictionary *prefs) {
    NSMutableDictionary *result = [NSMutableDictionary dictionary];
    id raw = prefs[BACKUPS_KEY];
    if ([raw isKindOfClass:[NSDictionary class]]) {
        [(NSDictionary *)raw enumerateKeysAndObjectsUsingBlock:^(id k, id v, BOOL *stop) {
            if ([k isKindOfClass:[NSString class]] && [v isKindOfClass:[NSDictionary class]]) {
                result[k] = v;
            }
        }];
    }
    return result;
}

// Newest first ("2026-10-17 (2)" comes before "2026-10-17", "(10)" before "(2)")
static NSArray<NSString *> *ICOSortedBackupNames(NSDictionary *backups) {
    return [backups.allKeys sortedArrayUsingComparator:^NSComparisonResult(NSString *a, NSString *b) {
        return [b compare:a options:NSNumericSearch];
    }];
}

// Fixed locale / calendar so the name is always yyyy-MM-dd even with Japanese or Buddhist calendars.
static NSString *ICODateString(void) {
    static NSDateFormatter *formatter;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [[NSDateFormatter alloc] init];
        formatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
        formatter.calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
        formatter.dateFormat = @"yyyy-MM-dd";
    });
    return [formatter stringFromDate:[NSDate date]];
}

// "2026-10-17" -> "2026-10-17 (2)" -> "2026-10-17 (3)" ...
static NSString *ICOUniqueName(NSDictionary *existing, NSString *base) {
    if (!existing[base]) return base;
    NSUInteger n = 2;
    NSString *name;
    do {
        name = [NSString stringWithFormat:@"%@ (%lu)", base, (unsigned long)n++];
    } while (existing[name]);
    return name;
}

static PSSpecifier *ICOGroup(NSString *title, NSString *footer) {
    PSSpecifier *spec;
    if (title.length) {
        spec = [PSSpecifier preferenceSpecifierNamed:title
                                              target:nil
                                                 set:Nil
                                                 get:Nil
                                              detail:Nil
                                                cell:PSGroupCell
                                                edit:Nil];
    } else {
        spec = [PSSpecifier emptyGroupSpecifier];
    }
    if (footer.length) [spec setProperty:footer forKey:@"footerText"];
    return spec;
}

static PSSpecifier *ICOButton(id target, NSString *title, SEL action) {
    PSSpecifier *spec = [PSSpecifier preferenceSpecifierNamed:title
                                                       target:target
                                                          set:NULL
                                                          get:NULL
                                                       detail:Nil
                                                         cell:PSButtonCell
                                                         edit:Nil];
    spec->action = action;
    return spec;
}

#pragma mark - Header views

@interface UIImage (SettingsKit)
+ (UIImage *)imageNamed:(NSString *)named inBundle:(NSBundle *)bundle;
@end

@interface PSSpecifier (ValuesAndTitles)
- (void)setValues:(NSArray *)values titles:(NSArray *)titles;
@end

// Navigation bar icon
@interface ICOIconImageView : UIImageView
@end

@implementation ICOIconImageView
- (instancetype)initWithImage:(UIImage *)image {
    self = [super initWithImage:image];
    if (self) {
        self.contentMode = UIViewContentModeScaleAspectFit;
        self.clipsToBounds = YES;
        self.layer.borderWidth = 1.0;
        self.frame = CGRectMake(0, 0, 30, 30);
        [self updateBorderColor];
    }
    return self;
}

- (CGSize)intrinsicContentSize {
    return CGSizeMake(30, 30);
}

- (void)layoutSubviews {
    [super layoutSubviews];
    self.layer.cornerRadius = MIN(CGRectGetWidth(self.bounds), CGRectGetHeight(self.bounds)) * 0.2237;
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    [self updateBorderColor];
}

- (void)updateBorderColor {
    BOOL dark = NO;
    if (@available(iOS 13.0, *)) {
        dark = (self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark);
    }
    UIColor *color = dark ? [UIColor colorWithWhite:1.0 alpha:0.55] : [UIColor colorWithWhite:0.0 alpha:0.18];
    self.layer.borderColor = color.CGColor;
}
@end

@interface ICOHeaderView : UIView
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
- (CGFloat)heightForWidth:(CGFloat)width;
@end

@implementation ICOHeaderView
- (instancetype)init {
    self = [super initWithFrame:CGRectZero];
    if (self) {
        self.backgroundColor = [UIColor clearColor];

        _titleLabel = [[UILabel alloc] init];
        _titleLabel.text = TWEAK_TITLE;
        _titleLabel.font = [UIFont fontWithName:@"HelveticaNeue-Thin" size:35] ?: [UIFont systemFontOfSize:35 weight:UIFontWeightThin];
        _titleLabel.backgroundColor = [UIColor clearColor];
        _titleLabel.textAlignment = NSTextAlignmentCenter;
        _titleLabel.numberOfLines = 1;
        _titleLabel.adjustsFontSizeToFitWidth = YES;
        _titleLabel.minimumScaleFactor = 0.6;

        _subtitleLabel = [[UILabel alloc] init];
        _subtitleLabel.text = TWEAK_DESCRIPTION;
        _subtitleLabel.font = [UIFont fontWithName:@"HelveticaNeue-Thin" size:14] ?: [UIFont systemFontOfSize:14 weight:UIFontWeightThin];
        _subtitleLabel.backgroundColor = [UIColor clearColor];
        _subtitleLabel.textAlignment = NSTextAlignmentCenter;
        _subtitleLabel.numberOfLines = 0;
        _subtitleLabel.lineBreakMode = NSLineBreakByWordWrapping;

        if (@available(iOS 13.0, *)) {
            _titleLabel.textColor = [UIColor labelColor];
            _subtitleLabel.textColor = [UIColor secondaryLabelColor];
        }

        [self addSubview:_titleLabel];
        [self addSubview:_subtitleLabel];
    }
    return self;
}

- (CGFloat)layoutForWidth:(CGFloat)width apply:(BOOL)apply {
    const CGFloat pad = 20.0;
    CGFloat inner = MAX(width - pad * 2, 0);
    CGSize titleSize = [self.titleLabel sizeThatFits:CGSizeMake(inner, CGFLOAT_MAX)];
    CGSize subSize = [self.subtitleLabel sizeThatFits:CGSizeMake(inner, CGFLOAT_MAX)];

    CGFloat y = 14.0;
    if (apply) self.titleLabel.frame = CGRectMake(pad, y, inner, ceil(titleSize.height));
    y += ceil(titleSize.height) + 4.0;
    if (apply) self.subtitleLabel.frame = CGRectMake(pad, y, inner, ceil(subSize.height));
    y += ceil(subSize.height) + 22.0;
    return y;
}

- (CGFloat)heightForWidth:(CGFloat)width {
    return [self layoutForWidth:width apply:NO];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    [self layoutForWidth:CGRectGetWidth(self.bounds) apply:YES];
}
@end

#pragma mark - Cells

@interface PSSubtitleSwitchTableCell : PSSwitchTableCell
@end

@interface ICOSwitchTableCell : PSSubtitleSwitchTableCell
@end

@implementation ICOSwitchTableCell
- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier specifier:(PSSpecifier *)specifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier specifier:specifier];
    if (self) {
        [((UISwitch *)[self control]) setOnTintColor:SettingsColor(1)];
    }
    return self;
}
@end

#pragma mark - Controller

@interface IconOrderController : PSListController
@end

@interface IconOrderController () <UIDocumentPickerDelegate>
@property (nonatomic, strong) ICOHeaderView *ico_headerView;
@property (nonatomic, assign) BOOL ico_pickerIsImport;
@property (nonatomic, strong) NSURL *ico_exportTempURL;
@property (nonatomic, strong) UIButton *respringButton;
@end

@implementation IconOrderController

- (NSArray *)specifiers {
    if (_specifiers == nil) {
        NSMutableArray *specifiers = [NSMutableArray array];
        PSSpecifier *spec;
        
        spec = [PSSpecifier preferenceSpecifierNamed:@"Enabled"
                                              target:self
                                                 set:@selector(setPreferenceValue:specifier:)
                                                 get:@selector(readPreferenceValue:)
                                              detail:Nil
                                                cell:PSSwitchCell
                                                edit:Nil];
        [spec setProperty:@"enabled" forKey:@"key"];
        [spec setProperty:@YES forKey:@"default"];
        [spec setProperty:NSClassFromString(@"ICOSwitchTableCell") forKey:@"cellClass"];
        [spec setProperty:@"Respring is required" forKey:@"cellSubtitleText"];
        [specifiers addObject:spec];
        
        // Backup / Restore
        NSDictionary *backups = ICOBackupsFromPrefs(ICOLoadPrefs());
        NSArray<NSString *> *names = ICOSortedBackupNames(backups);
        
        [specifiers addObject:ICOGroup(@"Backup / Restore",
                                       @"Save the current icon layout as a backup. Restoring a backup replaces the current layout and requires a respring.")];
        [specifiers addObject:ICOButton(self, @"Create Backup", @selector(createBackup))];
        
        NSString *listFooter = names.count
            ? @"Tap a backup to restore or delete it. You can also swipe left to delete."
            : @"No backups yet.";
        [specifiers addObject:ICOGroup(@"Saved Backups", listFooter)];
        for (NSString *name in names) {
            PSSpecifier *item = ICOButton(self, name, NULL);
            [item setProperty:name forKey:kBackupSpecifierKey];
            [specifiers addObject:item];
        }
        
        // Files app
        [specifiers addObject:ICOGroup(@"Files",
                                       @"Export the settings file (current layout and all backups) to the Files app, or import one that was exported earlier.")];
        [specifiers addObject:ICOButton(self, @"Export to Files", @selector(exportToFiles))];
        [specifiers addObject:ICOButton(self, @"Import from Files", @selector(importFromFiles))];
        
        spec = [PSSpecifier emptyGroupSpecifier];
        [specifiers addObject:spec];
        
        spec = [PSSpecifier preferenceSpecifierNamed:@"Other Tweaks"
                                              target:self
                                                 set:NULL
                                                 get:NULL
                                              detail:Nil
                                                cell:PSLinkCell
                                                edit:Nil];
        
        spec->action = @selector(openDaonate);
        [specifiers addObject:spec];
        
        spec = [PSSpecifier emptyGroupSpecifier];
        [spec setProperty:@1 forKey:@"footerAlignment"];
        [spec setProperty:CREDITS forKey:@"footerText"];
        [specifiers addObject:spec];
        
        _specifiers = [specifiers copy];
    }
    return _specifiers;
}

- (void)ico_reloadList {
    _specifiers = nil;
    [self reloadSpecifiers];
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
    NSMutableDictionary *prefs = ICOLoadPrefs();
    [prefs setObject:value forKey:specifier.properties[@"key"]];
    ICOSavePrefs(prefs);
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFSTR(Notify_Preferences), NULL, NULL, YES);
}

- (id)readPreferenceValue:(PSSpecifier*)specifier {
    NSDictionary *prefs = [[NSDictionary alloc] initWithContentsOfFile:PREF_PATH];
    return prefs[specifier.properties[@"key"]]?:[[specifier properties] objectForKey:@"default"];
}

- (void)respring {
    easy_spawn((const char *[]){jbroot("/usr/bin/killall"), "backboardd", NULL});
}

- (void)openDaonate {
    [self openURLInBrowser:@"https://cydia.ichitaso.com/donation.html"];
}

- (void)openURLInBrowser:(NSString *)url {
    SFSafariViewController *safari = [[SFSafariViewController alloc] initWithURL:[NSURL URLWithString:url]];
    [self presentViewController:safari animated:YES completion:nil];
}

#pragma mark - Alerts

- (void)ico_showAlert:(NSString *)title message:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)ico_promptRespringWithTitle:(NSString *)title message:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Later" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Respring" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [self respring];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - Backup

- (void)createBackup {
    NSMutableDictionary *prefs = ICOLoadPrefs();
    id state = prefs[KEY];
    if (![state isKindOfClass:[NSDictionary class]]) {
        [self ico_showAlert:@"No Icon Layout Yet"
                    message:@"IconOrder has not saved an icon layout yet. Make sure it is enabled and respring once, then try again."];
        return;
    }
    
    NSMutableDictionary *backups = ICOBackupsFromPrefs(prefs);
    NSString *name = ICOUniqueName(backups, ICODateString());
    backups[name] = state;
    prefs[BACKUPS_KEY] = backups;
    
    if (!ICOSavePrefs(prefs)) {
        [self ico_showAlert:@"Backup Failed" message:@"Could not write the settings file."];
        return;
    }
    [self ico_reloadList];
    [self ico_showAlert:@"Backup Created" message:name];
}

- (void)ico_showActionsForBackup:(NSString *)name {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:name
                                                                   message:@"Restoring replaces the current icon layout. A respring is required."
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Restore" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [self ico_restoreBackup:name];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Delete" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        [self ico_deleteBackup:name];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)ico_restoreBackup:(NSString *)name {
    NSMutableDictionary *prefs = ICOLoadPrefs();
    NSDictionary *state = ICOBackupsFromPrefs(prefs)[name];
    if (!state) {
        [self ico_showAlert:@"Backup Not Found" message:name];
        [self ico_reloadList];
        return;
    }
    
    prefs[KEY] = state;
    if (!ICOSavePrefs(prefs)) {
        [self ico_showAlert:@"Restore Failed" message:@"Could not write the settings file."];
        return;
    }
    
    BOOL disabled = (prefs[@"enabled"] && ![prefs[@"enabled"] boolValue]);
    NSString *message = disabled
        ? @"IconOrder is currently disabled. Enable it, then respring to apply the restored layout."
        : @"Respring now to apply the restored layout?";
    [self ico_promptRespringWithTitle:[NSString stringWithFormat:@"Restored %@", name] message:message];
}

- (void)ico_deleteBackup:(NSString *)name {
    NSMutableDictionary *prefs = ICOLoadPrefs();
    NSMutableDictionary *backups = ICOBackupsFromPrefs(prefs);
    [backups removeObjectForKey:name];
    if (backups.count) {
        prefs[BACKUPS_KEY] = backups;
    } else {
        [prefs removeObjectForKey:BACKUPS_KEY];
    }
    ICOSavePrefs(prefs);
    [self ico_reloadList];
}

#pragma mark - Backup list interaction

- (NSString *)ico_backupNameAtIndexPath:(NSIndexPath *)indexPath {
    PSSpecifier *spec = [self specifierAtIndexPath:indexPath];
    id name = [spec propertyForKey:kBackupSpecifierKey];
    return [name isKindOfClass:[NSString class]] ? name : nil;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *name = [self ico_backupNameAtIndexPath:indexPath];
    if (name) {
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
        [self ico_showActionsForBackup:name];
        return;
    }
    [super tableView:tableView didSelectRowAtIndexPath:indexPath];
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return [self ico_backupNameAtIndexPath:indexPath] != nil;
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath {
    return [self ico_backupNameAtIndexPath:indexPath] ? UITableViewCellEditingStyleDelete : UITableViewCellEditingStyleNone;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle != UITableViewCellEditingStyleDelete) return;
    NSString *name = [self ico_backupNameAtIndexPath:indexPath];
    if (name) [self ico_deleteBackup:name];
}

#pragma mark - Export / Import (Files app, iOS 12 - 26)

- (void)ico_cleanupExportTemp {
    if (self.ico_exportTempURL) {
        [[NSFileManager defaultManager] removeItemAtURL:self.ico_exportTempURL error:nil];
        self.ico_exportTempURL = nil;
    }
}

- (void)exportToFiles {
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:PREF_PATH]) {
        [self ico_showAlert:@"Nothing to Export" message:@"The settings file does not exist yet. Respring once with IconOrder enabled and try again."];
        return;
    }
    
    // Export a copy with a friendly file name
    [self ico_cleanupExportTemp];
    NSString *fileName = [NSString stringWithFormat:@"IconOrder-%@.plist", ICODateString()];
    NSURL *tempURL = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:fileName]];
    [fm removeItemAtURL:tempURL error:nil];
    
    NSError *error = nil;
    if (![fm copyItemAtURL:[NSURL fileURLWithPath:PREF_PATH] toURL:tempURL error:&error]) {
        [self ico_showAlert:@"Export Failed" message:error.localizedDescription ?: @"Could not create the export file."];
        return;
    }
    self.ico_exportTempURL = tempURL;
    self.ico_pickerIsImport = NO;
    
    UIDocumentPickerViewController *picker = nil;
    if (@available(iOS 14.0, *)) {
        picker = [[UIDocumentPickerViewController alloc] initForExportingURLs:@[tempURL] asCopy:YES];
    } else {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        picker = [[UIDocumentPickerViewController alloc] initWithURL:tempURL inMode:UIDocumentPickerModeExportToService];
#pragma clang diagnostic pop
    }
    picker.delegate = self;
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)importFromFiles {
    self.ico_pickerIsImport = YES;
    
    // The legacy initializer is deprecated in iOS 14 but works on every version from iOS 12 to 26,
    // and avoids linking UniformTypeIdentifiers (iOS 14+ only). The file content is validated after picking.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initWithDocumentTypes:@[@"public.data"]
                                                                                                    inMode:UIDocumentPickerModeImport];
#pragma clang diagnostic pop
    picker.delegate = self;
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    if (!self.ico_pickerIsImport) {
        [self ico_cleanupExportTemp];
        return;
    }
    
    NSURL *url = urls.firstObject;
    if (!url) return;
    
    // Read now (the temporary copy may disappear), present results after the picker has been dismissed.
    BOOL scoped = [url startAccessingSecurityScopedResource];
    NSError *error = nil;
    NSData *data = [NSData dataWithContentsOfURL:url options:0 error:&error];
    if (scoped) [url stopAccessingSecurityScopedResource];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self ico_importData:data readError:error];
    });
}

- (void)documentPickerWasCancelled:(UIDocumentPickerViewController *)controller {
    if (!self.ico_pickerIsImport) [self ico_cleanupExportTemp];
}

- (void)ico_importData:(NSData *)data readError:(NSError *)readError {
    if (!data) {
        [self ico_showAlert:@"Import Failed" message:readError.localizedDescription ?: @"Could not read the file."];
        return;
    }
    
    id obj = [NSPropertyListSerialization propertyListWithData:data options:NSPropertyListImmutable format:NULL error:NULL];
    if (![obj isKindOfClass:[NSDictionary class]]) {
        [self ico_showAlert:@"Invalid File" message:@"This is not a valid property list file."];
        return;
    }
    NSDictionary *incoming = obj;
    
    // Accepts an IconOrder export, or a raw IconState.plist
    NSDictionary *state = nil;
    if ([incoming[KEY] isKindOfClass:[NSDictionary class]]) {
        state = incoming[KEY];
    } else if (incoming[@"iconLists"] || incoming[@"buttonBar"]) {
        state = incoming;
    }
    NSDictionary *incomingBackups = ICOBackupsFromPrefs(incoming);
    
    if (!state && incomingBackups.count == 0) {
        [self ico_showAlert:@"Invalid File" message:@"This file does not contain an IconOrder icon layout or backups."];
        return;
    }
    
    NSMutableDictionary *prefs = ICOLoadPrefs();
    NSMutableDictionary *backups = ICOBackupsFromPrefs(prefs);
    
    NSUInteger added = 0;
    NSArray<NSString *> *incomingNames = [ICOSortedBackupNames(incomingBackups) reverseObjectEnumerator].allObjects;
    for (NSString *name in incomingNames) {
        NSDictionary *backup = incomingBackups[name];
        if ([backups[name] isEqual:backup]) continue; // already have exactly this one
        backups[ICOUniqueName(backups, name)] = backup;
        added++;
    }
    if (backups.count) prefs[BACKUPS_KEY] = backups;
    if (state) prefs[KEY] = state;
    
    if (!ICOSavePrefs(prefs)) {
        [self ico_showAlert:@"Import Failed" message:@"Could not write the settings file."];
        return;
    }
    [self ico_reloadList];
    
    NSMutableArray<NSString *> *lines = [NSMutableArray array];
    if (state) [lines addObject:@"Icon layout imported."];
    if (added) [lines addObject:[NSString stringWithFormat:@"%lu backup(s) added.", (unsigned long)added]];
    if (!lines.count) [lines addObject:@"Nothing new to import."];
    
    if (state) {
        [lines addObject:@"Respring now to apply the layout?"];
        [self ico_promptRespringWithTitle:@"Import Complete" message:[lines componentsJoinedByString:@"\n"]];
    } else {
        [self ico_showAlert:@"Import Complete" message:[lines componentsJoinedByString:@"\n"]];
    }
}

#pragma mark - Header
- (void)loadView {
    [super loadView];
    UINavigationItem *navigationItem = self.navigationItem;
    // Right button
    self.respringButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.respringButton setTitle:@"Respring" forState:UIControlStateNormal];
    self.respringButton.titleLabel.font = [UIFont systemFontOfSize:17];
    [self.respringButton addTarget:self action:@selector(respring) forControlEvents:UIControlEventTouchUpInside];
    
    UIBarButtonItem *rightBarButton = [[UIBarButtonItem alloc] initWithCustomView:self.respringButton];
    [navigationItem setRightBarButtonItem:rightBarButton];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    if (self.class == IconOrderController.class) {
        [self setupHeader];
    }
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    
    if (self.class == IconOrderController.class) {
        [self ico_updateHeaderLayout];
    }
}

- (void)setupHeader {
    if (!self.navigationItem.titleView) {
        UIImage *icon = [UIImage imageNamed:@"Icon" inBundle:[NSBundle bundleForClass:self.class]];
        if (icon) {
            self.navigationItem.titleView = [[ICOIconImageView alloc] initWithImage:icon];
        }
    }
    
    if (!self.ico_headerView) {
        self.ico_headerView = [[ICOHeaderView alloc] init];
    }
    if (self.table.tableHeaderView != self.ico_headerView) {
        self.table.tableHeaderView = self.ico_headerView;
    }
    [self ico_updateHeaderLayout];
}

// The header height depends on the subtitle text (line breaks) and the table width.
- (void)ico_updateHeaderLayout {
    ICOHeaderView *header = self.ico_headerView;
    CGFloat width = CGRectGetWidth(self.table.bounds);
    if (!header || width <= 0) return;
    
    CGFloat height = [header heightForWidth:width];
    if (fabs(CGRectGetWidth(header.frame) - width) > 0.5 || fabs(CGRectGetHeight(header.frame) - height) > 0.5) {
        header.frame = CGRectMake(0, 0, width, height);
        self.table.tableHeaderView = header; // re-assign so the table picks up the new height
    }
}

@end
