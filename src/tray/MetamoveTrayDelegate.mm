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

#import <Cocoa/Cocoa.h>
#import "metamove.hpp"
#import "tray/MetamoveTrayDelegate.h"
#import "tray/PreferenceWindowController.h"

static NSImage *statusImageEnabled = [NSImage imageNamed: @"tray_icon_enabled"];
static NSImage *statusImageDisabled = [NSImage imageNamed: @"tray_icon_disabled"];

@implementation MetamoveTrayDelegate

@synthesize menu;
@synthesize menuToggleEnabled;
@synthesize menuEnabledText;
@synthesize window;
@synthesize statusItem;

- (void)
applicationDidFinishLaunching:
    (NSNotification *) notification
{
    metamove_start();
}

- (void)
awakeFromNib
{
    [statusImageEnabled setTemplate: true];
    [statusImageDisabled setTemplate: true];

    self.statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength: NSSquareStatusItemLength];

    self.statusItem.menu = self.menu;
    self.statusItem.image = statusImageEnabled;
    self.statusItem.highlightMode = true;
}

- (IBAction)
onMenuItemConfigureClicked:
    (id) sender
{
    [[PreferenceWindowController shared] showWindow: self];
    [[[PreferenceWindowController shared] window] makeKeyAndOrderFront: self];
    [NSApp activateIgnoringOtherApps:YES];
}

- (IBAction)
onMenuItemToggleEnabledClicked:
    (id) sender
{
    if (metamove_is_enabled()) {
        self.menuEnabledText.title = @"Metamove: Off";
        self.menuToggleEnabled.title = @"Enable";

        if (floor(NSAppKitVersionNumber) <= NSAppKitVersionNumber10_9) {
            // Mavericks or below
            self.statusItem.image = statusImageDisabled;
        } else {
            // Yosemite
            self.statusItem.button.appearsDisabled = true;
        }

        metamove_set_enabled(false);
    } else {
        self.menuEnabledText.title = @"Metamove: On";
        self.menuToggleEnabled.title = @"Disable";

        if (floor(NSAppKitVersionNumber) <= NSAppKitVersionNumber10_9) {
            // Mavericks or below
            self.statusItem.image = statusImageEnabled;
        } else {
            // Yosemite
            self.statusItem.button.appearsDisabled = false;
        }

        metamove_set_enabled(true);
    }
    metamove_reconfigure();
}

- (IBAction)
onMenuItemExitClicked:
    (id) sender
{
    exit(0);
}

@end
