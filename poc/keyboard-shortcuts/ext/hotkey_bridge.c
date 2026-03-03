// POC 2: macOS Global Keyboard Shortcuts via Carbon API
//
// Uses Carbon's RegisterEventHotKey which still works on modern macOS.
// This avoids the complexity of CGEvent taps and Accessibility permissions.
//
// Compile: clang -c ext/hotkey_bridge.c -o ext/hotkey_bridge.o -framework Carbon

#include <Carbon/Carbon.h>
#include <stdio.h>

// Callback function type that Crystal will provide
typedef void (*hotkey_callback_fn)(unsigned int hotkey_id);

// Global callback storage
static hotkey_callback_fn g_callback = NULL;

// Event handler installed on the application event target
static OSStatus hotkey_event_handler(EventHandlerCallRef next, EventRef event, void *user_data) {
    EventHotKeyID hotkey_id;
    OSStatus err = GetEventParameter(event, kEventParamDirectObject,
                                      typeEventHotKeyID, NULL,
                                      sizeof(hotkey_id), NULL, &hotkey_id);
    if (err == noErr && g_callback != NULL) {
        g_callback(hotkey_id.id);
    }
    return noErr;
}

// Register the event handler for hotkey events (call once at startup)
int hotkey_install_handler(hotkey_callback_fn callback) {
    g_callback = callback;

    EventTypeSpec event_type;
    event_type.eventClass = kEventClassKeyboard;
    event_type.eventKind = kEventHotKeyPressed;

    OSStatus err = InstallApplicationEventHandler(
        &hotkey_event_handler,
        1,
        &event_type,
        NULL,
        NULL
    );

    return (int)err;
}

// Register a global hotkey
// Returns 0 on success, error code otherwise
// modifier_flags: cmdKey=0x100, shiftKey=0x200, optionKey=0x800, controlKey=0x1000
// key_code: Carbon virtual key code (e.g., kVK_ANSI_R = 0x0F)
int hotkey_register(unsigned int hotkey_id, unsigned int modifier_flags, unsigned int key_code, void **out_ref) {
    EventHotKeyID hk_id;
    hk_id.signature = 'SCRB';  // Scribe app signature
    hk_id.id = hotkey_id;

    EventHotKeyRef ref;
    OSStatus err = RegisterEventHotKey(
        key_code,
        modifier_flags,
        hk_id,
        GetApplicationEventTarget(),
        0,
        &ref
    );

    if (out_ref) *out_ref = (void *)ref;
    return (int)err;
}

// Unregister a previously registered hotkey
int hotkey_unregister(void *ref) {
    return (int)UnregisterEventHotKey((EventHotKeyRef)ref);
}

// Run the Carbon event loop for a specified duration (seconds)
// RunApplicationEventLoop is deprecated; use CFRunLoop instead
void hotkey_run_loop(double seconds) {
    if (seconds > 0) {
        CFRunLoopRunInMode(kCFRunLoopDefaultMode, seconds, false);
    } else {
        CFRunLoopRun();  // Run indefinitely
    }
}

// Run one iteration of the event loop (non-blocking, for integration with other loops)
void hotkey_pump_events(void) {
    EventRef event;
    while (ReceiveNextEvent(0, NULL, 0.0, true, &event) == noErr) {
        SendEventToEventTarget(event, GetApplicationEventTarget());
        ReleaseEvent(event);
    }
}
