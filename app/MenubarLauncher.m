// Menubar Launcher
// A menu bar icon that lists named shell commands from ~/.config/menubar-launcher/menu.conf.
// The file is read again every time the menu opens, so edits show up without restarting the app.
// Choosing an item runs its command and does not wait for it; a non-zero exit shows a notification.
// Bringing an already open window to the front is left to each command (`open -a Cursor <folder>`, `open -a <app>`).
// An optional global hot key (HOTKEY= in the file) opens the same menu at the mouse pointer.
#import <AppKit/AppKit.h>
#import <Carbon/Carbon.h>
#import <UserNotifications/UserNotifications.h>

static NSString *const kDefaultPath = @"/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin";

// Parses a hot key like `ctrl+cmd+L` into a Carbon key code and modifier mask.
// Keys are matched by position (ANSI layout), so the shortcut works with any input source, Korean included.
// Needs Command, Control or Option: Shift alone would swallow capital letters.
static BOOL ParseHotkey(NSString *spec, UInt32 *keyCode, UInt32 *modifiers, NSString **normalized) {
    static NSDictionary<NSString *, NSNumber *> *keys;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        keys = @{@"A": @(kVK_ANSI_A), @"B": @(kVK_ANSI_B), @"C": @(kVK_ANSI_C), @"D": @(kVK_ANSI_D), @"E": @(kVK_ANSI_E),
                 @"F": @(kVK_ANSI_F), @"G": @(kVK_ANSI_G), @"H": @(kVK_ANSI_H), @"I": @(kVK_ANSI_I), @"J": @(kVK_ANSI_J),
                 @"K": @(kVK_ANSI_K), @"L": @(kVK_ANSI_L), @"M": @(kVK_ANSI_M), @"N": @(kVK_ANSI_N), @"O": @(kVK_ANSI_O),
                 @"P": @(kVK_ANSI_P), @"Q": @(kVK_ANSI_Q), @"R": @(kVK_ANSI_R), @"S": @(kVK_ANSI_S), @"T": @(kVK_ANSI_T),
                 @"U": @(kVK_ANSI_U), @"V": @(kVK_ANSI_V), @"W": @(kVK_ANSI_W), @"X": @(kVK_ANSI_X), @"Y": @(kVK_ANSI_Y),
                 @"Z": @(kVK_ANSI_Z), @"0": @(kVK_ANSI_0), @"1": @(kVK_ANSI_1), @"2": @(kVK_ANSI_2), @"3": @(kVK_ANSI_3),
                 @"4": @(kVK_ANSI_4), @"5": @(kVK_ANSI_5), @"6": @(kVK_ANSI_6), @"7": @(kVK_ANSI_7), @"8": @(kVK_ANSI_8),
                 @"9": @(kVK_ANSI_9), @"SPACE": @(kVK_Space)};
    });
    NSDictionary<NSString *, NSNumber *> *mods = @{@"CMD": @(cmdKey), @"COMMAND": @(cmdKey), @"SHIFT": @(shiftKey),
                                                   @"OPT": @(optionKey), @"OPTION": @(optionKey), @"ALT": @(optionKey),
                                                   @"CTRL": @(controlKey), @"CONTROL": @(controlKey)};
    NSArray *parts = [[spec uppercaseString] componentsSeparatedByString:@"+"];
    UInt32 m = 0;
    NSNumber *key = nil;
    NSString *keyName = nil;
    for (NSString *raw in parts) {
        NSString *p = [raw stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
        if (mods[p]) {
            m |= mods[p].unsignedIntValue;
        } else if (keys[p] && !key) {
            key = keys[p];
            keyName = [p isEqual:@"SPACE"] ? @"space" : p;
        } else {
            return NO;
        }
    }
    if (!key || !(m & (cmdKey | controlKey | optionKey))) return NO;
    NSMutableString *n = [NSMutableString string];
    if (m & controlKey) [n appendString:@"ctrl+"];
    if (m & optionKey) [n appendString:@"opt+"];
    if (m & shiftKey) [n appendString:@"shift+"];
    if (m & cmdKey) [n appendString:@"cmd+"];
    [n appendString:keyName];
    *keyCode = key.unsignedIntValue;
    *modifiers = m;
    *normalized = n;
    return YES;
}

