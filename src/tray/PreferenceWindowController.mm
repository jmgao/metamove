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

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import "config.hpp"
#import "metamove.hpp"
#import "tray/PreferenceWindowController.h"

static PreferenceWindowController *instance = nullptr;

@implementation PreferenceWindowController

@synthesize moveRadioButtons;
@synthesize moveModifierControlButton;
@synthesize moveModifierOptionButton;
@synthesize moveModifierCommandButton;
@synthesize moveModifierShiftButton;

@synthesize resizeRadioButtons;
@synthesize resizeModifierControlButton;
@synthesize resizeModifierOptionButton;
@synthesize resizeModifierCommandButton;
@synthesize resizeModifierShiftButton;

@synthesize versionLabel;
@synthesize urlLabel;

+ (PreferenceWindowController *)
shared
{
    @synchronized(self) {
        if (!instance) {
            instance = [PreferenceWindowController alloc];
            instance = [instance initWithWindowNibName: @"PreferenceWindow" owner: instance];
        }

        return instance;
    }
}

- (void)
windowDidLoad
{
    [self loadSettings];
    [versionLabel setStringValue: [NSString stringWithFormat: @"metamove v%s", VERSION_STRING]];
}


- (void)
loadSettings
{
    [moveRadioButtons selectCellWithTag: long(get_move_button())];
    [moveModifierControlButton setState: get_move_modifiers() & kCGEventFlagMaskControl];
    [moveModifierOptionButton setState: get_move_modifiers() & kCGEventFlagMaskAlternate];
    [moveModifierCommandButton setState: get_move_modifiers() & kCGEventFlagMaskCommand];
    [moveModifierShiftButton setState: get_move_modifiers() & kCGEventFlagMaskShift];

    [resizeRadioButtons selectCellWithTag: long(get_resize_button())];
    [resizeModifierControlButton setState: get_resize_modifiers() & kCGEventFlagMaskControl];
    [resizeModifierOptionButton setState: get_resize_modifiers() & kCGEventFlagMaskAlternate];
    [resizeModifierCommandButton setState: get_resize_modifiers() & kCGEventFlagMaskCommand];
    [resizeModifierShiftButton setState: get_resize_modifiers() & kCGEventFlagMaskShift];
}

- (void)
saveSettings
{
    CGEventMask modifiers = 0;
    set_move_button(config_mouse_button([moveRadioButtons selectedTag]));
    if ([moveModifierControlButton state]) modifiers |= kCGEventFlagMaskControl;
    if ([moveModifierOptionButton state]) modifiers |= kCGEventFlagMaskAlternate;
    if ([moveModifierCommandButton state]) modifiers |= kCGEventFlagMaskCommand;
    if ([moveModifierShiftButton state]) modifiers |= kCGEventFlagMaskShift;
    set_move_modifiers(modifiers);

    modifiers = 0;
    set_resize_button(config_mouse_button([resizeRadioButtons selectedTag]));
    if ([resizeModifierControlButton state]) modifiers |= kCGEventFlagMaskControl;
    if ([resizeModifierOptionButton state]) modifiers |= kCGEventFlagMaskAlternate;
    if ([resizeModifierCommandButton state]) modifiers |= kCGEventFlagMaskCommand;
    if ([resizeModifierShiftButton state]) modifiers |= kCGEventFlagMaskShift;
    set_resize_modifiers(modifiers);
}

- (IBAction)
configButtonClicked:
    (id) sender
{
    [self saveSettings];
    metamove_reconfigure();
}

- (IBAction)
urlClicked:
    (id) sender
{
    [[NSWorkspace sharedWorkspace] openURL: [NSURL URLWithString: @"https://github.com/jmgao/metamove"]];
}

@end
