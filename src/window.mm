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

#include <ApplicationServices/ApplicationServices.h>
#include <CoreFoundation/CoreFoundation.h>
#include <Foundation/Foundation.h>
#include "window.hpp"

extern "C" AXError _AXUIElementGetWindow(AXUIElementRef, CGWindowID *out) __attribute__((weak_import));

static AXUIElementRef accessibility_object = AXUIElementCreateSystemWide();

AXUIElementRef window_get_from_point(CGPoint point)
{
    AXUIElementRef element = nullptr;
    CFStringRef element_role = nullptr;
    AXUIElementRef window_owner = nullptr;

    // Naive method, fails for Console's message pane
    if (AXUIElementCopyElementAtPosition(accessibility_object, point.x, point.y, &element) == kAXErrorSuccess) {
        if (AXUIElementCopyAttributeValue(element, kAXRoleAttribute, (CFTypeRef *)&element_role) == kAXErrorSuccess) {
            if (CFStringCompare(kAXWindowRole, element_role, 0) != kCFCompareEqualTo) {
                AXUIElementRef window = nullptr;

                if (AXUIElementCopyAttributeValue(element, kAXWindowAttribute, (CFTypeRef *)&window) == kAXErrorSuccess) {
                    if (element != window) {
                        CFRelease(element);
                        element = window;
                    }
                    goto exit;
                }
            }
        } else {
            NSLog(@"Unable to copy role for element, using fallback method");
        }
    } else {
        NSLog(@"Unable to copy element at position (%f, %f), using fallback method", point.x, point.y);
    }

    // Fallback method, find the topmost window that contains the cursor
    {
        NSDictionary *selected_window = nullptr;
        NSArray *window_list = [(NSArray *)CGWindowListCopyWindowInfo(
            kCGWindowListOptionOnScreenOnly | kCGWindowListExcludeDesktopElements,
            kCGNullWindowID) autorelease];
        NSRect window_bounds = NSZeroRect;

        for (NSDictionary *current_window in window_list) {
            NSDictionary *window_bounds_dict = current_window[(NSString *) kCGWindowBounds];

            if (![current_window[(id)kCGWindowLayer] isEqual: @0]) {
                continue;
            }

            int x = [window_bounds_dict[@"X"] intValue];
            int y = [window_bounds_dict[@"Y"] intValue];
            int width = [window_bounds_dict[@"Width"] intValue];
            int height = [window_bounds_dict[@"Height"] intValue];
            NSRect current_window_bounds = NSMakeRect(x, y, width, height);
            if (NSPointInRect(NSPointFromCGPoint(point), current_window_bounds)) {
                window_bounds = current_window_bounds;
                selected_window = current_window;
                break;
            }
        }

        if (!selected_window) {
            NSLog(@"Unable to find window under cursor");
            goto exit;
        }

        // Find the AXUIElement corresponding to the window via its application
        {
            int window_owner_pid = [selected_window[(id)kCGWindowOwnerPID] intValue];
            window_owner = AXUIElementCreateApplication(window_owner_pid);
            CFTypeRef windows_cf = nullptr;
            NSArray *application_windows = nullptr;

            if (AXUIElementCopyAttributeValue(window_owner, kAXWindowsAttribute, &windows_cf) != kAXErrorSuccess) {
                NSLog(@"Failed to find window under cursor");
                goto exit;
            }

            application_windows = (NSArray *) windows_cf;

            // Use a private symbol to get the CGWindowID from the application's windows
            if (_AXUIElementGetWindow) {
                CGWindowID selected_window_id = [selected_window[(id)kCGWindowNumber] intValue];

                if (!selected_window_id) {
                    NSLog(@"Unable to get window ID for selected window");
                    goto exit;
                }

                for (id application_window in application_windows) {
                    AXUIElementRef application_window_ax = (__bridge AXUIElementRef)application_window;
                    CGWindowID application_window_id = 0;

                    if (_AXUIElementGetWindow(application_window_ax, &application_window_id) == kAXErrorSuccess) {
                        if (application_window_id == selected_window_id) {
                            element = application_window_ax;
                            CFRetain(element);
                            goto exit;
                        }
                    } else {
                        NSLog(@"Unable to get window id from AXUIElement");
                    }
                }
            } else {
                NSLog(@"Unable to use _AXUIElementGetWindow, falling back to window bounds comparison");

                for (id application_window in application_windows) {
                    AXUIElementRef application_window_ax = (__bridge AXUIElementRef)application_window;
                    CGPoint application_window_position = window_get_position(application_window_ax);
                    CGSize application_window_size = window_get_size(application_window_ax);

                    NSRect application_window_bounds =
                        NSMakeRect(
                            application_window_position.x,
                            application_window_position.y,
                            application_window_size.width,
                            application_window_size.height);

                    if (NSEqualRects(application_window_bounds, window_bounds)) {
                        element = application_window_ax;
                        CFRetain(element);
                        goto exit;
                    }
                }
            }
        }
    }

exit:
    if (element_role) CFRelease(element_role);
    if (window_owner) CFRelease(window_owner);
    return element;
}

