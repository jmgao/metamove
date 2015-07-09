/*
 * metamove - XFree86 window movement for OS X
 * Copyright (C) 2015 jmgao
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

#include <mutex>

#include "window.hpp"
#include "window_event_tap.hpp"
#include "worker_thread.hpp"

struct WindowEventTap;

WorkerThread WorkerThread::instance;

WorkerThread::WorkerThread(void)
{
    std::thread(
        [this](void) {
            this->run();
        }).detach();
}

void WorkerThread::run(void)
{
    while (true) {
        std::unique_lock<std::mutex> lock(this->mutex);
        this->cv.wait(lock, [this](void) { return !this->windows.empty(); });

        std::shared_ptr<WindowOperation> op = windows.front();
        windows.pop_front();
        lock.unlock();

        int old_x = -1, old_y = -1;

        static const auto half_frame = std::chrono::microseconds(8333);
        while (!op->completed) {
            if (!op->window) {
                NSLog(@"No window, sleeping for half of a frame");
                std::this_thread::sleep_for(half_frame);
                continue;
            }

            int current_x, current_y;
            std::tie(current_x, current_y) = std::tie(op->x, op->y);
            if (old_x != current_x || old_y != current_y) {
                auto start = std::chrono::high_resolution_clock::now();
                op->event_tap->on_drag(op, op->x, op->y);
                auto end = std::chrono::high_resolution_clock::now();
                using ms = std::chrono::duration<float, std::chrono::milliseconds::period>;
                NSLog(@"Operation duration: %0.3f ms", ms(end - start).count());
            } else {
                std::this_thread::sleep_for(half_frame);
            }

            std::tie(old_x, old_y) = std::tie(current_x, current_y);
        }
    }
}

std::shared_ptr<WindowOperation> WorkerThread::begin_operation(int32_t x, int32_t y, WindowEventTap *event_tap)
{
    auto op = std::make_shared<WindowOperation>();

    op->window = nullptr;
    op->x = x;
    op->y = y;
    op->completed = false;
    op->event_tap = event_tap;

    std::thread([op](void) {
        auto window = window_get_from_point({CGFloat(op->x), CGFloat(op->y)});
        if (!window) {
            op->completed = true;
        }

        if (!op->event_tap->on_drag_start(op, window)) {
            op->completed = true;
        }

        if (op->event_tap->raise_window_on_action) {
            window_raise(window);
        }

        op->window = window;
    }).detach();

    {
        std::unique_lock<std::mutex> lock(this->mutex);
        this->windows.push_back(op);
    }

    this->cv.notify_one();
    return op;
}