static BOOL Korean(void) {
    return [NSLocale.preferredLanguages.firstObject hasPrefix:@"ko"];
}

static NSString *L(NSString *ko, NSString *en) {
    return Korean() ? ko : en;
}

static NSString *Home(void) {
    const char *home = getenv("HOME");
    return home && *home ? @(home) : NSHomeDirectory();
}

static NSString *ConfigPath(void) {
    return [Home() stringByAppendingPathComponent:@".config/menubar-launcher/menu.conf"];
}

// Expands a `~` that starts a word (after a space, `=`, `:` or a quote) and is followed by `/` or ends the word.
// Unlike the shell, this also expands inside quotes, so `cursor "~/My Folder"` works.
static NSString *ExpandTilde(NSString *s) {
    static NSRegularExpression *re;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        re = [NSRegularExpression regularExpressionWithPattern:@"(?<![^\\s=:'\"])~(?=[/\\s'\":]|$)" options:0 error:nil];
    });
    return [re stringByReplacingMatchesInString:s options:0 range:NSMakeRange(0, s.length)
                                   withTemplate:[NSRegularExpression escapedTemplateForString:Home()]];
}

// Parses the config into @{path, entries[, hotkey, hotkeyCode, hotkeyMods]}.
// Each entry is @{kind: section|separator|item|error, ...}.
//   PATH=<dirs>        PATH for every command (LaunchAgents don't read .zshrc)
//   HOTKEY=<keys>      global shortcut that opens the menu at the mouse pointer, e.g. ctrl+cmd+L
//   [Title]            section header
//   ---                separator
//   name = command     menu item; the command may contain `=`
//   # comment          ignored, as are blank lines
static NSDictionary *ParseConfig(NSString *text) {
    NSString *path = kDefaultPath;
    NSDictionary *hotkey = @{};
    NSMutableArray *entries = [NSMutableArray array];
    NSCharacterSet *ws = NSCharacterSet.whitespaceCharacterSet;
    NSArray *lines = [text componentsSeparatedByCharactersInSet:NSCharacterSet.newlineCharacterSet];
    for (NSUInteger i = 0; i < lines.count; i++) {
        NSString *line = [lines[i] stringByTrimmingCharactersInSet:ws];
        if (line.length == 0 || [line hasPrefix:@"#"]) continue;
        if ([line stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"-"]].length == 0 &&
            line.length >= 3) {
            [entries addObject:@{@"kind": @"separator"}];
            continue;
        }
        if ([line hasPrefix:@"["] && [line hasSuffix:@"]"] && line.length > 2) {
            NSString *title = [[line substringWithRange:NSMakeRange(1, line.length - 2)] stringByTrimmingCharactersInSet:ws];
            [entries addObject:@{@"kind": @"section", @"title": title}];
            continue;
        }
        NSRange eq = [line rangeOfString:@"="];
        NSString *key = eq.location == NSNotFound ? @"" : [[line substringToIndex:eq.location] stringByTrimmingCharactersInSet:ws];
        NSString *value = eq.location == NSNotFound ? @"" : [[line substringFromIndex:NSMaxRange(eq)] stringByTrimmingCharactersInSet:ws];
        if ([key isEqual:@"PATH"]) {
            path = value.length ? ExpandTilde(value) : kDefaultPath;
        } else if ([key isEqual:@"HOTKEY"]) {
            UInt32 code, mods;
            NSString *normalized;
            if (!value.length) {
                hotkey = @{};
            } else if (ParseHotkey(value, &code, &mods, &normalized)) {
                hotkey = @{@"hotkey": normalized, @"hotkeyCode": @(code), @"hotkeyMods": @(mods)};
            } else {
                [entries addObject:@{@"kind": @"error", @"line": @(i + 1), @"text": line}];
            }
        } else if (key.length && value.length) {
            [entries addObject:@{@"kind": @"item", @"name": key, @"command": ExpandTilde(value)}];
        } else {
            [entries addObject:@{@"kind": @"error", @"line": @(i + 1), @"text": line}];
        }
    }
    NSMutableDictionary *config = [hotkey mutableCopy];
    config[@"path"] = path;
    config[@"entries"] = entries;
    return config;
}

