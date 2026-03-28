// scribe_platform_bridge.m — Scribe app-level ObjC/Carbon bridge
//
// Provides:
//   1. NSApplication/NSWindow lifecycle (Asset Pipeline doesn't cover this)
//   2. NSStatusItem menu bar integration
//   3. Global keyboard shortcuts via Carbon RegisterEventHotKey
//
// Compile with:
//   clang -c src/platform/macos/ext/scribe_platform_bridge.m \
//     -o src/platform/macos/ext/scribe_platform_bridge.o -fno-objc-arc

#import <AppKit/AppKit.h>
#import <Carbon/Carbon.h>
#import <ApplicationServices/ApplicationServices.h>
#import <CoreServices/CoreServices.h>
#import <UserNotifications/UserNotifications.h>
#import <ServiceManagement/ServiceManagement.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#include <whisper.h>

// ============================================================================
// Section 1: Application Lifecycle
// ============================================================================

void *scribe_shared_application(void) {
    return (void *)[NSApplication sharedApplication];
}

void scribe_set_activation_policy_regular(void *app) {
    [(NSApplication *)app setActivationPolicy:NSApplicationActivationPolicyRegular];
}

void scribe_set_activation_policy_accessory(void *app) {
    [(NSApplication *)app setActivationPolicy:NSApplicationActivationPolicyAccessory];
}

void scribe_activate_app(void *app) {
    NSApplication *nsApp = (NSApplication *)app;
    // On macOS 14+, activate is the correct API. But for menu bar apps that
    // start as accessory, we need to also bring windows to front explicitly.
    [nsApp activate];
    // Force the app to the front by making it the active app
    [[NSRunningApplication currentApplication]
        activateWithOptions:NSApplicationActivateAllWindows |
                           NSApplicationActivateIgnoringOtherApps];
}

void scribe_run_app(void *app) {
    [(NSApplication *)app run];
}

// Bring a window to front after the run loop has started.
// Uses dispatch_async on the main queue so it fires on the NEXT run loop
// iteration — guaranteed to be after NSApp.run() has begun processing events.
void scribe_bring_window_to_front_async(void *window) {
    NSWindow *win = (NSWindow *)window;
    dispatch_async(dispatch_get_main_queue(), ^{
        NSApplication *app = [NSApplication sharedApplication];
        [app setActivationPolicy:NSApplicationActivationPolicyRegular];
        [win makeKeyAndOrderFront:nil];
        [app activate];
        [[NSRunningApplication currentApplication]
            activateWithOptions:NSApplicationActivateAllWindows |
                               NSApplicationActivateIgnoringOtherApps];
    });
}

void scribe_terminate_app(void *app) {
    [(NSApplication *)app terminate:nil];
}

// ============================================================================
// Section 2: NSWindow
// ============================================================================

void *scribe_create_window(double x, double y, double w, double h,
                           unsigned long style_mask) {
    NSWindow *window = [[NSWindow alloc]
        initWithContentRect:NSMakeRect(x, y, w, h)
                  styleMask:style_mask
                    backing:NSBackingStoreBuffered
                      defer:NO];
    return (void *)window;
}

void scribe_set_window_title(void *window, const char *title) {
    [(NSWindow *)window setTitle:[NSString stringWithUTF8String:title]];
}

// Set window level. Use NSFloatingWindowLevel (3) for above-normal,
// NSNormalWindowLevel (0) for standard, NSStatusWindowLevel (25) for always-on-top.
void scribe_set_window_level(void *window, int level) {
    [(NSWindow *)window setLevel:(NSWindowLevel)level];
}

void scribe_set_content_view(void *window, void *view) {
    [(NSWindow *)window setContentView:(NSView *)view];
}

void scribe_center_window(void *window) {
    [(NSWindow *)window center];
}

void scribe_make_key_and_order_front(void *window) {
    NSWindow *win = (NSWindow *)window;
    [win makeKeyAndOrderFront:nil];
    // Set focus to the content view so VoiceOver and Tab navigation start there
    if ([win contentView]) {
        [win makeFirstResponder:[win contentView]];
    }
}

// Force a window in front of ALL other windows from ALL apps,
// even if the app is not active. This is the reliable way to show
// windows from menu bar / accessory apps.
void scribe_order_window_front_regardless(void *window) {
    NSWindow *win = (NSWindow *)window;
    [win orderFrontRegardless];
    [win makeKeyWindow];
    if ([win contentView]) {
        [win makeFirstResponder:[win contentView]];
    }
    // Also activate the app so it appears in Cmd+Tab
    NSApplication *app = [NSApplication sharedApplication];
    [app setActivationPolicy:NSApplicationActivationPolicyRegular];
    [app activate];
    [[NSRunningApplication currentApplication]
        activateWithOptions:NSApplicationActivateAllWindows |
                           NSApplicationActivateIgnoringOtherApps];
}

void scribe_close_window(void *window) {
    [(NSWindow *)window close];
}

void scribe_show_window(void *window) {
    [(NSWindow *)window makeKeyAndOrderFront:nil];
    [(NSApplication *)NSApp activateIgnoringOtherApps:YES];
}

// ============================================================================
// Section 2b: Recording Indicator Panel
// ============================================================================
//
// A small floating panel that appears at the top of the screen during recording.
// Always on top, semi-transparent dark background, shows status text.
// The user can drag it around. It never steals focus from other apps.

static NSTextField *g_indicator_label = nil;

void *scribe_create_recording_indicator(void) {
    NSPanel *panel = [[NSPanel alloc]
        initWithContentRect:NSMakeRect(0, 0, 300, 48)
                  styleMask:NSWindowStyleMaskBorderless | NSWindowStyleMaskNonactivatingPanel
                    backing:NSBackingStoreBuffered
                      defer:NO];

    [panel setLevel:NSStatusWindowLevel];
    [panel setOpaque:NO];
    [panel setBackgroundColor:[NSColor clearColor]];
    [panel setHasShadow:YES];
    [panel setMovableByWindowBackground:YES];
    [panel setCollectionBehavior:NSWindowCollectionBehaviorCanJoinAllSpaces |
                                 NSWindowCollectionBehaviorStationary];

    // Rounded dark background view
    NSView *content = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 300, 48)];
    content.wantsLayer = YES;
    content.layer.cornerRadius = 12;
    content.layer.masksToBounds = YES;
    content.layer.backgroundColor = [[NSColor colorWithCalibratedRed:0.15
                                                               green:0.15
                                                                blue:0.15
                                                               alpha:0.92] CGColor];
    [panel setContentView:content];

    // Recording dot + text label
    g_indicator_label = [[NSTextField alloc] initWithFrame:NSMakeRect(16, 10, 268, 28)];
    [g_indicator_label setStringValue:@"\xF0\x9F\x94\xB4 Recording \xE2\x80\x94 \xE2\x8C\xA5\xE2\x87\xA7R to stop"];
    [g_indicator_label setBezeled:NO];
    [g_indicator_label setDrawsBackground:NO];
    [g_indicator_label setEditable:NO];
    [g_indicator_label setSelectable:NO];
    [g_indicator_label setTextColor:[NSColor whiteColor]];
    [g_indicator_label setFont:[NSFont systemFontOfSize:15 weight:NSFontWeightMedium]];
    [g_indicator_label setAlignment:NSTextAlignmentCenter];
    // Accessibility: announce recording status to VoiceOver
    [g_indicator_label setAccessibilityRole:NSAccessibilityStaticTextRole];
    [g_indicator_label setAccessibilityLabel:@"Recording Status"];
    [content addSubview:g_indicator_label];

    // Position at top-center of main screen
    NSRect screen = [[NSScreen mainScreen] visibleFrame];
    NSRect frame = [panel frame];
    frame.origin.x = screen.origin.x + (screen.size.width - frame.size.width) / 2;
    frame.origin.y = screen.origin.y + screen.size.height - frame.size.height - 8;
    [panel setFrame:frame display:NO];

    return (void *)panel;
}

