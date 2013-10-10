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

#include <cassert>
#include <cstdint>
#include <cstdio>
#include <chrono>
#include <thread>
#include <mach/mach_time.h>
#include <mach/task_policy.h>
#include <mach/thread_act.h>
#include <pthread.h>

#include <ApplicationServices/ApplicationServices.h>
#include <CoreFoundation/CoreFoundation.h>
#include <Foundation/Foundation.h>
#include "config.h"

static AXUIElementRef accessibility_object = AXUIElementCreateSystemWide();
struct cg_event_callback_data;

// Returns true when the mouse event should be consumed
typedef bool (*mouse_down_callback_t)(
    CGEventTapProxy proxy, CGEventType type, CGEventRef event, cg_event_callback_data *data, AXUIElementRef window);
typedef bool (*mouse_drag_callback_t)(
    CGEventTapProxy proxy, CGEventType type, CGEventRef event, cg_event_callback_data *data);
typedef bool (*mouse_up_callback_t)(
    CGEventTapProxy proxy, CGEventType type, CGEventRef event, cg_event_callback_data *data);

struct mouse_callbacks {
    mouse_down_callback_t mouse_down_callback;
    mouse_drag_callback_t mouse_drag_callback;
    mouse_up_callback_t mouse_up_callback;
};

struct cg_event_callback_data {
    CGEventFlags modifiers;
    mouse_down_callback_t mouse_down_callback;
    mouse_drag_callback_t mouse_drag_callback;
    mouse_up_callback_t mouse_up_callback;
    CGPoint last_mouse_position;
    ::std::atomic<void *> extra;
};

struct window_move_callback_data {
    AXUIElementRef window;
    ::std::atomic<int64_t> delta;
    ::std::atomic<bool> completed;
    CGPoint window_position;
};

struct window_resize_callback_data {
    AXUIElementRef window;
    ::std::atomic<int64_t> delta;
    ::std::atomic<bool> completed;
    CGSize window_size;
};

CGPoint ax_ui_element_get_position(AXUIElementRef element) {
    AXValueRef position_wrapper = nullptr;
    CGPoint result;

    if (AXUIElementCopyAttributeValue(element, kAXPositionAttribute, (CFTypeRef *)&position_wrapper) != kAXErrorSuccess) {
        assert(false && "Unable to get AXValueRef for element position");
    }

    assert(AXValueGetType(position_wrapper) == kAXValueCGPointType);
    if (!AXValueGetValue(position_wrapper, kAXValueCGPointType, &result)) {
        assert(false && "Unable to get CGPoint for element position");
    }

    CFRelease(position_wrapper);
    return result;
}

void ax_ui_element_set_position(AXUIElementRef element, CGPoint position) {
    AXValueRef position_wrapper = AXValueCreate(kAXValueCGPointType, &position);
    AXUIElementSetAttributeValue(element, kAXPositionAttribute, position_wrapper);
    CFRelease(position_wrapper);
}

CGSize ax_ui_element_get_size(AXUIElementRef element) {
    AXValueRef size_wrapper = nullptr;
    CGSize result;

    if (AXUIElementCopyAttributeValue(element, kAXSizeAttribute, (CFTypeRef *)&size_wrapper) != kAXErrorSuccess) {
        assert(false && "Unable to get AXValueRef for element size");
    }

    assert(AXValueGetType(size_wrapper) == kAXValueCGSizeType);
    if (!AXValueGetValue(size_wrapper, kAXValueCGSizeType, &result)) {
        assert(false && "Unable to get CGSize for element size");
    }

    CFRelease(size_wrapper);
    return result;
}

void ax_ui_element_set_size(AXUIElementRef element, CGSize size) {
    AXValueRef size_wrapper = AXValueCreate(kAXValueCGSizeType, &size);
    AXUIElementSetAttributeValue(element, kAXSizeAttribute, size_wrapper);
    CFRelease(size_wrapper);
}

