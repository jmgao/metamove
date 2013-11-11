/*
 * metamove - XFree86 window movement for OS X
 * Copyright (C) 2013 jmgao
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program; if not, write to the Free Software Foundation, Inc.,
 * 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
 */

#include <CoreFoundation/CoreFoundation.h>
#include <Foundation/Foundation.h>
#include "config.hpp"
#include "metamove.hpp"
#include "window_event_tap.hpp"

extern Boolean AXIsProcessTrustedWithOptions(CFDictionaryRef options) __attribute__((weak_import));
extern CFStringRef kAXTrustedCheckOptionPrompt __attribute__((weak_import));

static bool metamove_enabled = true;
static MoveWindowEventTap *move_window_event_tap;
static ResizeWindowEventTap *resize_window_event_tap;

static CGEventMask get_mouse_mask(config_mouse_button button)
{
    if (!metamove_is_enabled()) {
        return 0;
    }

    constexpr CGEventMask left_mouse_mask =
        CGEventMaskBit(kCGEventLeftMouseDown) |
        CGEventMaskBit(kCGEventLeftMouseDragged) |
        CGEventMaskBit(kCGEventLeftMouseUp);
    constexpr CGEventMask right_mouse_mask =
        CGEventMaskBit(kCGEventRightMouseDown) |
        CGEventMaskBit(kCGEventRightMouseDragged) |
        CGEventMaskBit(kCGEventRightMouseUp);

    switch (button) {
        case config_mouse_button::left:
            return left_mouse_mask;
        case config_mouse_button::right:
            return right_mouse_mask;
        default:
            return 0;
    }
}

bool metamove_is_enabled(void)
{
    return metamove_enabled;
}

void metamove_set_enabled(bool enabled)
{
    metamove_enabled = enabled;
}

void metamove_start(void)
{
    if (AXIsProcessTrustedWithOptions && kAXTrustedCheckOptionPrompt) {
        AXIsProcessTrustedWithOptions((__bridge CFDictionaryRef) @{
            (__bridge NSString *) kAXTrustedCheckOptionPrompt : (NSNumber *)kCFBooleanTrue
        });
    }

    move_window_event_tap =
        new MoveWindowEventTap(
            get_mouse_mask(get_move_button()),
            get_move_modifiers(),
            true);
    resize_window_event_tap =
        new ResizeWindowEventTap(
            get_mouse_mask(get_resize_button()),
            get_resize_modifiers(),
            true);

    NSLog(@"metamove v%s successfully initialized.", VERSION_STRING);
}

void metamove_reconfigure(void)
{
    move_window_event_tap->set_event_mask(get_mouse_mask(get_move_button()));
    move_window_event_tap->set_modifiers(get_move_modifiers());

    resize_window_event_tap->set_event_mask(get_mouse_mask(get_resize_button()));
    resize_window_event_tap->set_modifiers(get_resize_modifiers());
}
