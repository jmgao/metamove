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
#include "config.hpp"

static CFStringRef application_id = CFSTR("us.insolit.metamove");
static CFStringRef move_button_key = CFSTR("move_button");
static CFStringRef resize_button_key = CFSTR("resize_button");
static CFStringRef move_modifiers_key = CFSTR("move_modifiers");
static CFStringRef resize_modifiers_key = CFSTR("resize_modifiers");
static CFStringRef raise_window_key = CFSTR("resize_modifiers");

config_mouse_button get_button(CFStringRef key) {
    Boolean key_exists = false;
    CFIndex result = CFPreferencesGetAppIntegerValue(key, application_id, &key_exists);

    if (!key_exists) {
        return config_mouse_button::unknown;
    }

    switch (config_mouse_button(result)) {
        case config_mouse_button::disabled:
            return config_mouse_button::disabled;
        case config_mouse_button::left:
            return config_mouse_button::left;
        case config_mouse_button::right:
            return config_mouse_button::right;
        default:
            return config_mouse_button::unknown;
    }

    return config_mouse_button::unknown;
}

void set_button(CFStringRef key, config_mouse_button button) {
    CFNumberRef value = CFNumberCreate(nullptr, kCFNumberCFIndexType, &button);
    CFPreferencesSetAppValue(key, value, application_id);
    CFPreferencesAppSynchronize(application_id);
    CFRelease(value);
}

config_mouse_button get_move_button(void) {
    config_mouse_button result = get_button(move_button_key);
    return result != config_mouse_button::unknown ? result : config_mouse_button::left;
}

config_mouse_button get_resize_button(void) {
    config_mouse_button result = get_button(resize_button_key);
    return result != config_mouse_button::unknown ? result : config_mouse_button::left;
}

void set_move_button(config_mouse_button button) {
    set_button(move_button_key, button);
}

void set_resize_button(config_mouse_button button) {
    set_button(resize_button_key, button);
}

CGEventMask get_move_modifiers(void) {
    Boolean key_exists = false;
    CFIndex result = CFPreferencesGetAppIntegerValue(move_modifiers_key, application_id, &key_exists);

    return key_exists ? result : kCGEventFlagMaskCommand | kCGEventFlagMaskShift;
}

CGEventMask get_resize_modifiers(void) {
    Boolean key_exists = false;
    CFIndex result = CFPreferencesGetAppIntegerValue(resize_modifiers_key, application_id, &key_exists);

    return key_exists ? result : kCGEventFlagMaskAlternate | kCGEventFlagMaskShift;
}

void set_move_modifiers(CGEventMask modifiers) {
    CFNumberRef value = CFNumberCreate(nullptr, kCFNumberCFIndexType, &modifiers);
    CFPreferencesSetAppValue(move_modifiers_key, value, application_id);
    CFPreferencesAppSynchronize(application_id);
    CFRelease(value);
}

void set_resize_modifiers(CGEventMask modifiers) {
    CFNumberRef value = CFNumberCreate(nullptr, kCFNumberCFIndexType, &modifiers);
    CFPreferencesSetAppValue(resize_modifiers_key, value, application_id);
    CFPreferencesAppSynchronize(application_id);
    CFRelease(value);
}