void scribe_show_recording_indicator(void *window) {
    [(NSPanel *)window orderFront:nil];
}

void scribe_hide_recording_indicator(void *window) {
    [(NSPanel *)window orderOut:nil];
}

void scribe_update_recording_indicator_text(void *window, const char *text) {
    if (g_indicator_label) {
        NSString *nsText = [NSString stringWithUTF8String:text];
        [g_indicator_label setStringValue:nsText];
        // Announce status change to VoiceOver
        NSAccessibilityPostNotification(g_indicator_label,
            NSAccessibilityValueChangedNotification);
        // Also post an announcement for screen readers
        NSDictionary *info = @{
            NSAccessibilityAnnouncementKey: nsText,
            NSAccessibilityPriorityKey: @(NSAccessibilityPriorityHigh)
        };
        NSAccessibilityPostNotification(
            [NSApplication sharedApplication],
            NSAccessibilityAnnouncementRequestedNotification);
    }
}

// ============================================================================
// Section 3: NSStatusItem (Menu Bar)
// ============================================================================

void *scribe_create_status_item(void) {
    NSStatusBar *bar = [NSStatusBar systemStatusBar];
    NSStatusItem *item = [bar statusItemWithLength:NSVariableStatusItemLength];
    return (void *)item;
}

void scribe_set_status_item_title(void *item, const char *title) {
    [[(NSStatusItem *)item button] setTitle:[NSString stringWithUTF8String:title]];
}

void scribe_set_status_item_image(void *item, const char *system_name) {
    NSImage *image = [NSImage imageWithSystemSymbolName:
        [NSString stringWithUTF8String:system_name]
        accessibilityDescription:@"Scribe"];
    if (image) {
        [image setTemplate:YES];
        [[(NSStatusItem *)item button] setImage:image];
    }
}

// ============================================================================
// Section 4: NSMenu
// ============================================================================

void *scribe_create_menu(const char *title) {
    NSMenu *menu = [[NSMenu alloc] initWithTitle:[NSString stringWithUTF8String:title]];
    return (void *)menu;
}

void scribe_set_status_item_menu(void *item, void *menu) {
    [(NSStatusItem *)item setMenu:(NSMenu *)menu];
}

void *scribe_add_menu_item(void *menu, const char *title, const char *key) {
    NSMenuItem *item = [[NSMenuItem alloc]
        initWithTitle:[NSString stringWithUTF8String:title]
               action:nil
        keyEquivalent:[NSString stringWithUTF8String:key]];
    [(NSMenu *)menu addItem:item];
    return (void *)item;
}

void scribe_add_menu_separator(void *menu) {
    [(NSMenu *)menu addItem:[NSMenuItem separatorItem]];
}

void scribe_set_menu_item_action(void *item, void *sel) {
    [(NSMenuItem *)item setAction:(SEL)sel];
}

void scribe_set_menu_item_target(void *item, void *target) {
    [(NSMenuItem *)item setTarget:(id)target];
}

void scribe_set_menu_item_title(void *item, const char *title) {
    [(NSMenuItem *)item setTitle:[NSString stringWithUTF8String:title]];
}

// ============================================================================
// Section 5: Menu Item Callback Target
// ============================================================================
//
// NSMenuItem requires a target+action pair to be enabled and clickable.
// This section provides a simple ObjC target that routes menu clicks
// back to a Crystal callback via a C function pointer.
// Each menu item is identified by its NSMenuItem tag (unsigned int).

typedef void (*menu_item_callback_fn)(unsigned int item_tag);
static menu_item_callback_fn g_menu_callback = NULL;

@interface ScribeMenuTarget : NSObject
- (void)menuItemClicked:(NSMenuItem *)sender;
@end

@implementation ScribeMenuTarget
- (void)menuItemClicked:(NSMenuItem *)sender {
    if (g_menu_callback != NULL) {
        g_menu_callback((unsigned int)[sender tag]);
    }
}
@end

static ScribeMenuTarget *g_menu_target = nil;

void scribe_install_menu_callback(menu_item_callback_fn callback) {
    g_menu_callback = callback;
    if (g_menu_target == nil) {
        g_menu_target = [[ScribeMenuTarget alloc] init];
    }
}

void *scribe_get_menu_target(void) {
    if (g_menu_target == nil) {
        g_menu_target = [[ScribeMenuTarget alloc] init];
    }
    return (void *)g_menu_target;
}

void scribe_set_menu_item_tag(void *item, unsigned int tag) {
    [(NSMenuItem *)item setTag:(NSInteger)tag];
}

// ============================================================================
// Section 6: Global Keyboard Shortcuts (Carbon API)
// ============================================================================
//
// Carbon RegisterEventHotKey works on modern macOS without Accessibility
// permission. Hotkey events are dispatched through the CFRunLoop which
// [NSApp run] already manages.

typedef void (*hotkey_callback_fn)(unsigned int hotkey_id);
static hotkey_callback_fn g_hotkey_callback = NULL;

static OSStatus hotkey_event_handler(EventHandlerCallRef next, EventRef event, void *user_data) {
    EventHotKeyID hotkey_id;
    OSStatus err = GetEventParameter(event, kEventParamDirectObject,
                                      typeEventHotKeyID, NULL,
                                      sizeof(hotkey_id), NULL, &hotkey_id);
    if (err == noErr && g_hotkey_callback != NULL) {
        g_hotkey_callback(hotkey_id.id);
    }
    return noErr;
}