AXUIElementRef window_copy_application(AXUIElementRef window)
{
    AXUIElementRef current = nullptr;
    AXUIElementCopyAttributeValue(window, kAXParentAttribute, (CFTypeRef *)&current);

    while (current) {
        CFStringRef role = nullptr;
        if (AXUIElementCopyAttributeValue(current, kAXRoleAttribute, (CFTypeRef *)&role) != kAXErrorSuccess) {
            NSLog(@"Unable to copy role for element, aborting");
            current = nullptr;
            break;
        }

        if (CFStringCompare(role, kAXApplicationRole, 0) != 0) {
            AXUIElementRef last = current;
            AXUIElementCopyAttributeValue(current, kAXParentAttribute, (CFTypeRef *)&current);
            CFRelease(last);
            CFRelease(role);
        } else {
            CFRelease(role);
            break;
        }
    }

    return current;
}

CGPoint window_get_position(AXUIElementRef window)
{
    AXValueRef position_wrapper = nullptr;
    CGPoint result;

    if (AXUIElementCopyAttributeValue(window, kAXPositionAttribute, (CFTypeRef *)&position_wrapper) != kAXErrorSuccess) {
        assert(false && "Unable to get AXValueRef for window position");
    }

    assert(AXValueGetType(position_wrapper) == kAXValueCGPointType);
    if (!AXValueGetValue(position_wrapper, kAXValueCGPointType, &result)) {
        assert(false && "Unable to get CGPoint for window position");
    }

    CFRelease(position_wrapper);
    return result;
}

void window_set_position(AXUIElementRef window, CGPoint position)
{
    AXValueRef position_wrapper = AXValueCreate(kAXValueCGPointType, &position);
    AXUIElementSetAttributeValue(window, kAXPositionAttribute, position_wrapper);
    CFRelease(position_wrapper);
}

CGSize window_get_size(AXUIElementRef window)
{
    AXValueRef size_wrapper = nullptr;
    CGSize result;

    if (AXUIElementCopyAttributeValue(window, kAXSizeAttribute, (CFTypeRef *)&size_wrapper) != kAXErrorSuccess) {
        assert(false && "Unable to get AXValueRef for window size");
    }

    assert(AXValueGetType(size_wrapper) == kAXValueCGSizeType);
    if (!AXValueGetValue(size_wrapper, kAXValueCGSizeType, &result)) {
        assert(false && "Unable to get CGSize for window size");
    }

    CFRelease(size_wrapper);
    return result;
}

void window_set_size(AXUIElementRef window, CGSize size)
{
    AXValueRef size_wrapper = AXValueCreate(kAXValueCGSizeType, &size);
    AXUIElementSetAttributeValue(window, kAXSizeAttribute, size_wrapper);
    CFRelease(size_wrapper);
}

void window_raise(AXUIElementRef window) {
    // With thanks to http://stackoverflow.com/a/6784991/341371
    if (AXUIElementPerformAction(window, kAXRaiseAction) != kAXErrorSuccess) {
        NSLog(@"Unable to raise window");
        return;
    }

    pid_t window_pid = 0;
    if (AXUIElementGetPid(window, &window_pid) != kAXErrorSuccess) {
        NSLog(@"Unable to get PID for window");
        return;
    }

    #pragma clang diagnostic push
    #pragma clang diagnostic ignored "-Wdeprecated-declarations"
    ProcessSerialNumber window_process;
    if (GetProcessForPID(window_pid, &window_process) != 0) {
        NSLog(@"Unable to get process for window PID");
        return;
    }

    if (SetFrontProcessWithOptions(&window_process, kSetFrontProcessFrontWindowOnly) != 0) {
        NSLog(@"Unable to set front process");
        return;
    }
    #pragma clang diagnostic pop
}