CGEventRef cg_event_callback(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *data) {
    bool consume_event = false;
    AXUIElementRef element = nullptr;
    struct cg_event_callback_data *callback_data = static_cast<cg_event_callback_data *>(data);

    assert(AXAPIEnabled() || AXIsProcessTrusted());

    switch (type) {
        case kCGEventLeftMouseDown:
        {
            CGPoint location = CGEventGetLocation(event);
            CFStringRef element_role = nullptr;
            CGEventFlags flags = CGEventGetFlags(event);

            if ((flags & callback_data->modifiers) != callback_data->modifiers) {
                goto abort;
            }

            CGEventSetFlags(event, flags | kCGEventFlagMaskNonCoalesced);

            if (AXUIElementCopyElementAtPosition(accessibility_object, location.x, location.y, &element) != kAXErrorSuccess) {
                NSLog(@"Failed to find element at (%f, %f)\n", location.x, location.y);
                goto abort;
            }

            AXUIElementCopyAttributeValue(element, kAXRoleAttribute, (CFTypeRef *)&element_role);
            if (CFStringCompare(kAXWindowRole, element_role, 0) != kCFCompareEqualTo) {
                AXUIElementRef window = nullptr;

                if (AXUIElementCopyAttributeValue(element, kAXWindowAttribute, (CFTypeRef *)&window) != kAXErrorSuccess) {
                    NSLog(@"Failed to copy window for element at (%f, %f)\n", location.x, location.y);
                    goto abort;
                } else {
                    if (element != window) {
                        CFRelease(element);
                        element = window;
                    }
                }
            }

            callback_data->last_mouse_position = location;
            if (callback_data->mouse_down_callback) {
                consume_event = callback_data->mouse_down_callback(proxy, type, event, callback_data, element);
            }

        abort:
            if (element_role) CFRelease(element_role);
            break;
        }

        case kCGEventLeftMouseDragged:
            if (callback_data->extra && callback_data->mouse_drag_callback) {
                consume_event = callback_data->mouse_drag_callback(proxy, type, event, callback_data);
            }
            break;

        case kCGEventLeftMouseUp:
            if (callback_data->extra && callback_data->mouse_up_callback) {
                consume_event = callback_data->mouse_up_callback(proxy, type, event, callback_data);
            }
            break;

        case kCGEventTapDisabledByTimeout:
            NSLog(@"Event tap was disabled by timeout, aborting\n");
            break;

        default:
            NSLog(@"Unknown event %d\n", type);
            break;
    }

    if (element) CFRelease(element);

    return consume_event ? nullptr : event;
}

void create_event_tap(CFRunLoopRef run_loop, CGEventFlags modifiers, mouse_callbacks callbacks) {
    auto callback_data = new cg_event_callback_data {
        .modifiers = modifiers,
        .mouse_down_callback = callbacks.mouse_down_callback,
        .mouse_drag_callback = callbacks.mouse_drag_callback,
        .mouse_up_callback = callbacks.mouse_up_callback
    };

    callback_data->extra = nullptr;

    CFMachPortRef event_tap =
        CGEventTapCreate(
            kCGSessionEventTap,
            kCGTailAppendEventTap,
            kCGEventTapOptionDefault,
            CGEventMaskBit(kCGEventLeftMouseDown) |
            CGEventMaskBit(kCGEventLeftMouseDragged) |
            CGEventMaskBit(kCGEventLeftMouseUp),
            cg_event_callback,
            callback_data);
    CFRunLoopSourceRef run_loop_source = CFMachPortCreateRunLoopSource(nullptr, event_tap, 0);
    CFRunLoopAddSource(run_loop, run_loop_source, kCFRunLoopCommonModes);
    CFRelease(run_loop_source);
    CFRelease(event_tap);
}

void suicide_callback(CFNotificationCenterRef, void *, CFStringRef, const void *, CFDictionaryRef userInfo) {
    NSDictionary *data = (__bridge NSDictionary *)userInfo;
    NSLog(@"Received suicide notification from sender '%@' for reason '%@'",
        [data objectForKey: @"sender"],
        [data objectForKey: @"reason"]);
    CFRunLoopStop(CFRunLoopGetMain());
}

