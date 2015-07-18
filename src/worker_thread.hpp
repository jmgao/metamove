#pragma once

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

#include <ApplicationServices/ApplicationServices.h>

#include <cstdint>
#include <atomic>
#include <deque>
#include <memory>
#include <mutex>
#include <thread>

class WindowEventTap;

struct WindowOperation {
    AXUIElementRef window = nullptr;
    std::atomic<int32_t> x;
    std::atomic<int32_t> y;
    std::atomic<bool> completed;
    WindowEventTap *event_tap;

    ~WindowOperation(void)
    {
        if (this->window) {
            CFRelease(this->window);
        }
    }
};

class WorkerThread {
private:
    WorkerThread(void);
    void run(void);

public:
    static WorkerThread instance;

    std::mutex mutex;
    std::condition_variable cv;
    std::deque<std::shared_ptr<WindowOperation>> windows;

    std::shared_ptr<WindowOperation> begin_operation(int32_t x, int32_t y, WindowEventTap *event_tap);
};