int scribe_hotkey_install_handler(hotkey_callback_fn callback) {
    g_hotkey_callback = callback;

    EventTypeSpec event_type;
    event_type.eventClass = kEventClassKeyboard;
    event_type.eventKind = kEventHotKeyPressed;

    OSStatus err = InstallApplicationEventHandler(
        &hotkey_event_handler, 1, &event_type, NULL, NULL);
    return (int)err;
}

// Register a global hotkey
// modifier_flags: cmdKey=0x100, shiftKey=0x200, optionKey=0x800, controlKey=0x1000
// key_code: Carbon virtual key code (e.g., kVK_ANSI_R = 0x0F)
int scribe_hotkey_register(unsigned int hotkey_id, unsigned int modifier_flags,
                           unsigned int key_code, void **out_ref) {
    EventHotKeyID hk_id;
    hk_id.signature = 'SCRB';
    hk_id.id = hotkey_id;

    EventHotKeyRef ref;
    OSStatus err = RegisterEventHotKey(
        key_code, modifier_flags, hk_id,
        GetApplicationEventTarget(), 0, &ref);

    if (out_ref) *out_ref = (void *)ref;
    return (int)err;
}

int scribe_hotkey_unregister(void *ref) {
    return (int)UnregisterEventHotKey((EventHotKeyRef)ref);
}

// ============================================================================
// Section 7: GCD Async Work Dispatch
// ============================================================================
//
// Crystal's spawn/sleep don't work under [NSApp run] because the fiber
// scheduler never gets ticked (GAP-19). This provides a generic mechanism
// to run a Crystal function on a GCD background thread and call back on
// the main thread when done.
//
// CRITICAL (GAP-20): Crystal uses Boehm GC which doesn't know about GCD
// worker threads. Running Crystal code on a GCD thread without registering
// it first causes SIGSEGV in GC_get_my_stackbottom when Crystal tries to
// set up Thread/Fiber state. We must call GC_register_my_thread before
// invoking Crystal callbacks on GCD threads.

// Boehm GC thread registration — Crystal links against bdw-gc
struct GC_stack_base { void *mem_base; };
extern int GC_get_stack_base(struct GC_stack_base *);
extern int GC_register_my_thread(const struct GC_stack_base *);
extern int GC_unregister_my_thread(void);
extern void GC_allow_register_threads(void);

static int g_gc_threads_allowed = 0;

typedef void (*background_work_fn)(void);
typedef void (*main_thread_callback_fn)(void);

void scribe_dispatch_background(background_work_fn work, main_thread_callback_fn callback) {
    // Enable foreign thread registration (must be called once from main thread)
    if (!g_gc_threads_allowed) {
        GC_allow_register_threads();
        g_gc_threads_allowed = 1;
    }

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        // Register this GCD worker thread with Boehm GC so Crystal can
        // safely allocate, create Fibers, and access thread-local state.
        struct GC_stack_base sb;
        GC_get_stack_base(&sb);
        GC_register_my_thread(&sb);

        if (work) work();

        GC_unregister_my_thread();

        dispatch_async(dispatch_get_main_queue(), ^{
            if (callback) callback();
        });
    });
}

// ============================================================================
// Section 8: Clipboard (NSPasteboard + CGEvent paste simulation)
// ============================================================================

// Read clipboard text. Returns malloc'd UTF-8 string (caller must free via
// scribe_clipboard_free). Returns NULL if clipboard is empty or non-text.
const char *scribe_clipboard_read(void) {
    @autoreleasepool {
        NSPasteboard *pb = [NSPasteboard generalPasteboard];
        NSString *text = [pb stringForType:NSPasteboardTypeString];
        if (!text) return NULL;
        const char *utf8 = [text UTF8String];
        if (!utf8) return NULL;
        return strdup(utf8);
    }
}

// Write text to clipboard. Returns 0 on success, -1 on failure.
int scribe_clipboard_write(const char *text) {
    if (!text) return -1;
    @autoreleasepool {
        NSPasteboard *pb = [NSPasteboard generalPasteboard];
        [pb clearContents];
        NSString *nsText = [NSString stringWithUTF8String:text];
        if (!nsText) return -1;
        BOOL ok = [pb setString:nsText forType:NSPasteboardTypeString];
        return ok ? 0 : -1;
    }
}

// Free a string returned by scribe_clipboard_read.
void scribe_clipboard_free(const char *ptr) {
    free((void *)ptr);
}

// ============================================================================
// Section 9: Accessibility Permission Check
// ============================================================================
//
// CGEvent paste simulation requires Accessibility permission.
// AXIsProcessTrusted() checks without prompting.
// AXIsProcessTrustedWithOptions() can show the system permission dialog.

// Check if Accessibility permission is granted.
// If prompt=1, shows the system permission dialog if not yet granted.
// Returns 1 if trusted, 0 if not.
int scribe_accessibility_check(int prompt) {
    if (prompt) {
        NSDictionary *options = @{
            (__bridge NSString *)kAXTrustedCheckOptionPrompt: @YES
        };
        return AXIsProcessTrustedWithOptions((__bridge CFDictionaryRef)options) ? 1 : 0;
    }
    return AXIsProcessTrusted() ? 1 : 0;
}

// ============================================================================
// Section 10: Clipboard Paste Cycle (GCD-timed, non-blocking)
// ============================================================================
//
// Full paste cycle with proper timing via GCD dispatch_after:
//   1. Save current clipboard
//   2. Write transcript text to clipboard
//   3. Wait 50ms (dispatch_after) for clipboard to settle
//   4. Simulate Cmd+V paste via CGEvent
//   5. Wait 500ms (dispatch_after) for target app to consume
//   6. Restore original clipboard
//   7. Call completion callback
//
// IMPORTANT: Crystal's sleep() uses the fiber scheduler, which NSApp's
// run loop doesn't pump. All timing MUST go through GCD dispatch_after
// to work correctly within the CFRunLoop.

typedef void (*paste_cycle_callback_fn)(int success);
static paste_cycle_callback_fn g_paste_cycle_callback = NULL;

void scribe_install_paste_cycle_callback(paste_cycle_callback_fn callback) {
    g_paste_cycle_callback = callback;
}