void status_callback(CFNotificationCenterRef notification_center, void *, CFStringRef, const void *, CFDictionaryRef userInfo) {
    NSDictionary *data = (__bridge NSDictionary *)userInfo;
    NSLog(@"Received status query from sender '%@'", [data objectForKey: @"sender"]);
    CFNotificationCenterPostNotification(
        notification_center,
        NOTIFICATION_ALIVE,
        NOTIFICATION_OBJECT,
        (__bridge CFDictionaryRef)@{@"version" : @VERSION_STRING},
        true);
}

void set_thread_realtime(thread_port_t mach_thread_id ) {
    thread_extended_policy_data_t policy;
    policy.timeshare = 0;
    thread_policy_set(
        mach_thread_id,
        THREAD_EXTENDED_POLICY,
        (thread_policy_t)&policy,
        THREAD_EXTENDED_POLICY_COUNT);

    thread_precedence_policy_data_t precedence;
    precedence.importance = 63;
    thread_policy_set(
        mach_thread_id,
        THREAD_PRECEDENCE_POLICY,
        (thread_policy_t)&precedence,
        THREAD_PRECEDENCE_POLICY_COUNT);

    const double time_quantum = 16.66666666666666666;
    const double time_needed = 0.2 * time_quantum;
    const double time_allowed = 0.85 * time_quantum;

    mach_timebase_info_data_t tb_info;
    mach_timebase_info(&tb_info);
    double ms_to_abs_time =
        ((double)tb_info.denom / (double)tb_info.numer) * 1000000;

    thread_time_constraint_policy_data_t time_constraints;
    time_constraints.period = time_quantum * ms_to_abs_time;
    time_constraints.computation = time_needed * ms_to_abs_time;
    time_constraints.constraint = time_allowed * ms_to_abs_time;
    time_constraints.preemptible = 0;

    thread_policy_set(
        mach_thread_id,
        THREAD_TIME_CONSTRAINT_POLICY,
        (thread_policy_t)&time_constraints,
        THREAD_TIME_CONSTRAINT_POLICY_COUNT);
}

