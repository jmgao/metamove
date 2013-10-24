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
#include <atomic>
#include <thread>
#include "event_tap.hpp"

class WindowEventTap : public EventTap {
public:
    using on_drag_start_callback_t = ::std::function< bool (AXUIElementRef window) >;
    using on_drag_callback_t = ::std::function< bool (AXUIElementRef window, int64_t delta_x, int64_t delta_y) >;
    using on_drag_end_callback_t = ::std::function< bool (AXUIElementRef window) >;

protected:
    CGEventFlags modifiers;
    AXUIElementRef window = nullptr;
    on_drag_start_callback_t on_drag_start_callback;
    on_drag_callback_t on_drag_callback;
    on_drag_end_callback_t on_drag_end_callback;
    bool raise_window_on_action;
    ::std::atomic<int64_t> delta;
    ::std::atomic<bool> completed;
    ::std::thread worker_thread;

public:
    WindowEventTap(
        int64_t event_mask,
        CGEventFlags modifiers,
        on_drag_start_callback_t on_drag_start_callback,
        on_drag_callback_t on_drag_callback,
        on_drag_end_callback_t on_drag_end_callback,
        bool raise_window_on_action);

protected:
    void worker_thread_perform(void);

    virtual bool on_mouse_down(CGEventTapProxy proxy, CGEventType type, CGEventRef event) override;

    virtual bool on_mouse_drag(CGEventTapProxy proxy, CGEventType type, CGEventRef event, int64_t delta_x, int64_t delta_y) override;

    virtual bool on_mouse_up(CGEventTapProxy proxy, CGEventType type, CGEventRef event) override;
};

class MoveWindowEventTap : public WindowEventTap {
private:
    CGPoint window_position = { 0, 0 };

public:
    MoveWindowEventTap(
        int64_t event_mask,
        CGEventFlags modifiers,
        bool raise_window_on_action);

private:
    bool on_drag_start(AXUIElementRef window);
    bool on_drag(AXUIElementRef window, int64_t delta_x, int64_t delta_y);
    bool on_drag_end(AXUIElementRef window);
};

class ResizeWindowEventTap : public WindowEventTap {
private:
    CGSize window_size = { 0, 0 };

public:
    ResizeWindowEventTap(
        int64_t event_mask,
        CGEventFlags modifiers,
        bool raise_window_on_action);

private:
    bool on_drag_start(AXUIElementRef window);
    bool on_drag(AXUIElementRef window, int64_t delta_x, int64_t delta_y);
    bool on_drag_end(AXUIElementRef window);
};
