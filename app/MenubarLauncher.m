// Menubar Launcher
// A menu bar icon that lists named shell commands from ~/.config/menubar-launcher/menu.conf.
// The file is read again every time the menu opens, so edits show up without restarting the app.
// Choosing an item runs its command and does not wait for it; a non-zero exit shows a notification.
// Bringing an already open window to the front is left to each command (`cursor <folder>`, `open -a <app>`).
#import <AppKit/AppKit.h>
#import <UserNotifications/UserNotifications.h>

static NSString *const kDefaultPath = @"/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin";

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

// Parses the config into @{path, entries}. Each entry is @{kind: section|separator|item|error, ...}.
//   PATH=<dirs>        PATH for every command (LaunchAgents don't read .zshrc)
//   [Title]            section header
//   ---                separator
//   name = command     menu item; the command may contain `=`
//   # comment          ignored, as are blank lines
static NSDictionary *ParseConfig(NSString *text) {
    NSString *path = kDefaultPath;
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
        } else if (key.length && value.length) {
            [entries addObject:@{@"kind": @"item", @"name": key, @"command": ExpandTilde(value)}];
        } else {
            [entries addObject:@{@"kind": @"error", @"line": @(i + 1), @"text": line}];
        }
    }
    return @{@"path": path, @"entries": entries};
}

// `MenubarLauncher --print [file]` shows how a config is read, for checking a file and for the tests.
static int PrintConfig(NSString *file) {
    NSString *text = [NSString stringWithContentsOfFile:file encoding:NSUTF8StringEncoding error:nil];
    if (!text) { fprintf(stderr, "cannot read %s\n", file.UTF8String); return 1; }
    NSDictionary *config = ParseConfig(text);
    int status = 0;
    printf("path\t%s\n", [config[@"path"] UTF8String]);
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
@end

@implementation AppDelegate {
    NSStatusItem *_statusItem;
    NSMutableSet<NSTask *> *_running;
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    _running = [NSMutableSet set];
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

- (void)menuNeedsUpdate:(NSMenu *)menu {
    [menu removeAllItems];
    NSString *text = [NSString stringWithContentsOfFile:ConfigPath() encoding:NSUTF8StringEncoding error:nil];
    if (!text) {
        [menu addItem:[self disabledItem:L(@"설정 파일이 없습니다", @"No config file")]];
    } else {
        NSDictionary *config = ParseConfig(text);
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
