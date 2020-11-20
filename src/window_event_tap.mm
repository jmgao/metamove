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
    raise_window_on_action(raise_window_on_action)
{
}

void WindowEventTap::set_modifiers(CGEventFlags modifiers)
{
    this->modifiers = modifiers;
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

    CGPoint event_location = CGEventGetLocation(event);
    this->current_window = WorkerThread::instance.begin_operation(event_location.x, event_location.y, this);

    return true;
}

static void atomic_fetch_add(std::atomic<CGFloat>& atomic, CGFloat rhs) {
    CGFloat prev = atomic.load();
    while (!atomic.compare_exchange_weak(prev, prev + rhs));
}

bool WindowEventTap::on_mouse_drag(CGEventTapProxy proxy, CGEventType type, CGEventRef event, CGFloat delta_x, CGFloat delta_y)
{
    if (!this->current_window) {
        return false;
    }

    atomic_fetch_add(this->current_window->x, delta_x);
    atomic_fetch_add(this->current_window->y, delta_y);

    return true;
}

bool WindowEventTap::on_mouse_up(CGEventTapProxy proxy, CGEventType type, CGEventRef event)
{
    if (!this->current_window) {
        return false;
    }

    this->current_window->completed = true;
    this->on_drag_end(this->current_window);
    this->current_window = nullptr;

    return true;
}

MoveWindowEventTap::MoveWindowEventTap(int64_t event_mask, CGEventFlags modifiers, bool raise_window_on_action) :
    WindowEventTap(event_mask, modifiers, raise_window_on_action)
{
}

bool MoveWindowEventTap::on_drag_start(std::shared_ptr<WindowOperation> window_op, AXUIElementRef window)
{
    assert(window_op);
    assert(window);

    CGPoint position = window_get_position(window);
    std::tie(window_op->x, window_op->y) = std::tie(position.x, position.y);

    return true;
}

void MoveWindowEventTap::on_drag(std::shared_ptr<WindowOperation> window_op, CGFloat x, CGFloat y)
{
    assert(window_op);
    assert(window_op->window);
    window_set_position(window_op->window, {x, y});
}

void MoveWindowEventTap::on_drag_end(std::shared_ptr<WindowOperation> window_op)
{
}

ResizeWindowEventTap::ResizeWindowEventTap(int64_t event_mask, CGEventFlags modifiers, bool raise_window_on_action) :
    WindowEventTap(event_mask, modifiers, raise_window_on_action)
{
}

bool ResizeWindowEventTap::on_drag_start(std::shared_ptr<WindowOperation> window_op, AXUIElementRef window)
{
    assert(window_op);
    assert(window);

    CGSize size = window_get_size(window);
    std::tie(window_op->x, window_op->y) = std::tie(size.width, size.height);

    return true;
}

void ResizeWindowEventTap::on_drag(std::shared_ptr<WindowOperation> window_op, CGFloat x, CGFloat y)
{
    assert(window_op);
    assert(window_op->window);
    window_set_size(window_op->window, {CGFloat(window_op->x), CGFloat(window_op->y)});
}

void ResizeWindowEventTap::on_drag_end(std::shared_ptr<WindowOperation> window_op)
{
}

