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

#import "config.hpp"
#import "launchd_manager.hh"
#import "PreferencePaneView.hh"

@implementation PreferencePaneView

@synthesize startStopButton;

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

- (void)
viewWillMoveToWindow:
    (NSWindow *) newWindow
{
    [self updateStatus];
    [self loadSettings];
    [versionLabel setStringValue: [NSString stringWithFormat: @"metamove v%s", VERSION_STRING]];
}

- (void)
updateStatus {
    if ([launchd_manager isRunning]) {
        [startStopButton setEnabled: false forSegment: 0];
        [startStopButton setEnabled: true forSegment: 1];
        [startStopButton setSelectedSegment: 0];
    } else {
        [startStopButton setEnabled: true forSegment: 0];
        [startStopButton setEnabled: false forSegment: 1];
        [startStopButton setSelectedSegment: 1];
    }
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
startStopButtonClicked:
    (id) sender
{
    if ([startStopButton isEnabledForSegment: 0]) {
        // Start button was clicked
        [launchd_manager start];
    } else {
        [launchd_manager stop];
    }

    [self updateStatus];
}

- (IBAction)
configButtonClicked:
    (id) sender
{
    [self saveSettings];

    // Restart the daemon
    static CFNotificationCenterRef distributed_center = CFNotificationCenterGetDistributedCenter();
    CFNotificationCenterPostNotification(
        distributed_center,
        NOTIFICATION_SUICIDE,
        NOTIFICATION_OBJECT,
        (CFDictionaryRef) @{
            @"sender" : @"metamove-prefpane",
            @"reason" : @"Configuration changed"
        },
        true);
}

- (IBAction)
urlClicked:
    (id) sender
{
    [[NSWorkspace sharedWorkspace] openURL: [NSURL URLWithString: @"https://github.com/jmgao/metamove"]];
}

@end
