#pragma once

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

#include <cstdint>
#include <ApplicationServices/ApplicationServices.h>
#include <CoreFoundation/CoreFoundation.h>

class EventTap {
protected:
    CGPoint last_mouse_position;
    CFMachPortRef event_tap;
    CFRunLoopSourceRef run_loop_source;

public:
    explicit EventTap(int64_t event_mask);

    virtual ~EventTap(void);

    static CGEventRef cg_event_callback(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *data);

protected:
    virtual bool on_left_mouse_down(CGEventTapProxy proxy, CGEventType type, CGEventRef event) {
        return on_mouse_down(proxy, type, event);
    }

    virtual bool on_left_mouse_drag(CGEventTapProxy proxy, CGEventType type, CGEventRef event, int64_t delta_x, int64_t delta_y) {
        return on_mouse_drag(proxy, type, event, delta_x, delta_y);
    }

    virtual bool on_left_mouse_up(CGEventTapProxy proxy, CGEventType type, CGEventRef event) {
        return on_mouse_up(proxy, type, event);
    }

    virtual bool on_right_mouse_down(CGEventTapProxy proxy, CGEventType type, CGEventRef event) {
        return on_mouse_down(proxy, type, event);
    }

    virtual bool on_right_mouse_drag(CGEventTapProxy proxy, CGEventType type, CGEventRef event, int64_t delta_x, int64_t delta_y) {
        return on_mouse_drag(proxy, type, event, delta_x, delta_y);
    }

    virtual bool on_right_mouse_up(CGEventTapProxy proxy, CGEventType type, CGEventRef event) {
        return on_mouse_up(proxy, type, event);
    }

    virtual bool on_mouse_down(CGEventTapProxy proxy, CGEventType type, CGEventRef event) {
        return false;
    }

    virtual bool on_mouse_drag(CGEventTapProxy proxy, CGEventType type, CGEventRef event, int64_t delta_x, int64_t delta_y) {
        return false;
    }

    virtual bool on_mouse_up(CGEventTapProxy proxy, CGEventType type, CGEventRef event) {
        return false;
    }
};
