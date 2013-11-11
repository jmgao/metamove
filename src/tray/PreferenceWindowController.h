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

#import <Cocoa/Cocoa.h>

@interface PreferenceWindowController : NSWindowController

@property (strong) IBOutlet NSMatrix *moveRadioButtons;
@property (strong) IBOutlet NSButton *moveModifierControlButton;
@property (strong) IBOutlet NSButton *moveModifierOptionButton;
@property (strong) IBOutlet NSButton *moveModifierCommandButton;
@property (strong) IBOutlet NSButton *moveModifierShiftButton;

@property (strong) IBOutlet NSMatrix *resizeRadioButtons;
@property (strong) IBOutlet NSButton *resizeModifierControlButton;
@property (strong) IBOutlet NSButton *resizeModifierOptionButton;
@property (strong) IBOutlet NSButton *resizeModifierCommandButton;
@property (strong) IBOutlet NSButton *resizeModifierShiftButton;

@property (strong) IBOutlet NSTextField *versionLabel;
@property (strong) IBOutlet NSTextField *urlLabel;

+ (PreferenceWindowController *)
shared;

- (void)
windowDidLoad;

- (void)
loadSettings;

- (void)
saveSettings;

- (IBAction)
configButtonClicked:
    (id) sender;

- (IBAction)
urlClicked:
    (id) sender;

@end