// `MenubarLauncher --print [file]` shows how a config is read, for checking a file and for the tests.
static int PrintConfig(NSString *file) {
    NSString *text = [NSString stringWithContentsOfFile:file encoding:NSUTF8StringEncoding error:nil];
    if (!text) { fprintf(stderr, "cannot read %s\n", file.UTF8String); return 1; }
    NSDictionary *config = ParseConfig(text);
    int status = 0;
    printf("path\t%s\n", [config[@"path"] UTF8String]);
    if (config[@"hotkey"]) printf("hotkey\t%s\n", [config[@"hotkey"] UTF8String]);
    for (NSDictionary *e in config[@"entries"]) {
        NSString *kind = e[@"kind"];
        if ([kind isEqual:@"section"]) printf("section\t%s\n", [e[@"title"] UTF8String]);
        else if ([kind isEqual:@"separator"]) printf("separator\n");
        else if ([kind isEqual:@"item"]) printf("item\t%s\t%s\n", [e[@"name"] UTF8String], [e[@"command"] UTF8String]);
        else { printf("error\t%ld\t%s\n", [e[@"line"] longValue], [e[@"text"] UTF8String]); status = 2; }
    }
    return status;
}

// Uses Notification Center when the app is allowed to post, and falls back to osascript otherwise.
static void Notify(NSString *title, NSString *body) {
    UNUserNotificationCenter *center = UNUserNotificationCenter.currentNotificationCenter;
    [center getNotificationSettingsWithCompletionHandler:^(UNNotificationSettings *settings) {
        if (settings.authorizationStatus == UNAuthorizationStatusAuthorized ||
            settings.authorizationStatus == UNAuthorizationStatusProvisional) {
            UNMutableNotificationContent *content = [UNMutableNotificationContent new];
            content.title = title;
            content.body = body;
            [center addNotificationRequest:[UNNotificationRequest requestWithIdentifier:NSUUID.UUID.UUIDString
                                                                                content:content trigger:nil]
                     withCompletionHandler:nil];
            return;
        }
        NSTask *task = [NSTask new];
        task.executableURL = [NSURL fileURLWithPath:@"/usr/bin/osascript"];
        task.arguments = @[@"-e", @"on run argv", @"-e", @"display notification (item 2 of argv) with title (item 1 of argv)",
                           @"-e", @"end run", title, body];
        [task launchAndReturnError:nil];
    }];
}

@interface AppDelegate : NSObject <NSApplicationDelegate, NSMenuDelegate, UNUserNotificationCenterDelegate>
- (void)showMenuAtPointer;
@end

static OSStatus HotKeyPressed(EventHandlerCallRef next, EventRef event, void *delegate) {
    // Let the key event finish before the menu starts its own tracking loop.
    dispatch_async(dispatch_get_main_queue(), ^{ [(__bridge AppDelegate *)delegate showMenuAtPointer]; });
    return noErr;
}

@implementation AppDelegate {
    NSStatusItem *_statusItem;
    NSMutableSet<NSTask *> *_running;
    EventHotKeyRef _hotKeyRef;
    NSString *_hotkey;        // normalized spec currently registered, @"" when none
    NSString *_hotkeyError;
    NSDate *_configDate;
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    _running = [NSMutableSet set];
    _hotkey = @"";
    EventTypeSpec spec = {kEventClassKeyboard, kEventHotKeyPressed};
    InstallEventHandler(GetApplicationEventTarget(), HotKeyPressed, 1, &spec, (__bridge void *)self, NULL);
    // The hot key has to follow edits even if the menu is never opened, so watch the file's modification date.
    [self reloadHotkeyIfChanged];
    [NSTimer scheduledTimerWithTimeInterval:2 target:self selector:@selector(reloadHotkeyIfChanged) userInfo:nil repeats:YES];

    _statusItem = [NSStatusBar.systemStatusBar statusItemWithLength:NSVariableStatusItemLength];
    _statusItem.autosaveName = @"menubar-launcher";
    NSImage *icon = [NSImage imageWithSystemSymbolName:@"square.grid.2x2" accessibilityDescription:@"Menubar Launcher"];
    if (icon) {
        icon.template = YES;
        _statusItem.button.image = icon;
    } else {
        _statusItem.button.title = @"▦";
    }
    NSMenu *menu = [NSMenu new];
    menu.delegate = self;
    _statusItem.menu = menu;

    UNUserNotificationCenter *center = UNUserNotificationCenter.currentNotificationCenter;
    center.delegate = self;
    [center requestAuthorizationWithOptions:UNAuthorizationOptionAlert completionHandler:^(BOOL granted, NSError *error) {}];
}