void scribe_clipboard_paste_cycle(const char *text) {
    if (!text) {
        NSLog(@"[Scribe:paste] ERROR: null text passed");
        if (g_paste_cycle_callback) g_paste_cycle_callback(0);
        return;
    }

    // Check Accessibility permission (with prompt if not granted)
    BOOL trusted = AXIsProcessTrusted();
    NSLog(@"[Scribe:paste] AXIsProcessTrusted = %@", trusted ? @"YES" : @"NO");

    if (!trusted) {
        NSDictionary *options = @{
            (__bridge NSString *)kAXTrustedCheckOptionPrompt: @YES
        };
        BOOL afterPrompt = AXIsProcessTrustedWithOptions((__bridge CFDictionaryRef)options);
        NSLog(@"[Scribe:paste] AXIsProcessTrustedWithOptions (prompted) = %@",
              afterPrompt ? @"YES" : @"NO");
        NSLog(@"[Scribe:paste] Accessibility not granted — writing to clipboard only (user must Cmd+V)");
        // Still write to clipboard so user can paste manually
        NSPasteboard *pb = [NSPasteboard generalPasteboard];
        [pb clearContents];
        [pb setString:[NSString stringWithUTF8String:text] forType:NSPasteboardTypeString];
        NSLog(@"[Scribe:paste] Transcript written to clipboard");
        if (g_paste_cycle_callback) g_paste_cycle_callback(0);
        return;
    }

    // Step 1: Save current clipboard
    NSPasteboard *pb = [NSPasteboard generalPasteboard];
    NSString *saved = [pb stringForType:NSPasteboardTypeString] ?: @"";
    NSLog(@"[Scribe:paste] Step 1: Saved clipboard (%lu chars)", (unsigned long)[saved length]);

    // Step 2: Write transcript to clipboard
    [pb clearContents];
    NSString *nsText = [NSString stringWithUTF8String:text];
    BOOL writeOk = [pb setString:nsText forType:NSPasteboardTypeString];
    NSLog(@"[Scribe:paste] Step 2: Write transcript to clipboard = %@", writeOk ? @"OK" : @"FAILED");
    if (!writeOk) {
        if (g_paste_cycle_callback) g_paste_cycle_callback(0);
        return;
    }

    // Step 3: Wait 50ms for clipboard to settle, then paste
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 50 * NSEC_PER_MSEC),
                   dispatch_get_main_queue(), ^{
        // Step 4: Simulate Cmd+V
        NSLog(@"[Scribe:paste] Step 4: Simulating Cmd+V...");
        CGKeyCode v_keycode = 0x09; // kVK_ANSI_V
        CGEventRef key_down = CGEventCreateKeyboardEvent(NULL, v_keycode, true);
        CGEventRef key_up = CGEventCreateKeyboardEvent(NULL, v_keycode, false);

        if (key_down && key_up) {
            CGEventSetFlags(key_down, kCGEventFlagMaskCommand);
            CGEventSetFlags(key_up, kCGEventFlagMaskCommand);
            CGEventPost(kCGHIDEventTap, key_down);
            CGEventPost(kCGHIDEventTap, key_up);
            CFRelease(key_down);
            CFRelease(key_up);
            NSLog(@"[Scribe:paste] Step 4: CGEventPost completed (events posted)");
        } else {
            NSLog(@"[Scribe:paste] Step 4: FAILED to create CGEvent (key_down=%p key_up=%p)",
                  key_down, key_up);
        }

        // Step 5: Wait 500ms for target app to process paste, then restore
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 500 * NSEC_PER_MSEC),
                       dispatch_get_main_queue(), ^{
            // Step 6: Restore original clipboard
            NSPasteboard *pb2 = [NSPasteboard generalPasteboard];
            [pb2 clearContents];
            [pb2 setString:saved forType:NSPasteboardTypeString];
            NSLog(@"[Scribe:paste] Step 6: Clipboard restored");

            // Step 7: Callback
            if (g_paste_cycle_callback) g_paste_cycle_callback(1);
        });
    });
}

// ============================================================================
// Section 11: Whisper Transcription Wrapper (GAP-21: struct layout mismatch)
// ============================================================================
//
// Crystal's LibWhisper::FullParams struct is missing fields vs whisper.h 1.8.3
// (logits_filter_callback + user_data = 16 bytes). Passing a mismatched struct
// by value to whisper_full causes SIGSEGV. This C wrapper builds FullParams
// with guaranteed-correct layout so Crystal never touches the struct directly.
//
// Returns malloc'd UTF-8 string with all segments concatenated.
// Caller must free with scribe_whisper_free_result().

char *scribe_whisper_transcribe(struct whisper_context *ctx,
                                const float *samples,
                                int n_samples,
                                const char *language,
                                int n_threads) {
    if (!ctx || !samples || n_samples <= 0) return NULL;

    struct whisper_full_params params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY);
    params.n_threads      = n_threads;
    params.language       = language ? language : "en";
    params.translate      = false;
    params.no_context     = false;
    params.single_segment = false;
    params.print_progress = false;
    params.print_realtime = false;
    params.greedy.best_of = 5;

    int result = whisper_full(ctx, params, samples, n_samples);
    if (result != 0) {
        NSLog(@"[Scribe:whisper] whisper_full failed with code %d", result);
        return NULL;
    }

    int n_segments = whisper_full_n_segments(ctx);
    if (n_segments == 0) return strdup("");

    // Calculate total text length
    size_t total_len = 0;
    for (int i = 0; i < n_segments; i++) {
        const char *text = whisper_full_get_segment_text(ctx, i);
        if (text) total_len += strlen(text);
    }

    char *out = (char *)malloc(total_len + 1);
    if (!out) return NULL;

    out[0] = '\0';
    for (int i = 0; i < n_segments; i++) {
        const char *text = whisper_full_get_segment_text(ctx, i);
        if (text) strcat(out, text);
    }

    NSLog(@"[Scribe:whisper] Transcribed %d segments, %zu chars", n_segments, total_len);
    return out;
}

void scribe_whisper_free_result(char *text) {
    free(text);
}

// Wrapper for whisper context creation (avoids ContextParams struct mismatch too)
struct whisper_context *scribe_whisper_init(const char *model_path) {
    if (!model_path) return NULL;
    struct whisper_context_params params = whisper_context_default_params();
    params.use_gpu = true;
    struct whisper_context *ctx = whisper_init_from_file_with_params(model_path, params);
    if (ctx) {
        NSLog(@"[Scribe:whisper] Model loaded: %s", model_path);
    } else {
        NSLog(@"[Scribe:whisper] Failed to load model: %s", model_path);
    }
    return ctx;
}

void scribe_whisper_free(struct whisper_context *ctx) {
    if (ctx) whisper_free(ctx);
}

// ============================================================================
// Section 12: HTTP File Download (NSURLSession with progress)
// ============================================================================
//
// Downloads a file from a URL to a local path, reporting progress and
// completion via C function pointer callbacks. Uses NSURLSession's
// downloadTaskWithURL: with a delegate for progress reporting.
//
// Progress callback fires on main thread with (bytesWritten, totalBytes).
// Completion callback fires on main thread with (success, error_message).

typedef void (*download_progress_fn)(int64_t bytes_written, int64_t total_bytes);
typedef void (*download_completion_fn)(int32_t success, const char *error_message);

