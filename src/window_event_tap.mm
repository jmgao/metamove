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

#include <Foundation/Foundation.h>
#include <cstdint>
#include "window.hpp"
#include "window_event_tap.hpp"

WindowEventTap::WindowEventTap(int64_t event_mask, CGEventFlags modifiers, bool raise_window_on_action) :
    EventTap(event_mask),
    modifiers(modifiers),
    raise_window_on_action(raise_window_on_action),
    completed(false)
{
}

void WindowEventTap::set_modifiers(CGEventFlags modifiers)
{
    this->modifiers = modifiers;
}

void WindowEventTap::worker_thread_perform(void)
{
    int old_x = -1, old_y = -1;
    while (!this->completed) {
        int current_x, current_y;
        std::tie(current_x, current_y) = std::tie(this->x, this->y);
        if (old_x != current_x || old_y != current_y) {
            // auto start = std::chrono::high_resolution_clock::now();
            this->on_drag(this->x, this->y);
            // auto end = std::chrono::high_resolution_clock::now();
            // using ms = std::chrono::duration<float, std::chrono::milliseconds::period>;
            // NSLog(@"Operation %d duration: %0.3f ms", i, ms(end - start).count());
        } else {
            static const auto desired_duration = std::chrono::microseconds(16667);
            std::this_thread::sleep_for(desired_duration);
        }

        std::tie(old_x, old_y) = std::tie(current_x, current_y);
    }
}

bool WindowEventTap::on_mouse_down(CGEventTapProxy proxy, CGEventType type, CGEventRef event)
{
    if (!modifiers) {
        return false;
    }

    CGEventFlags flags = CGEventGetFlags(event);
    if ((flags & this->modifiers) != this->modifiers) {
        return false;
    }

    this->window = window_get_from_point(CGEventGetLocation(event));
    if (!this->window) {
        return false;
    }

    if (!this->on_drag_start()) {
        this->window = nullptr;
        return false;
    }

    CGEventSetFlags(event, flags | kCGEventFlagMaskNonCoalesced);

    if (this->raise_window_on_action) {
        window_raise(this->window);
    }

    assert(!this->worker_thread.joinable() && "Worker thread is still running");

    this->completed = false;
    this->worker_thread = std::thread(
        [this](void) {
            this->worker_thread_perform();
        });

    return true;
}

bool WindowEventTap::on_mouse_drag(CGEventTapProxy proxy, CGEventType type, CGEventRef event, CGFloat delta_x, CGFloat delta_y)
{
    if (!this->window) {
        return false;
    }

    this->x += delta_x;
    this->y += delta_y;

    assert(this->worker_thread.joinable() && "Worker thread died unexpectedly");
    return true;
}

bool WindowEventTap::on_mouse_up(CGEventTapProxy proxy, CGEventType type, CGEventRef event)
{
    if (!this->window) {
        return false;
    }

    assert(this->worker_thread.joinable() && "Worker thread died unexpectedly");
    this->completed = true;
    this->worker_thread.join();

    this->on_drag_end();
    CFRelease(this->window);
    this->window = nullptr;

    return true;
}

MoveWindowEventTap::MoveWindowEventTap(int64_t event_mask, CGEventFlags modifiers, bool raise_window_on_action) :
    WindowEventTap(event_mask, modifiers, raise_window_on_action)
{
}

bool MoveWindowEventTap::on_drag_start(void)
{
    assert(this->window);

    CGPoint position = window_get_position(window);
    std::tie(this->x, this->y) = std::tie(position.x, position.y);

    return true;
}

void MoveWindowEventTap::on_drag(CGFloat x, CGFloat y)
{
    assert(window);
    window_set_position(window, {x, y});
}

void MoveWindowEventTap::on_drag_end(void)
{
}

ResizeWindowEventTap::ResizeWindowEventTap(int64_t event_mask, CGEventFlags modifiers, bool raise_window_on_action) :
    WindowEventTap(event_mask, modifiers, raise_window_on_action)
{
}

bool ResizeWindowEventTap::on_drag_start(void)
{
    assert(window);

    CGSize size = window_get_size(window);
    std::tie(this->x, this->y) = std::tie(size.width, size.height);

    return true;
}

void ResizeWindowEventTap::on_drag(CGFloat x, CGFloat y)
{
    assert(window);
    window_set_size(window, {x, y});
}

void ResizeWindowEventTap::on_drag_end(void)
{
}