// Show banners even while the app counts as frontmost (right after a menu click).
- (void)userNotificationCenter:(UNUserNotificationCenter *)center willPresentNotification:(UNNotification *)notification
         withCompletionHandler:(void (^)(UNNotificationPresentationOptions))completionHandler {
    completionHandler(UNNotificationPresentationOptionBanner | UNNotificationPresentationOptionList);
}

- (void)reloadHotkeyIfChanged {
    NSDate *date = [[NSFileManager.defaultManager attributesOfItemAtPath:ConfigPath() error:nil] fileModificationDate];
    if (date == _configDate || [date isEqual:_configDate]) return;
    _configDate = date;
    NSString *text = [NSString stringWithContentsOfFile:ConfigPath() encoding:NSUTF8StringEncoding error:nil];
    [self applyHotkey:text ? ParseConfig(text) : @{}];
}

- (void)applyHotkey:(NSDictionary *)config {
    NSString *spec = config[@"hotkey"] ?: @"";
    if ([spec isEqual:_hotkey]) return;
    if (_hotKeyRef) UnregisterEventHotKey(_hotKeyRef);
    _hotKeyRef = NULL;
    _hotkey = spec;
    _hotkeyError = nil;
    if (!spec.length) return;
    EventHotKeyID hotKeyID = {'mbln', 1};
    OSStatus status = RegisterEventHotKey([config[@"hotkeyCode"] unsignedIntValue], [config[@"hotkeyMods"] unsignedIntValue],
                                          hotKeyID, GetApplicationEventTarget(), 0, &_hotKeyRef);
    if (status != noErr) {
        _hotKeyRef = NULL;
        _hotkeyError = [NSString stringWithFormat:L(@"⚠︎ 단축키 %@를 등록하지 못함 (%d)", @"⚠︎ Could not register %@ (%d)"),
                        spec, (int)status];
    }
}

// The menu opens without activating the app, like a click on the icon, so the app in front keeps focus
// and arrow keys, typing the start of a name and Return all work.
- (void)showMenuAtPointer {
    [_statusItem.menu popUpMenuPositioningItem:nil atLocation:NSEvent.mouseLocation inView:nil];
}

- (void)menuNeedsUpdate:(NSMenu *)menu {
    [menu removeAllItems];
    NSString *text = [NSString stringWithContentsOfFile:ConfigPath() encoding:NSUTF8StringEncoding error:nil];
    if (!text) {
        [menu addItem:[self disabledItem:L(@"설정 파일이 없습니다", @"No config file")]];
    } else {
        NSDictionary *config = ParseConfig(text);
        [self applyHotkey:config];
        if (_hotkeyError) [menu addItem:[self disabledItem:_hotkeyError]];
        NSUInteger items = 0;
        for (NSDictionary *e in config[@"entries"]) {
            NSString *kind = e[@"kind"];
            if ([kind isEqual:@"section"]) {
                if (@available(macOS 14, *)) [menu addItem:[NSMenuItem sectionHeaderWithTitle:e[@"title"]]];
                else [menu addItem:[self disabledItem:e[@"title"]]];
            } else if ([kind isEqual:@"separator"]) {
                [menu addItem:NSMenuItem.separatorItem];
            } else if ([kind isEqual:@"item"]) {
                NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:e[@"name"] action:@selector(run:) keyEquivalent:@""];
                item.target = self;
                item.toolTip = e[@"command"];
                item.representedObject = @{@"name": e[@"name"], @"command": e[@"command"], @"path": config[@"path"]};
                [menu addItem:item];
                items++;
            } else {
                [menu addItem:[self disabledItem:[NSString stringWithFormat:L(@"⚠︎ %@번째 줄을 읽을 수 없음: %@", @"⚠︎ Line %@ not understood: %@"),
                                                  e[@"line"], e[@"text"]]]];
            }
        }
        if (items == 0) [menu addItem:[self disabledItem:L(@"항목 없음", @"No items")]];
    }
    [menu addItem:NSMenuItem.separatorItem];
    NSMenuItem *edit = [[NSMenuItem alloc] initWithTitle:L(@"목록 편집…", @"Edit List…") action:@selector(edit) keyEquivalent:@""];
    edit.target = self;
    [menu addItem:edit];
    [menu addItem:[[NSMenuItem alloc] initWithTitle:L(@"종료", @"Quit") action:@selector(terminate:) keyEquivalent:@""]];
}

