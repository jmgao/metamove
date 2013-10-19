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
#include "window.hpp"

static AXUIElementRef accessibility_object = AXUIElementCreateSystemWide();

AXUIElementRef window_get_from_point(CGPoint point) {
    AXUIElementRef element = nullptr;
    CFStringRef element_role = nullptr;

    if (AXUIElementCopyElementAtPosition(accessibility_object, point.x, point.y, &element) != kAXErrorSuccess) {
        NSLog(@"Failed to find element at (%f, %f)\n", point.x, point.y);
        goto abort;
    }

    AXUIElementCopyAttributeValue(element, kAXRoleAttribute, (CFTypeRef *)&element_role);
    if (CFStringCompare(kAXWindowRole, element_role, 0) != kCFCompareEqualTo) {
        AXUIElementRef window = nullptr;

        if (AXUIElementCopyAttributeValue(element, kAXWindowAttribute, (CFTypeRef *)&window) != kAXErrorSuccess) {
            NSLog(@"Failed to copy window for element at (%f, %f)\n", point.x, point.y);
            goto abort;
        } else {
            if (element != window) {
                CFRelease(element);
                element = window;
            }
        }
    }

abort:
    if (element_role) CFRelease(element_role);
    return element;
}

AXUIElementRef window_copy_application(AXUIElementRef window) {
    AXUIElementRef current;
    AXUIElementCopyAttributeValue(window, kAXParentAttribute, (CFTypeRef *)&current);

    while (current) {
        CFStringRef role;
        AXUIElementCopyAttributeValue(current, kAXRoleAttribute, (CFTypeRef *)&role);

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

CGPoint window_get_position(AXUIElementRef widnow) {
    AXValueRef position_wrapper = nullptr;
    CGPoint result;

    if (AXUIElementCopyAttributeValue(widnow, kAXPositionAttribute, (CFTypeRef *)&position_wrapper) != kAXErrorSuccess) {
        assert(false && "Unable to get AXValueRef for widnow position");
    }

    assert(AXValueGetType(position_wrapper) == kAXValueCGPointType);
    if (!AXValueGetValue(position_wrapper, kAXValueCGPointType, &result)) {
        assert(false && "Unable to get CGPoint for widnow position");
    }

    CFRelease(position_wrapper);
    return result;
}

void window_set_position(AXUIElementRef widnow, CGPoint position) {
    AXValueRef position_wrapper = AXValueCreate(kAXValueCGPointType, &position);
    AXUIElementSetAttributeValue(widnow, kAXPositionAttribute, position_wrapper);
    CFRelease(position_wrapper);
}

CGSize window_get_size(AXUIElementRef widnow) {
    AXValueRef size_wrapper = nullptr;
    CGSize result;

    if (AXUIElementCopyAttributeValue(widnow, kAXSizeAttribute, (CFTypeRef *)&size_wrapper) != kAXErrorSuccess) {
        assert(false && "Unable to get AXValueRef for widnow size");
    }

    assert(AXValueGetType(size_wrapper) == kAXValueCGSizeType);
    if (!AXValueGetValue(size_wrapper, kAXValueCGSizeType, &result)) {
        assert(false && "Unable to get CGSize for widnow size");
    }

    CFRelease(size_wrapper);
    return result;
}

void window_set_size(AXUIElementRef widnow, CGSize size) {
    AXValueRef size_wrapper = AXValueCreate(kAXValueCGSizeType, &size);
    AXUIElementSetAttributeValue(widnow, kAXSizeAttribute, size_wrapper);
    CFRelease(size_wrapper);
}