@interface ScribeDownloadDelegate : NSObject <NSURLSessionDownloadDelegate>
@property (nonatomic, copy) NSString *destinationPath;
@property (nonatomic, assign) download_progress_fn progressCallback;
@property (nonatomic, assign) download_completion_fn completionCallback;
@end

@implementation ScribeDownloadDelegate

- (void)URLSession:(NSURLSession *)session
      downloadTask:(NSURLSessionDownloadTask *)downloadTask
didFinishDownloadingToURL:(NSURL *)location {
    NSError *error = nil;
    NSFileManager *fm = [NSFileManager defaultManager];

    // Remove existing file if present (re-download case)
    if ([fm fileExistsAtPath:self.destinationPath]) {
        [fm removeItemAtPath:self.destinationPath error:nil];
    }

    // Move downloaded temp file to destination
    BOOL moved = [fm moveItemAtURL:location
                             toURL:[NSURL fileURLWithPath:self.destinationPath]
                             error:&error];

    if (moved) {
        NSLog(@"[Scribe:download] File saved to %@", self.destinationPath);
        dispatch_async(dispatch_get_main_queue(), ^{
            if (self.completionCallback) {
                self.completionCallback(1, NULL);
            }
        });
    } else {
        NSString *errMsg = [NSString stringWithFormat:@"Failed to move file: %@",
                           error.localizedDescription];
        NSLog(@"[Scribe:download] %@", errMsg);
        dispatch_async(dispatch_get_main_queue(), ^{
            if (self.completionCallback) {
                self.completionCallback(0, [errMsg UTF8String]);
            }
        });
    }
}

- (void)URLSession:(NSURLSession *)session
      downloadTask:(NSURLSessionDownloadTask *)downloadTask
      didWriteData:(int64_t)bytesWritten
 totalBytesWritten:(int64_t)totalBytesWritten
totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.progressCallback) {
            self.progressCallback(totalBytesWritten, totalBytesExpectedToWrite);
        }
    });
}

- (void)URLSession:(NSURLSession *)session
              task:(NSURLSessionTask *)task
didCompleteWithError:(NSError *)error {
    if (error) {
        NSString *errMsg = [NSString stringWithFormat:@"Download failed: %@",
                           error.localizedDescription];
        NSLog(@"[Scribe:download] %@", errMsg);
        dispatch_async(dispatch_get_main_queue(), ^{
            if (self.completionCallback) {
                self.completionCallback(0, [errMsg UTF8String]);
            }
        });
    }
}

@end

// Strong reference to keep delegate alive during download
static ScribeDownloadDelegate *g_download_delegate = nil;

void scribe_download_file(const char *url_str,
                           const char *dest_path,
                           download_progress_fn progress_callback,
                           download_completion_fn completion_callback) {
    if (!url_str || !dest_path) {
        if (completion_callback) completion_callback(0, "NULL url or destination");
        return;
    }

    NSString *urlString = [NSString stringWithUTF8String:url_str];
    NSURL *url = [NSURL URLWithString:urlString];
    if (!url) {
        if (completion_callback) completion_callback(0, "Invalid URL");
        return;
    }

    NSLog(@"[Scribe:download] Starting download: %@ -> %s", urlString, dest_path);

    // Ensure destination directory exists
    NSString *destDir = [[NSString stringWithUTF8String:dest_path] stringByDeletingLastPathComponent];
    [[NSFileManager defaultManager] createDirectoryAtPath:destDir
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:nil];

    g_download_delegate = [[ScribeDownloadDelegate alloc] init];
    g_download_delegate.destinationPath = [NSString stringWithUTF8String:dest_path];
    g_download_delegate.progressCallback = progress_callback;
    g_download_delegate.completionCallback = completion_callback;

    NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
    config.timeoutIntervalForRequest = 30.0;
    config.timeoutIntervalForResource = 600.0; // 10 min for large models

    NSURLSession *session = [NSURLSession sessionWithConfiguration:config
                                                          delegate:g_download_delegate
                                                     delegateQueue:nil];

    NSURLSessionDownloadTask *task = [session downloadTaskWithURL:url];
    [task resume];
}

// ============================================================================
// Section 13: macOS Notifications (UNUserNotificationCenter)
// ============================================================================
//
// Delivers macOS system notifications via UNUserNotificationCenter.
// Permission is requested lazily on first notification attempt.
// Notifications include title, body, and an identifier (thread UUID)
// that can be used for future deep-link handling.

static BOOL g_notifications_authorized = NO;
static BOOL g_notifications_auth_requested = NO;

void scribe_notifications_request_auth(void) {
    if (g_notifications_auth_requested) return;
    g_notifications_auth_requested = YES;

    UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
    [center requestAuthorizationWithOptions:(UNAuthorizationOptionAlert |
                                             UNAuthorizationOptionSound |
                                             UNAuthorizationOptionBadge)
                         completionHandler:^(BOOL granted, NSError * _Nullable error) {
        g_notifications_authorized = granted;
        if (granted) {
            NSLog(@"[Scribe:notifications] Authorization granted");
        } else {
            NSLog(@"[Scribe:notifications] Authorization denied: %@",
                  error ? error.localizedDescription : @"user denied");
        }
    }];
}

void scribe_notification_send(const char *title, const char *body, const char *identifier) {
    if (!title || !body || !identifier) {
        NSLog(@"[Scribe:notifications] ERROR: null title, body, or identifier");
        return;
    }

    // Request auth on first send if not already done
    if (!g_notifications_auth_requested) {
        scribe_notifications_request_auth();
    }

    UNMutableNotificationContent *content = [[UNMutableNotificationContent alloc] init];
    content.title = [NSString stringWithUTF8String:title];
    content.body = [NSString stringWithUTF8String:body];
    content.sound = [UNNotificationSound defaultSound];

    NSString *reqId = [NSString stringWithUTF8String:identifier];

    // Immediate delivery (nil trigger = deliver now)
    UNNotificationRequest *request = [UNNotificationRequest requestWithIdentifier:reqId
                                                                          content:content
                                                                          trigger:nil];

    UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
    [center addNotificationRequest:request withCompletionHandler:^(NSError * _Nullable error) {
        if (error) {
            NSLog(@"[Scribe:notifications] Failed to deliver: %@", error.localizedDescription);
        } else {
            NSLog(@"[Scribe:notifications] Delivered: %s", identifier);
        }
    }];
}

// ============================================================================
// Section 14: FSEvents File Watching (iCloud Sync -- Epic 12)
// ============================================================================
//
// Monitors a directory tree for file-level changes using macOS FSEvents API.
// Used to detect iCloud Drive synced file changes (new/modified/deleted thread
// files from other devices). The callback fires on the main thread with the
// changed file path and FSEvent flags.
//
// Flags of interest:
//   kFSEventStreamEventFlagItemCreated   = 0x00000100
//   kFSEventStreamEventFlagItemRemoved   = 0x00000200
//   kFSEventStreamEventFlagItemModified  = 0x00001000
//   kFSEventStreamEventFlagItemRenamed   = 0x00000800

