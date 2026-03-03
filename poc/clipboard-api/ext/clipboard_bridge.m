// POC 3: macOS Clipboard API (NSPasteboard) + Paste Simulation (CGEvent)
//
// Provides:
// 1. Read plain text from clipboard
// 2. Write plain text to clipboard
// 3. Simulate Cmd+V paste keystroke via CGEvent
//
// Compile: clang -c ext/clipboard_bridge.c -o ext/clipboard_bridge.o \
//          -framework AppKit -framework ApplicationServices -fobjc-arc

#import <AppKit/AppKit.h>
#import <ApplicationServices/ApplicationServices.h>
#include <string.h>
#include <stdlib.h>

// Read the current clipboard contents as UTF-8 string
// Returns a malloc'd string (caller must free) or NULL if clipboard is empty/non-text
const char* clipboard_read(void) {
    @autoreleasepool {
        NSPasteboard *pb = [NSPasteboard generalPasteboard];
        NSString *text = [pb stringForType:NSPasteboardTypeString];
        if (text == nil) return NULL;

        const char *utf8 = [text UTF8String];
        if (utf8 == NULL) return NULL;

        // Return a copy (the autorelease pool will release the NSString)
        return strdup(utf8);
    }
}

// Write a UTF-8 string to the clipboard
// Returns 0 on success, -1 on failure
int clipboard_write(const char *text) {
    if (text == NULL) return -1;

    @autoreleasepool {
        NSPasteboard *pb = [NSPasteboard generalPasteboard];
        [pb clearContents];

        NSString *nsText = [NSString stringWithUTF8String:text];
        if (nsText == nil) return -1;

        BOOL ok = [pb setString:nsText forType:NSPasteboardTypeString];
        return ok ? 0 : -1;
    }
}

// Free a string returned by clipboard_read
void clipboard_free(const char *ptr) {
    free((void *)ptr);
}

// Simulate Cmd+V paste keystroke via CGEvent
// Returns 0 on success, -1 on failure
// NOTE: Requires Accessibility permission (System Settings > Privacy > Accessibility)
int clipboard_simulate_paste(void) {
    // Virtual key code for 'V'
    CGKeyCode v_keycode = 0x09;

    // Create key down event with Cmd modifier
    CGEventRef key_down = CGEventCreateKeyboardEvent(NULL, v_keycode, true);
    if (key_down == NULL) return -1;
    CGEventSetFlags(key_down, kCGEventFlagMaskCommand);

    // Create key up event with Cmd modifier
    CGEventRef key_up = CGEventCreateKeyboardEvent(NULL, v_keycode, false);
    if (key_up == NULL) {
        CFRelease(key_down);
        return -1;
    }
    CGEventSetFlags(key_up, kCGEventFlagMaskCommand);

    // Post to the HID event stream
    CGEventPost(kCGHIDEventTap, key_down);
    CGEventPost(kCGHIDEventTap, key_up);

    CFRelease(key_down);
    CFRelease(key_up);

    return 0;
}

// Get the change count of the clipboard (increments on each modification)
// Useful for detecting external clipboard changes
long clipboard_change_count(void) {
    @autoreleasepool {
        NSPasteboard *pb = [NSPasteboard generalPasteboard];
        return (long)[pb changeCount];
    }
}