- (NSMenuItem *)disabledItem:(NSString *)title {
    NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:title action:nil keyEquivalent:@""];
    item.enabled = NO;
    return item;
}

- (void)run:(NSMenuItem *)sender {
    NSDictionary *item = sender.representedObject;
    NSString *name = item[@"name"];
    NSTask *task = [NSTask new];
    task.executableURL = [NSURL fileURLWithPath:@"/bin/sh"];
    task.arguments = @[@"-c", item[@"command"]];
    NSMutableDictionary *env = [NSProcessInfo.processInfo.environment mutableCopy];
    env[@"PATH"] = item[@"path"];
    task.environment = env;
    task.currentDirectoryURL = [NSURL fileURLWithPath:Home()];
    task.standardInput = NSFileHandle.fileHandleWithNullDevice;
    task.standardOutput = NSFileHandle.fileHandleWithNullDevice;

    // Keep draining stderr until EOF: an app the command starts may inherit the pipe and outlive the shell.
    NSPipe *pipe = [NSPipe pipe];
    task.standardError = pipe;
    NSMutableData *stderrData = [NSMutableData data];
    pipe.fileHandleForReading.readabilityHandler = ^(NSFileHandle *handle) {
        NSData *data = handle.availableData;
        if (data.length == 0) { handle.readabilityHandler = nil; return; }
        @synchronized (stderrData) { if (stderrData.length < 4096) [stderrData appendData:data]; }
    };

    task.terminationHandler = ^(NSTask *t) {
        int status = t.terminationStatus;
        BOOL failed = t.terminationReason != NSTaskTerminationReasonExit || status != 0;
        // A short wait lets the last stderr bytes arrive before the message is built.
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self->_running removeObject:t];
            if (!failed) return;
            NSString *err;
            @synchronized (stderrData) {
                err = [[NSString alloc] initWithData:stderrData encoding:NSUTF8StringEncoding] ?: @"";
            }
            err = [err stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
            NSString *body = [NSString stringWithFormat:L(@"종료 코드 %d", @"Exit code %d"), status];
            if (err.length) body = [body stringByAppendingFormat:@"\n%@", err];
            Notify([NSString stringWithFormat:L(@"실행 실패: %@", @"Failed: %@"), name], body);
        });
    };

    NSError *error;
    if ([task launchAndReturnError:&error]) {
        [_running addObject:task];
    } else {
        Notify([NSString stringWithFormat:L(@"실행 실패: %@", @"Failed: %@"), name], error.localizedDescription);
    }
}

- (void)edit {
    NSString *file = ConfigPath();
    if (![NSFileManager.defaultManager fileExistsAtPath:file]) {
        [NSFileManager.defaultManager createDirectoryAtPath:file.stringByDeletingLastPathComponent
                                withIntermediateDirectories:YES attributes:nil error:nil];
        [@"# name = shell command  (see menu.conf.example in the menubar-launcher repository)\n"
            writeToFile:file atomically:YES encoding:NSUTF8StringEncoding error:nil];
    }
    NSTask *task = [NSTask new];
    task.executableURL = [NSURL fileURLWithPath:@"/usr/bin/open"];
    task.arguments = @[@"-t", file];
    [task launchAndReturnError:nil];
}

@end

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        if (argc >= 2 && strcmp(argv[1], "--print") == 0) {
            return PrintConfig(argc >= 3 ? @(argv[2]) : ConfigPath());
        }
        NSApplication *app = NSApplication.sharedApplication;
        AppDelegate *delegate = [AppDelegate new];
        app.delegate = delegate;
        [app setActivationPolicy:NSApplicationActivationPolicyAccessory];
        [app run];
    }
    return 0;
}
