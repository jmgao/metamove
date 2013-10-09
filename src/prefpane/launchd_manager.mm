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

#import <sys/stat.h>
#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import "launchd_manager.hh"

#include <launch.h>

#pragma mark - Pillaged from http://brockerhoff.net/blog/2009/02/02/cocoa-musings-pt-3
static id GetFromLaunchData(launch_data_t obj);

static void Launch_data_iterate(launch_data_t obj, const char *key, void* dict) {
    if (obj) {
        id value = GetFromLaunchData(obj);
        if(value) {
            [(NSMutableDictionary *)dict setObject: value forKey:[NSString stringWithUTF8String:key]];
        }
    }
}

static NSDictionary * GetFromLaunchDictionary(launch_data_t dict) {
    NSMutableDictionary *result = NULL;
    if (launch_data_get_type(dict) == LAUNCH_DATA_DICTIONARY) {
        result = [NSMutableDictionary dictionary];
        launch_data_dict_iterate(dict, Launch_data_iterate, result);
    }
    return result;
}

static NSArray * GetFromLaunchArray(launch_data_t arr) {
    NSMutableArray *result = NULL;
    if (launch_data_get_type(arr) == LAUNCH_DATA_ARRAY) {
        size_t count = launch_data_array_get_count(arr);
        result = [NSMutableArray arrayWithCapacity: count];
        for (size_t i = 0; i < count; i++) {
            id obj = GetFromLaunchData(launch_data_array_get_index(arr, i));
            if (obj) {
                [result addObject: obj];
            }
        }
    }
    return result;
}

static id GetFromLaunchData(launch_data_t obj) {
    switch (launch_data_get_type(obj)) {
        case LAUNCH_DATA_STRING:
            return [NSString stringWithUTF8String: launch_data_get_string(obj)];
        case LAUNCH_DATA_INTEGER:
            return [NSNumber numberWithLongLong: launch_data_get_integer(obj)];
        case LAUNCH_DATA_REAL:
            return [NSNumber numberWithDouble: launch_data_get_real(obj)];
        case LAUNCH_DATA_BOOL:
            return [NSNumber numberWithBool: launch_data_get_bool(obj) ? true : false];
        case LAUNCH_DATA_ARRAY:
            return GetFromLaunchArray(obj);
        case LAUNCH_DATA_DICTIONARY:
            return GetFromLaunchDictionary(obj);
        case LAUNCH_DATA_FD:
            return [NSNumber numberWithInt: launch_data_get_fd(obj)];
        case LAUNCH_DATA_MACHPORT:
            return [NSNumber numberWithInt: launch_data_get_machport(obj)];
        default:
            break;
    }

    return nullptr;
}

static NSDictionary * GetFromJobLabel(NSString *job) {
    NSDictionary *result = nullptr;
    launch_data_t msg = launch_data_alloc(LAUNCH_DATA_DICTIONARY);
    if (msg && launch_data_dict_insert(msg, launch_data_new_string([job fileSystemRepresentation]), LAUNCH_KEY_GETJOB)) {
        launch_data_t response = launch_msg(msg);
        launch_data_free(msg);
        if (response) {
            if (launch_data_get_type(response) == LAUNCH_DATA_DICTIONARY) {
                result = GetFromLaunchDictionary(response);
            }
            launch_data_free(response);
        }
    }
    return result;
}
#pragma mark -

@implementation launchd_manager

+ (NSString *)
bundleBinaryPath {
    return
        [[NSBundle bundleForClass: [self class]]
            pathForResource: @"metamove"
            ofType: @""];
}

+ (NSString *)
installedLaunchdPlistPath {
    return [@"~/Library/LaunchAgents/us.insolit.metamove.plist" stringByExpandingTildeInPath];
}

+ (NSString *)
bundleLaunchdPlistPath {
    return
        [[NSBundle bundleForClass: [self class]]
            pathForResource: @"us.insolit.metamove"
            ofType: @"plist"];
}

+ (bool)
isInstalled {    NSDictionary *installed_plist = [NSDictionary dictionaryWithContentsOfFile: [self installedLaunchdPlistPath]];
    return installed_plist && [[installed_plist objectForKey: @"Program"] isEqual: [self bundleBinaryPath]];
}

+ (void)
install {
    NSFileManager *file_manager = [NSFileManager defaultManager];
    [file_manager
        removeItemAtPath: [self installedLaunchdPlistPath]
        error: nullptr];

    NSMutableDictionary *base_plist = [NSMutableDictionary dictionaryWithContentsOfFile: [self bundleLaunchdPlistPath]];
    [base_plist setObject: [self bundleBinaryPath] forKey: @"Program"];
    [base_plist writeToFile: [self installedLaunchdPlistPath] atomically: true];
}

+ (void)
uninstall {
    [self stop];

    NSFileManager *file_manager = [NSFileManager defaultManager];
    [file_manager
        removeItemAtPath: [self installedLaunchdPlistPath]
        error: nullptr];
}

+ (bool)
isRunning {
    NSDictionary *job_dictionary = GetFromJobLabel(@"us.insolit.metamove");
    return job_dictionary && [job_dictionary objectForKey: @"PID"];
}

+ (void)
start {
    if (![self isInstalled]) {
        [self install];
    }

    system(
        [[NSString stringWithFormat: @"/bin/launchctl load -w \"%@\"", [self installedLaunchdPlistPath]]
            UTF8String]);
}

+ (void)
stop {
    if (![self isInstalled]) {
        return;
    }

    system(
        [[NSString stringWithFormat: @"/bin/launchctl unload -w \"%@\"", [self installedLaunchdPlistPath]]
            UTF8String]);
}

@end
