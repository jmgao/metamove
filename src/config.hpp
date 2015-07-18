#pragma once

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
#include "config.h"

enum class config_mouse_button {
    unknown = 0,
    disabled,
    left,
    right
};

config_mouse_button get_move_button(void);
config_mouse_button get_resize_button(void);
void set_move_button(config_mouse_button button);
void set_resize_button(config_mouse_button button);

CGEventFlags get_move_modifiers(void);
CGEventFlags get_resize_modifiers(void);
void set_move_modifiers(CGEventFlags modifiers);
void set_resize_modifiers(CGEventFlags modifiers);
