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

#include <CoreFoundation/CoreFoundation.h>
#include <Foundation/Foundation.h>
#include "config.hpp"
#include "window_event_tap.hpp"

void suicide_callback(CFNotificationCenterRef, void *, CFStringRef, const void *, CFDictionaryRef userInfo) {
    NSDictionary *data = (NSDictionary *)userInfo;
    NSLog(@"Received suicide notification from sender '%@' for reason '%@'",
        [data objectForKey: @"sender"],
        [data objectForKey: @"reason"]);
    CFRunLoopStop(CFRunLoopGetMain());
}

void status_callback(CFNotificationCenterRef notification_center, void *, CFStringRef, const void *, CFDictionaryRef userInfo) {
    NSDictionary *data = (NSDictionary *)userInfo;
    NSLog(@"Received status query from sender '%@'", [data objectForKey: @"sender"]);
    CFNotificationCenterPostNotification(
        notification_center,
        NOTIFICATION_ALIVE,
        NOTIFICATION_OBJECT,
        (CFDictionaryRef)@{@"version" : @VERSION_STRING},
        true);
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

    CGEventMask left_mouse_mask =
        CGEventMaskBit(kCGEventLeftMouseDown) |
        CGEventMaskBit(kCGEventLeftMouseDragged) |
        CGEventMaskBit(kCGEventLeftMouseUp);
    CGEventMask right_mouse_mask =
        CGEventMaskBit(kCGEventRightMouseDown) |
        CGEventMaskBit(kCGEventRightMouseDragged) |
        CGEventMaskBit(kCGEventRightMouseUp);

    CGEventMask move_mask, resize_mask;

    switch (get_move_button()) {
        case config_mouse_button::left:
            move_mask = left_mouse_mask;
            break;
        case config_mouse_button::right:
            move_mask = right_mouse_mask;
            break;
        default:
            move_mask = 0;
    }

    switch (get_resize_button()) {
        case config_mouse_button::left:
            resize_mask = left_mouse_mask;
            break;
        case config_mouse_button::right:
            resize_mask = right_mouse_mask;
            break;
        default:
            resize_mask = 0;
    }

    MoveWindowEventTap move_window_event_tap(
        move_mask,
        get_move_modifiers(),
        true);
    ResizeWindowEventTap resize_window_event_tap(
        resize_mask,
        get_resize_modifiers(),
        true);

    NSLog(@"metamove v%s successfully initialized.", VERSION_STRING);
    CFRunLoopRun();
    return 0;
}
