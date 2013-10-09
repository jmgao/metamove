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
#include <cstdio>
#include <chrono>
#include <thread>
#include <ApplicationServices/ApplicationServices.h>
#include <CoreFoundation/CoreFoundation.h>

static AXUIElementRef accessibility_object = AXUIElementCreateSystemWide();
struct cg_event_callback_data;

// Returns true when the mouse event should be consumed
typedef bool (*mouse_down_callback_t)(CGEventTapProxy proxy, CGEventType type, CGEventRef event, cg_event_callback_data *data, AXUIElementRef window);
typedef bool (*mouse_drag_callback_t)(CGEventTapProxy proxy, CGEventType type, CGEventRef event, cg_event_callback_data *data);
typedef bool (*mouse_up_callback_t)(CGEventTapProxy proxy, CGEventType type, CGEventRef event, cg_event_callback_data *data);

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
    ::std::atomic<void *> extra;
};

struct window_move_callback_data {
    AXUIElementRef window;
    ::std::atomic<int> delta_x;
    ::std::atomic<int> delta_y;
    ::std::atomic<bool> completed;
    CGPoint window_position;
};

struct window_resize_callback_data {
    AXUIElementRef window;
    ::std::atomic<int> delta_x;
    ::std::atomic<int> delta_y;
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

    assert(AXAPIEnabled());

    switch (type) {
        case kCGEventLeftMouseDown:
        {
            CGPoint location = CGEventGetLocation(event);
            CFStringRef element_role = nullptr;

            if ((CGEventGetFlags(event) & callback_data->modifiers) != callback_data->modifiers) {
                goto abort;
            }

            if (AXUIElementCopyElementAtPosition(accessibility_object, location.x, location.y, &element) != kAXErrorSuccess) {
                printf("Failed to find element at (%f, %f)\n", location.x, location.y);
                goto abort;
            }

            AXUIElementCopyAttributeValue(element, kAXRoleAttribute, (CFTypeRef *)&element_role);
            if (CFStringCompare(kAXWindowRole, element_role, 0) != kCFCompareEqualTo) {
                AXUIElementRef window = nullptr;

                if (AXUIElementCopyAttributeValue(element, kAXWindowAttribute, (CFTypeRef *)&window) != kAXErrorSuccess) {
                    printf("Failed to copy window for element at (%f, %f)\n", location.x, location.y);
                    goto abort;
                } else {
                    if (element != window) {
                        CFRelease(element);
                        element = window;
                    }
                }
            }

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
            printf("Timed out, what\n");
            break;

        default:
            printf("Unknown event %d\n", type);
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
            kCGHeadInsertEventTap, //kCGTailAppendEventTap,
            kCGEventTapOptionDefault,
            CGEventMaskBit(kCGEventLeftMouseDown) | CGEventMaskBit(kCGEventLeftMouseDragged) | CGEventMaskBit(kCGEventLeftMouseUp),
            cg_event_callback,
            callback_data);
    CFRunLoopSourceRef run_loop_source = CFMachPortCreateRunLoopSource(nullptr, event_tap, 0);
    CFRunLoopAddSource(run_loop, run_loop_source, kCFRunLoopCommonModes);
}

int main(int, const char *[]) {
    mouse_callbacks window_move_callbacks = {
        [](CGEventTapProxy, CGEventType, CGEventRef, cg_event_callback_data *data, AXUIElementRef window) {
            auto move_data = new window_move_callback_data {
                .window = static_cast<AXUIElementRef>(CFRetain(window)),
                .window_position = ax_ui_element_get_position(window)
            };

            move_data->delta_x = 0;
            move_data->delta_y = 0;
            move_data->completed = false;

            assert(!data->extra);
            data->extra = move_data;
            ::std::thread([move_data](void) {
                while (!move_data->completed) {
                    int delta_x = move_data->delta_x.exchange(0);
                    int delta_y = move_data->delta_y.exchange(0);

                    if (delta_x != 0 || delta_y != 0) {
                        move_data->window_position.x += delta_x;
                        move_data->window_position.y += delta_y;

                        ax_ui_element_set_position(
                            move_data->window,
                            move_data->window_position);
                    }
                    ::std::this_thread::sleep_for(::std::chrono::microseconds(8333)); // 120 Hz
                }

                CFRelease(move_data->window);
                delete move_data;
            }).detach();
            return true;
        },
        [](CGEventTapProxy, CGEventType, CGEventRef event, cg_event_callback_data *data) {
            if (!data->extra) return false;

            auto move_data = static_cast<window_move_callback_data *>(data->extra.load());
            int delta_x = CGEventGetIntegerValueField(event, kCGMouseEventDeltaX);
            int delta_y = CGEventGetIntegerValueField(event, kCGMouseEventDeltaY);

            assert(move_data);
            move_data->delta_x += delta_x;
            move_data->delta_y += delta_y;
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

            resize_data->delta_x = 0;
            resize_data->delta_y = 0;
            resize_data->completed = false;

            assert(!data->extra);
            data->extra = resize_data;
            ::std::thread([resize_data](void) {
                while (!resize_data->completed) {
                    int delta_x = resize_data->delta_x.exchange(0);
                    int delta_y = resize_data->delta_y.exchange(0);

                    if (delta_x != 0 || delta_y != 0) {
                        resize_data->window_size.width += delta_x;
                        resize_data->window_size.height += delta_y;

                        ax_ui_element_set_size(
                            resize_data->window,
                            resize_data->window_size);
                    }
                    ::std::this_thread::sleep_for(::std::chrono::microseconds(8333)); // 120 Hz
                }

                CFRelease(resize_data->window);
                delete resize_data;
            }).detach();
            return true;
        },
        [](CGEventTapProxy, CGEventType, CGEventRef event, cg_event_callback_data *data) {
            if (!data->extra) return false;

            auto resize_data = static_cast<window_move_callback_data *>(data->extra.load());
            int delta_x = CGEventGetIntegerValueField(event, kCGMouseEventDeltaX);
            int delta_y = CGEventGetIntegerValueField(event, kCGMouseEventDeltaY);

            assert(resize_data);
            resize_data->delta_x += delta_x;
            resize_data->delta_y += delta_y;

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

    printf("Initialized...\n");
    CFRunLoopRun();
    return 0;
}