typedef void (*fsevents_callback_fn)(const char *path, uint32_t flags);
static fsevents_callback_fn g_fsevents_callback = NULL;

static void fsevents_handler(ConstFSEventStreamRef streamRef,
                              void *clientCallBackInfo,
                              size_t numEvents,
                              void *eventPaths,
                              const FSEventStreamEventFlags eventFlags[],
                              const FSEventStreamEventId eventIds[]) {
    char **paths = (char **)eventPaths;
    for (size_t i = 0; i < numEvents; i++) {
        uint32_t flags = (uint32_t)eventFlags[i];
        // Only fire for file-level events (not directory-level)
        if (flags & (kFSEventStreamEventFlagItemCreated |
                     kFSEventStreamEventFlagItemRemoved |
                     kFSEventStreamEventFlagItemModified |
                     kFSEventStreamEventFlagItemRenamed)) {
            const char *path = paths[i];
            // Dispatch callback on main thread for thread safety with Crystal
            dispatch_async(dispatch_get_main_queue(), ^{
                if (g_fsevents_callback) {
                    g_fsevents_callback(path, flags);
                }
            });
        }
    }
}

// Start watching a directory path for file-level changes.
// Returns an opaque FSEventStreamRef (pass to scribe_fsevents_stop to stop).
// The callback fires on the main thread.
void *scribe_fsevents_start(const char *path, fsevents_callback_fn callback) {
    if (!path || !callback) {
        NSLog(@"[Scribe:fsevents] ERROR: null path or callback");
        return NULL;
    }

    g_fsevents_callback = callback;

    NSString *watchPath = [NSString stringWithUTF8String:path];
    NSArray *pathsToWatch = @[watchPath];

    FSEventStreamContext context = {0, NULL, NULL, NULL, NULL};

    FSEventStreamRef stream = FSEventStreamCreate(
        kCFAllocatorDefault,
        &fsevents_handler,
        &context,
        (__bridge CFArrayRef)pathsToWatch,
        kFSEventStreamEventIdSinceNow,
        1.0,  // 1 second latency (batches events for efficiency)
        kFSEventStreamCreateFlagFileEvents |
        kFSEventStreamCreateFlagUseCFTypes |
        kFSEventStreamCreateFlagNoDefer
    );

    if (!stream) {
        NSLog(@"[Scribe:fsevents] ERROR: Failed to create FSEventStream");
        return NULL;
    }

    // Schedule on the main dispatch queue (modern API, replaces deprecated RunLoop scheduling)
    FSEventStreamSetDispatchQueue(stream, dispatch_get_main_queue());
    FSEventStreamStart(stream);

    NSLog(@"[Scribe:fsevents] Watching: %@", watchPath);
    return (void *)stream;
}

// Stop watching for file changes and release the stream.
void scribe_fsevents_stop(void *stream) {
    if (!stream) return;

    FSEventStreamRef fsStream = (FSEventStreamRef)stream;
    FSEventStreamStop(fsStream);
    FSEventStreamInvalidate(fsStream);
    FSEventStreamRelease(fsStream);

    NSLog(@"[Scribe:fsevents] Stopped watching");
}

// ============================================================================
// Section 15: Launch at Login (SMAppService — macOS 13.0+)
// ============================================================================

// Check if the app is registered to launch at login.
// Returns 1 if enabled, 0 otherwise.
int scribe_launch_at_login_status(void) {
    @try {
        if (@available(macOS 13.0, *)) {
            SMAppService *service = [SMAppService mainAppService];
            return (service.status == SMAppServiceStatusEnabled) ? 1 : 0;
        }
    } @catch (NSException *exception) {
        NSLog(@"[Scribe:login] Exception checking status: %@", exception.reason);
    }
    return 0;
}

// Register the app to launch at login.
// Returns 1 on success, 0 on failure.
int scribe_launch_at_login_enable(void) {
    @try {
        if (@available(macOS 13.0, *)) {
            NSError *error = nil;
            BOOL ok = [[SMAppService mainAppService] registerAndReturnError:&error];
            if (!ok) {
                NSLog(@"[Scribe:login] Failed to enable: %@",
                      error.localizedDescription);
            }
            return ok ? 1 : 0;
        }
    } @catch (NSException *exception) {
        NSLog(@"[Scribe:login] Exception enabling: %@", exception.reason);
    }
    return 0;
}

// Unregister the app from launching at login.
// Returns 1 on success, 0 on failure.
int scribe_launch_at_login_disable(void) {
    @try {
        if (@available(macOS 13.0, *)) {
            NSError *error = nil;
            BOOL ok = [[SMAppService mainAppService] unregisterAndReturnError:&error];
            if (!ok) {
                NSLog(@"[Scribe:login] Failed to disable: %@",
                      error.localizedDescription);
            }
            return ok ? 1 : 0;
        }
    } @catch (NSException *exception) {
        NSLog(@"[Scribe:login] Exception disabling: %@", exception.reason);
    }
    return 0;
}

// ============================================================================
// Section 15b: Submenu & Menu Item Management
// ============================================================================

// Attach a submenu to a menu item.
void scribe_set_menu_item_submenu(void *item, void *submenu) {
    [(NSMenuItem *)item setSubmenu:(NSMenu *)submenu];
}

// Remove all items from a menu (for rebuilding submenus dynamically).
void scribe_remove_all_menu_items(void *menu) {
    [(NSMenu *)menu removeAllItems];
}

// Enable or disable a menu item.
void scribe_set_menu_item_enabled(void *item, int enabled) {
    [(NSMenuItem *)item setEnabled:(enabled != 0)];
}

// ============================================================================
// Section 16: NSOpenPanel (Folder Picker)
// ============================================================================

// Show a modal folder picker dialog.
// Returns a malloc'd C string with the selected path, or NULL if cancelled.
// Caller must free the returned string with scribe_free_string().
const char *scribe_choose_folder(const char *title) {
    @autoreleasepool {
        NSOpenPanel *panel = [NSOpenPanel openPanel];
        [panel setCanChooseFiles:NO];
        [panel setCanChooseDirectories:YES];
        [panel setAllowsMultipleSelection:NO];
        [panel setCanCreateDirectories:YES];
        if (title) {
            [panel setTitle:[NSString stringWithUTF8String:title]];
            [panel setMessage:[NSString stringWithUTF8String:title]];
        }

        NSModalResponse response = [panel runModal];
        if (response == NSModalResponseOK) {
            NSURL *url = [[panel URLs] firstObject];
            if (url) {
                return strdup([[url path] UTF8String]);
            }
        }
        return NULL;
    }
}

