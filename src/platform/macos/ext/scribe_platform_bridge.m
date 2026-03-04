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
    [(NSApplication *)app activate];
}

void scribe_run_app(void *app) {
    [(NSApplication *)app run];
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

void scribe_set_content_view(void *window, void *view) {
    [(NSWindow *)window setContentView:(NSView *)view];
}

void scribe_center_window(void *window) {
    [(NSWindow *)window center];
}

void scribe_make_key_and_order_front(void *window) {
    [(NSWindow *)window makeKeyAndOrderFront:nil];
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
        [g_indicator_label setStringValue:[NSString stringWithUTF8String:text]];
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
