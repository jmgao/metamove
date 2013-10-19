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
#include "window.hpp"
#include "window_event_tap.hpp"

WindowEventTap::WindowEventTap(
    int64_t event_mask,
    CGEventFlags modifiers,
    on_drag_start_callback_t on_drag_start_callback,
    on_drag_callback_t on_drag_callback,
    on_drag_end_callback_t on_drag_end_callback,
    bool raise_window_on_action) :
        EventTap(event_mask),
        modifiers(modifiers),
        on_drag_start_callback(on_drag_start_callback),
        on_drag_callback(on_drag_callback),
        on_drag_end_callback(on_drag_end_callback),
        raise_window_on_action(raise_window_on_action),
        delta(0),
        completed(false)
{

}

void WindowEventTap::worker_thread_perform(void) {
    set_thread_realtime(pthread_mach_thread_np(pthread_self()));

    int64_t delta;
    while ((delta = this->delta.exchange(0)) != 0 || !this->completed) {
        if (delta != 0) {
            int32_t delta_x = ((int32_t *)&delta)[0];
            int32_t delta_y = ((int32_t *)&delta)[1];

            this->on_drag_callback(this->window, delta_x, delta_y);
        }

        ::std::this_thread::sleep_for(::std::chrono::milliseconds(1));
    }

}

bool WindowEventTap::on_mouse_down(CGEventTapProxy proxy, CGEventType type, CGEventRef event) {
    CGEventFlags flags = CGEventGetFlags(event);
    if ((flags & this->modifiers) != this->modifiers) {
        return false;
    }

    auto window = window_get_from_point(CGEventGetLocation(event));
    if (!window) {
        return false;
    }

    if (!this->on_drag_start_callback(window)) {
        return false;
    }

    CGEventSetFlags(event, flags | kCGEventFlagMaskNonCoalesced);
    this->window = window;
    if (this->raise_window_on_action) {
        AXUIElementRef application = window_copy_application(this->window);

        if (application) {
            // This brings every window of the application to the front, which kinda sucks.
            //AXUIElementSetAttributeValue(application, kAXFrontmostAttribute, kCFBooleanTrue);
            CFRelease(application);
        }

        AXUIElementPerformAction(this->window, kAXRaiseAction);
    }

    assert(!this->worker_thread.joinable() && "Worker thread is still running");

    this->delta = 0;
    this->completed = false;
    this->worker_thread = ::std::thread(
        [this](void) {
            this->worker_thread_perform();
        });

    return true;
}

bool WindowEventTap::on_mouse_drag(CGEventTapProxy proxy, CGEventType type, CGEventRef event, int64_t delta_x, int64_t delta_y) {
    if (!this->window) {
        return false;
    }

    int64_t previous = this->delta.load();
    int64_t replacement;
    do {
        replacement = previous;
        ((int32_t *)&replacement)[0] += delta_x;
        ((int32_t *)&replacement)[1] += delta_y;
    } while (!this->delta.compare_exchange_weak(previous, replacement));

    assert(this->worker_thread.joinable() && "Worker thread died unexpectedly");
    return true;
}

bool WindowEventTap::on_mouse_up(CGEventTapProxy proxy, CGEventType type, CGEventRef event) {
    if (!this->window) {
        return false;
    }

    assert(this->worker_thread.joinable() && "Worker thread died unexpectedly");
    this->completed = true;
    this->worker_thread.join();

    this->on_drag_end_callback(this->window);
    CFRelease(this->window);
    this->window = nullptr;
    assert(this->delta == 0);

    return true;
}

MoveWindowEventTap::MoveWindowEventTap(
    int64_t event_mask,
    CGEventFlags modifiers,
    bool raise_window_on_action) :
        WindowEventTap(
            event_mask,
            modifiers,
            ::std::bind(&MoveWindowEventTap::on_drag_start, this, ::std::placeholders::_1),
            ::std::bind(&MoveWindowEventTap::on_drag, this, ::std::placeholders::_1, ::std::placeholders::_2, ::std::placeholders::_3),
            ::std::bind(&MoveWindowEventTap::on_drag_end, this, ::std::placeholders::_1),
            raise_window_on_action)
{
}

bool MoveWindowEventTap::on_drag_start(AXUIElementRef window) {
    assert(window);
    assert(!this->window_position.x && !this->window_position.y);
    this->window_position = window_get_position(window);
    return true;
}

bool MoveWindowEventTap::on_drag(AXUIElementRef window, int64_t delta_x, int64_t delta_y) {
    assert(window);
    this->window_position.x += delta_x;
    this->window_position.y += delta_y;
    window_set_position(window, this->window_position);
    return true;
}

bool MoveWindowEventTap::on_drag_end(AXUIElementRef window) {
    this->window_position = { 0, 0 };
    return true;
}

ResizeWindowEventTap::ResizeWindowEventTap(
    int64_t event_mask,
    CGEventFlags modifiers,
    bool raise_window_on_action) :
        WindowEventTap(
            event_mask,
            modifiers,
            ::std::bind(&ResizeWindowEventTap::on_drag_start, this, ::std::placeholders::_1),
            ::std::bind(&ResizeWindowEventTap::on_drag, this, ::std::placeholders::_1, ::std::placeholders::_2, ::std::placeholders::_3),
            ::std::bind(&ResizeWindowEventTap::on_drag_end, this, ::std::placeholders::_1),
            raise_window_on_action)
{
}

bool ResizeWindowEventTap::on_drag_start(AXUIElementRef window) {
    assert(window);
    assert(!this->window_size.width && !this->window_size.height);
    this->window_size = window_get_size(window);
    return true;
}

bool ResizeWindowEventTap::on_drag(AXUIElementRef window, int64_t delta_x, int64_t delta_y) {
    assert(window);
    this->window_size.width += delta_x;
    this->window_size.height += delta_y;
    window_set_size(window, this->window_size);
    return true;
}

bool ResizeWindowEventTap::on_drag_end(AXUIElementRef window) {
    this->window_size = { 0, 0 };
    return true;
}