// Show a modal file picker dialog filtered to audio files.
// Returns a malloc'd C string with the selected path, or NULL if cancelled.
const char *scribe_choose_file(const char *title) {
    @autoreleasepool {
        NSOpenPanel *panel = [NSOpenPanel openPanel];
        [panel setCanChooseFiles:YES];
        [panel setCanChooseDirectories:NO];
        [panel setAllowsMultipleSelection:NO];
        if (title) {
            [panel setTitle:[NSString stringWithUTF8String:title]];
        }
        // Filter to supported audio file types (WAV native, others converted via afconvert)
        if (@available(macOS 11.0, *)) {
            UTType *wav = [UTType typeWithFilenameExtension:@"wav"];
            UTType *m4a = [UTType typeWithFilenameExtension:@"m4a"];
            UTType *mp3 = [UTType typeWithFilenameExtension:@"mp3"];
            UTType *aiff = [UTType typeWithFilenameExtension:@"aiff"];
            UTType *caf = [UTType typeWithFilenameExtension:@"caf"];
            UTType *flac = [UTType typeWithFilenameExtension:@"flac"];
            NSMutableArray *types = [NSMutableArray array];
            if (wav)  [types addObject:wav];
            if (m4a)  [types addObject:m4a];
            if (mp3)  [types addObject:mp3];
            if (aiff) [types addObject:aiff];
            if (caf)  [types addObject:caf];
            if (flac) [types addObject:flac];
            [panel setAllowedContentTypes:types];
        }

        NSModalResponse response = [panel runModal];
        if (response == NSModalResponseOK) {
            NSURL *url = [[panel URLs] firstObject];
            if (url) {
                return strdup([[url path] UTF8String]);
            }
        }
        return NULL;
    }
}

// Free a string returned by scribe_choose_folder() or scribe_choose_file().
void scribe_free_string(char *str) {
    if (str) free(str);
}

// ============================================================================
// Section 17: System Colors (semantic macOS colors for adaptive Light/Dark mode)
// ============================================================================

// Helper: extract RGBA from an NSColor, resolving catalog/dynamic colors.
// NSColor.labelColor etc. are "catalog colors" that can't directly convert
// to sRGB. We must first convert to component-based, then to sRGB.
static void _extract_rgba(NSColor *color, double *r, double *g, double *b, double *a) {
    NSColor *resolved = nil;

    // Step 1: Convert catalog color to component-based (macOS 11+)
    if (@available(macOS 11.0, *)) {
        resolved = [color colorUsingType:NSColorTypeComponentBased];
    }

    // Step 2: Convert to sRGB for consistent RGBA extraction
    NSColor *srgb = nil;
    if (resolved) {
        srgb = [resolved colorUsingColorSpace:[NSColorSpace sRGBColorSpace]];
    }
    if (!srgb) {
        srgb = [color colorUsingColorSpace:[NSColorSpace sRGBColorSpace]];
    }

    if (srgb) {
        *r = [srgb redComponent];
        *g = [srgb greenComponent];
        *b = [srgb blueComponent];
        *a = [srgb alphaComponent];
        return;
    }

    // Ultimate fallback: detect dark mode and use appropriate default
    BOOL isDark = NO;
    NSAppearance *appearance = [[NSApplication sharedApplication] effectiveAppearance];
    if (appearance) {
        isDark = [appearance.name isEqualToString:NSAppearanceNameDarkAqua] ||
                 [appearance.name containsString:@"Dark"];
    }
    *r = isDark ? 1.0 : 0.0;
    *g = isDark ? 1.0 : 0.0;
    *b = isDark ? 1.0 : 0.0;
    *a = 1.0;
}

void scribe_get_label_color(double *r, double *g, double *b, double *a) {
    _extract_rgba([NSColor labelColor], r, g, b, a);
}

void scribe_get_secondary_label_color(double *r, double *g, double *b, double *a) {
    _extract_rgba([NSColor secondaryLabelColor], r, g, b, a);
}

void scribe_get_tertiary_label_color(double *r, double *g, double *b, double *a) {
    _extract_rgba([NSColor tertiaryLabelColor], r, g, b, a);
}

void scribe_get_control_accent_color(double *r, double *g, double *b, double *a) {
    _extract_rgba([NSColor controlAccentColor], r, g, b, a);
}

void scribe_get_window_background_color(double *r, double *g, double *b, double *a) {
    _extract_rgba([NSColor windowBackgroundColor], r, g, b, a);
}

void scribe_get_system_green_color(double *r, double *g, double *b, double *a) {
    _extract_rgba([NSColor systemGreenColor], r, g, b, a);
}

void scribe_get_system_red_color(double *r, double *g, double *b, double *a) {
    _extract_rgba([NSColor systemRedColor], r, g, b, a);
}

void scribe_get_system_yellow_color(double *r, double *g, double *b, double *a) {
    _extract_rgba([NSColor systemYellowColor], r, g, b, a);
}

void scribe_get_separator_color(double *r, double *g, double *b, double *a) {
    _extract_rgba([NSColor separatorColor], r, g, b, a);
}

void scribe_get_link_color(double *r, double *g, double *b, double *a) {
    _extract_rgba([NSColor linkColor], r, g, b, a);
}

// Open a URL in the default browser.
void scribe_open_url(const char *url_cstr) {
    if (!url_cstr) return;
    @autoreleasepool {
        NSURL *url = [NSURL URLWithString:[NSString stringWithUTF8String:url_cstr]];
        if (url) [[NSWorkspace sharedWorkspace] openURL:url];
    }
}

// Post a VoiceOver announcement (for state changes like recording start/stop).
void scribe_accessibility_announce(const char *text) {
    if (!text) return;
    NSString *announcement = [NSString stringWithUTF8String:text];
    NSDictionary *info = @{
        NSAccessibilityAnnouncementKey: announcement,
        NSAccessibilityPriorityKey: @(NSAccessibilityPriorityHigh)
    };
    NSAccessibilityPostNotificationWithUserInfo(
        [NSApplication sharedApplication],
        NSAccessibilityAnnouncementRequestedNotification,
        info
    );
}

// ============================================================================
// Section 17b: Screen Recording Permission Check
// ============================================================================

// Check if Screen Recording (system audio) permission is granted.
// Returns 1 if granted, 0 if not.
int scribe_screen_capture_check(void) {
    if (@available(macOS 10.15, *)) {
        return CGPreflightScreenCaptureAccess() ? 1 : 0;
    }
    return 1; // Pre-Catalina always allowed
}

// Request Screen Recording permission. Opens the system prompt.
// Returns 1 if granted immediately, 0 if user needs to grant in System Settings.
int scribe_screen_capture_request(void) {
    if (@available(macOS 10.15, *)) {
        return CGRequestScreenCaptureAccess() ? 1 : 0;
    }
    return 1;
}