int main(int, const char *[]) {
    CFNotificationCenterRef notification_center = CFNotificationCenterGetDistributedCenter();
    CFNotificationCenterAddObserver(
        notification_center,
        nullptr,
        suicide_callback,
        NOTIFICATION_SUICIDE,
        NOTIFICATION_OBJECT,
        CFNotificationSuspensionBehaviorDeliverImmediately);
    CFNotificationCenterAddObserver(
        notification_center,
        nullptr,
        status_callback,
        NOTIFICATION_STATUS,
        NOTIFICATION_OBJECT,
        CFNotificationSuspensionBehaviorDeliverImmediately);

    mouse_callbacks window_move_callbacks = {
        [](CGEventTapProxy, CGEventType, CGEventRef, cg_event_callback_data *data, AXUIElementRef window) {
            auto move_data = new window_move_callback_data {
                .window = static_cast<AXUIElementRef>(CFRetain(window)),
                .window_position = ax_ui_element_get_position(window)
            };

            move_data->delta = 0;
            move_data->completed = false;

            assert(!data->extra);
            data->extra = move_data;
            ::std::thread([move_data](void) {
                set_thread_realtime(pthread_mach_thread_np(pthread_self()));
                while (!move_data->completed) {
                    int64_t delta = move_data->delta.exchange(0);

                    if (delta != 0) {
                        int delta_x = ((int32_t *)&delta)[0];
                        int delta_y = ((int32_t *)&delta)[1];
                        move_data->window_position.x += delta_x;
                        move_data->window_position.y += delta_y;

                        ax_ui_element_set_position(
                            move_data->window,
                            move_data->window_position);
                    }

                    ::std::this_thread::sleep_for(::std::chrono::milliseconds(1));
                }

                CFRelease(move_data->window);
                delete move_data;
            }).detach();
            return true;
        },
        [](CGEventTapProxy, CGEventType, CGEventRef event, cg_event_callback_data *data) {
            if (!data->extra) return false;

            auto move_data = static_cast<window_move_callback_data *>(data->extra.load());

            assert(move_data);

            CGPoint location = CGEventGetLocation(event);
            int64_t delta_x = location.x - data->last_mouse_position.x;
            int64_t delta_y = location.y - data->last_mouse_position.y;
            data->last_mouse_position = location;

            int64_t previous = move_data->delta.load();
            int64_t replacement;
            do {
                replacement = previous;
                ((int32_t *)&replacement)[0] += delta_x;
                ((int32_t *)&replacement)[1] += delta_y;
            } while (!move_data->delta.compare_exchange_weak(previous, replacement));

            return true;
        },
        [](CGEventTapProxy, CGEventType, CGEventRef, cg_event_callback_data *data) {
            if (!data->extra) return false;

            static_cast<window_move_callback_data *>(data->extra.load())->completed = true;
            data->extra = nullptr;
            return true;
        }
    };

    mouse_callbacks window_resize_callbacks = {
        [](CGEventTapProxy, CGEventType, CGEventRef, cg_event_callback_data *data, AXUIElementRef window) {
            auto resize_data = new window_resize_callback_data {
                .window = static_cast<AXUIElementRef>(CFRetain(window)),
                .window_size = ax_ui_element_get_size(window)
            };

            resize_data->delta = 0;
            resize_data->completed = false;

            assert(!data->extra);
            data->extra = resize_data;
            ::std::thread([resize_data](void) {
                set_thread_realtime(pthread_mach_thread_np(pthread_self()));
                while (!resize_data->completed) {
                    int64_t delta = resize_data->delta.exchange(0);

                    if (delta != 0) {
                        int delta_x = ((int32_t *)&delta)[0];
                        int delta_y = ((int32_t *)&delta)[1];
                        resize_data->window_size.width += delta_x;
                        resize_data->window_size.height += delta_y;

                        ax_ui_element_set_size(
                            resize_data->window,
                            resize_data->window_size);
                    }

                    ::std::this_thread::sleep_for(::std::chrono::milliseconds(1));
                }

                CFRelease(resize_data->window);
                delete resize_data;
            }).detach();
            return true;
        },
        [](CGEventTapProxy, CGEventType, CGEventRef event, cg_event_callback_data *data) {
            if (!data->extra) return false;

            auto resize_data = static_cast<window_move_callback_data *>(data->extra.load());
            assert(resize_data);

            CGPoint location = CGEventGetLocation(event);
            int64_t delta_x = location.x - data->last_mouse_position.x;
            int64_t delta_y = location.y - data->last_mouse_position.y;
            data->last_mouse_position = location;

            int64_t previous = resize_data->delta.load();
            int64_t replacement;
            do {
                replacement = previous;
                ((int32_t *)&replacement)[0] += delta_x;
                ((int32_t *)&replacement)[1] += delta_y;
            } while (!resize_data->delta.compare_exchange_weak(previous, replacement));

            return true;
        },
        [](CGEventTapProxy, CGEventType, CGEventRef, cg_event_callback_data *data) {
            if (!data->extra) return false;

            static_cast<window_move_callback_data *>(data->extra.load())->completed = true;
            data->extra = nullptr;
            return true;
        }
    };

    create_event_tap(
        CFRunLoopGetCurrent(),
        kCGEventFlagMaskCommand | kCGEventFlagMaskShift,
        window_move_callbacks);

    create_event_tap(
        CFRunLoopGetCurrent(),
        kCGEventFlagMaskAlternate | kCGEventFlagMaskShift,
        window_resize_callbacks);

    NSLog(@"metamove v%s successfully initialized.", VERSION_STRING);
    CFRunLoopRun();
    return 0;
}
