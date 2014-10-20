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

WindowEventTap::WindowEventTap(int64_t event_mask, CGEventFlags modifiers, bool raise_window_on_action) :
    EventTap(event_mask),
    modifiers(modifiers),
    raise_window_on_action(raise_window_on_action),
    delta(0),
    completed(false)
{
}

void WindowEventTap::set_modifiers(CGEventFlags modifiers)
{
    this->modifiers = modifiers;
}

void WindowEventTap::worker_thread_perform(void)
{
    int64_t delta;
    while ((delta = this->delta.exchange(0)) != 0 || !this->completed) {
        auto start = std::chrono::high_resolution_clock::now();
        if (delta != 0) {
            int32_t delta_x = ((int32_t *)&delta)[0];
            int32_t delta_y = ((int32_t *)&delta)[1];

            this->on_drag(delta_x, delta_y);
        }
        auto end = std::chrono::high_resolution_clock::now();

        static const auto desired_duration = std::chrono::microseconds(16667);
        auto actual_duration = end - start;
        if (actual_duration < desired_duration) {
            std::this_thread::sleep_for(desired_duration - actual_duration);
        }
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

    this->delta = 0;
    this->completed = false;
    this->worker_thread = std::thread(
        [this](void) {
            this->worker_thread_perform();
        });

    return true;
}

bool WindowEventTap::on_mouse_drag(CGEventTapProxy proxy, CGEventType type, CGEventRef event, int64_t delta_x, int64_t delta_y)
{
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
    assert(this->delta == 0);

    return true;
}

MoveWindowEventTap::MoveWindowEventTap(int64_t event_mask, CGEventFlags modifiers, bool raise_window_on_action) :
    WindowEventTap(event_mask, modifiers, raise_window_on_action)
{
}

bool MoveWindowEventTap::on_drag_start(void)
{
    assert(this->window);
    assert(!this->window_position.x && !this->window_position.y);
    this->window_position = window_get_position(window);
    return true;
}

void MoveWindowEventTap::on_drag(int64_t delta_x, int64_t delta_y)
{
    assert(window);
    this->window_position.x += delta_x;
    this->window_position.y += delta_y;
    window_set_position(window, this->window_position);
}

void MoveWindowEventTap::on_drag_end(void) {
    this->window_position = { 0, 0 };
}

ResizeWindowEventTap::ResizeWindowEventTap(int64_t event_mask, CGEventFlags modifiers, bool raise_window_on_action) :
    WindowEventTap(event_mask, modifiers, raise_window_on_action)
{
}

bool ResizeWindowEventTap::on_drag_start(void)
{
    assert(window);
    assert(!this->window_size.width && !this->window_size.height);
    this->window_size = window_get_size(window);
    return true;
}

void ResizeWindowEventTap::on_drag(int64_t delta_x, int64_t delta_y)
{
    assert(window);
    this->window_size.width += delta_x;
    this->window_size.height += delta_y;
    window_set_size(window, this->window_size);
}

void ResizeWindowEventTap::on_drag_end(void)
{
    this->window_size = { 0, 0 };
}

