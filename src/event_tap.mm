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

#include <ApplicationServices/ApplicationServices.h>
#include <CoreFoundation/CoreFoundation.h>
#include <Foundation/Foundation.h>
#include "event_tap.hpp"
#include "window_event_tap.hpp"

EventTap::EventTap(int64_t event_mask) :
    event_mask(event_mask)
{
    this->event_tap =
        CGEventTapCreate(
            kCGSessionEventTap,
            kCGTailAppendEventTap,
            kCGEventTapOptionDefault,
            kCGEventMaskForAllEvents,
            cg_event_callback,
            this);
    this->run_loop_source = CFMachPortCreateRunLoopSource(nullptr, this->event_tap, 0);
    CFRunLoopAddSource(CFRunLoopGetMain(), this->run_loop_source, kCFRunLoopCommonModes);
}

EventTap::~EventTap(void)
{
    CFRunLoopSourceInvalidate(this->run_loop_source);
    CFRelease(this->run_loop_source);
    CFRelease(this->event_tap);
}

void EventTap::set_event_mask(int64_t event_mask)
{
    this->event_mask = event_mask;
}

CGEventRef EventTap::cg_event_callback(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *data)
{
    auto event_tap = static_cast<EventTap *>(data);

    CGEventMask event_type_mask = CGEventMaskBit(type);
    if (event_type_mask == 0 || (event_type_mask & event_tap->event_mask) != event_type_mask) {
        return event;
    }

    bool consume_event = false;
    CGPoint location = CGEventGetLocation(event);
    int64_t delta_x = location.x - event_tap->last_mouse_position.x,
            delta_y = location.y - event_tap->last_mouse_position.y;

    if (!(AXAPIEnabled() || AXIsProcessTrusted())) {
        return event;
    }

    switch (type) {
        case kCGEventLeftMouseDown:
            event_tap->last_mouse_position = location;
            consume_event = event_tap->on_left_mouse_down(proxy, type, event);
            break;

        case kCGEventLeftMouseDragged:
            event_tap->last_mouse_position = location;
            consume_event = event_tap->on_left_mouse_drag(proxy, type, event, delta_x, delta_y);
            break;

        case kCGEventLeftMouseUp:
            consume_event = event_tap->on_left_mouse_up(proxy, type, event);
            break;

        case kCGEventRightMouseDown:
            event_tap->last_mouse_position = location;
            consume_event = event_tap->on_right_mouse_down(proxy, type, event);
            break;

        case kCGEventRightMouseDragged:
            event_tap->last_mouse_position = location;
            consume_event = event_tap->on_right_mouse_drag(proxy, type, event, delta_x, delta_y);
            break;

        case kCGEventRightMouseUp:
            consume_event = event_tap->on_right_mouse_up(proxy, type, event);
            break;

        case kCGEventTapDisabledByTimeout:
            NSLog(@"Event tap was disabled by timeout, aborting\n");
            break;

        default:
            NSLog(@"Unknown event %d\n", type);
            break;
    }

    return consume_event ? nullptr : event;
}