// ============================================================================
// Section 18: Open System Settings (for permission request flows)
// ============================================================================

void scribe_open_system_settings(const char *url_string) {
    @autoreleasepool {
        NSURL *url = [NSURL URLWithString:[NSString stringWithUTF8String:url_string]];
        [[NSWorkspace sharedWorkspace] openURL:url];
    }
}

// ============================================================================
// Section 19: CrystalActionDispatcher (Asset Pipeline button callback bridge)
// ============================================================================
//
// The Asset Pipeline AppKit renderer expects a "CrystalActionDispatcher" ObjC
// class with a dispatch: method that routes button clicks back to Crystal's
// CallbackRegistry via crystal_ui_callback_dispatch(). This class is NOT
// provided by the Asset Pipeline's objc_bridge — we register it dynamically here.

// Extern: Crystal-side callback dispatch function. Defined via `fun` export in Crystal.
extern void crystal_ui_callback_dispatch(uint64_t callback_id);

// ============================================================================
// Section 19b: App Restart
// ============================================================================

void scribe_restart_app(void) {
    NSURL *bundleURL = [[NSBundle mainBundle] bundleURL];
    NSWorkspaceOpenConfiguration *config = [NSWorkspaceOpenConfiguration configuration];
    config.createsNewApplicationInstance = YES;
    [[NSWorkspace sharedWorkspace] openApplicationAtURL:bundleURL
                                         configuration:config
                                     completionHandler:^(NSRunningApplication *app, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [NSApp terminate:nil];
        });
    }];
}

// CrystalActionDispatcher — a simple NSObject subclass that stores a tag and
// dispatches button clicks to Crystal's CallbackRegistry.
@interface CrystalActionDispatcher : NSObject
@property (nonatomic, assign) NSInteger tag;
- (void)dispatch:(id)sender;
@end

@implementation CrystalActionDispatcher
- (void)dispatch:(id)sender {
    if (self.tag > 0) {
        crystal_ui_callback_dispatch((uint64_t)self.tag);
    }
}
@end

// ============================================================================
// Section 19d: CrystalTextFieldDelegate (TextField on_change callback bridge)
// ============================================================================
//
// The Asset Pipeline renderer registers on_change callbacks for TextFields
// but never sets a delegate. This observer listens for ALL NSTextField changes
// via NSNotificationCenter and routes them through crystal_ui_callback_dispatch.
//
// The callback ID is stored on the NativeView via CallbackRegistry.
// The renderer stores the callback ID as part of the NativeView's callback_ids.
// Since we can't access that from ObjC, we use the NSTextField's tag property
// to store the callback ID (set by the renderer at visit time).

@interface CrystalTextFieldObserver : NSObject
@end

@implementation CrystalTextFieldObserver
- (instancetype)init {
    self = [super init];
    if (self) {
        [[NSNotificationCenter defaultCenter]
            addObserver:self
               selector:@selector(textDidChange:)
                   name:NSControlTextDidChangeNotification
                 object:nil];
    }
    return self;
}

- (void)textDidChange:(NSNotification *)notification {
    NSTextField *field = notification.object;
    if ([field isKindOfClass:[NSTextField class]] && field.tag > 0) {
        crystal_ui_callback_dispatch((uint64_t)field.tag);
    }
}
@end

static CrystalTextFieldObserver *g_text_observer = nil;

__attribute__((constructor))
static void _register_text_field_observer(void) {
    g_text_observer = [[CrystalTextFieldObserver alloc] init];
}

// ============================================================================
// Section 20: NSStackView edge insets (padding support for Asset Pipeline)
// ============================================================================

void scribe_stackview_set_edge_insets(void *stackview,
                                       double top, double left,
                                       double bottom, double right) {
    if (!stackview) return;
    id obj = (id)stackview;
    if ([obj isKindOfClass:[NSStackView class]]) {
        NSStackView *sv = (NSStackView *)stackview;
        sv.edgeInsets = NSEdgeInsetsMake(top, left, bottom, right);
    } else {
        NSLog(@"[Scribe:padding] Warning: view is %@, not NSStackView", [obj class]);
    }
}

// ============================================================================
// Section 21: NSApplicationDelegate (Dock menu + Dock icon click)
// ============================================================================

typedef void (*dock_menu_callback_fn)(void);
typedef void (*reopen_callback_fn)(void);
typedef void (*will_terminate_callback_fn)(void);

static NSMenu *g_dock_menu = nil;
static dock_menu_callback_fn g_dock_menu_callback = NULL;
static reopen_callback_fn g_reopen_callback = NULL;
static will_terminate_callback_fn g_will_terminate_callback = NULL;

@interface ScribeAppDelegate : NSObject <NSApplicationDelegate>
@end

@implementation ScribeAppDelegate

// Right-click (or Ctrl+click) on Dock icon → return the Dock menu
- (NSMenu *)applicationDockMenu:(NSApplication *)sender {
    if (g_dock_menu_callback) {
        g_dock_menu_callback();
    }
    return g_dock_menu;
}

// Single-click on Dock icon → open Preferences
- (BOOL)applicationShouldHandleReopen:(NSApplication *)sender
                    hasVisibleWindows:(BOOL)hasVisibleWindows {
    if (g_reopen_callback) {
        g_reopen_callback();
    }
    return YES;
}

// Called before ANY termination (Cmd+Q, menu Quit, system shutdown, etc.)
// This is the LAST chance to clean up resources like the whisper Metal context.
- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender {
    if (g_will_terminate_callback) {
        g_will_terminate_callback();
    }
    return NSTerminateNow;
}

@end

static ScribeAppDelegate *g_app_delegate = nil;

// Create and install the app delegate on NSApp.
void scribe_install_app_delegate(void) {
    if (!g_app_delegate) {
        g_app_delegate = [[ScribeAppDelegate alloc] init];
    }
    [[NSApplication sharedApplication] setDelegate:g_app_delegate];
}

// Set the NSMenu to be returned by applicationDockMenu:.
void scribe_set_dock_menu(void *menu) {
    g_dock_menu = (NSMenu *)menu;
}

// Install a callback invoked just before the Dock menu is shown (to refresh items).
void scribe_install_dock_menu_callback(dock_menu_callback_fn callback) {
    g_dock_menu_callback = callback;
}

// Install a callback invoked when the Dock icon is single-clicked.
void scribe_install_reopen_callback(reopen_callback_fn callback) {
    g_reopen_callback = callback;
}

// Install a callback invoked before ANY app termination (Cmd+Q, menu Quit, shutdown).
// This is the safety net for cleaning up whisper Metal resources.
void scribe_install_will_terminate_callback(will_terminate_callback_fn callback) {
    g_will_terminate_callback = callback;
}
