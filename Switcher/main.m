//
//  main.m
//  Switcher
//
//  Created by Matt Jacobson on 8/16/19.
//  Copyright © 2019 Matt Jacobson. All rights reserved.
//

#import <AppKit/AppKit.h>
#import <Foundation/Foundation.h>
#import <dispatch/dispatch.h>
#import <assert.h>

@interface Switcher : NSObject
@end

@implementation Switcher

static NSMenuItem *_titleItem;
static BOOL _showsApplicationName;

+ (instancetype)allocWithZone:(NSZone *)zone {
    return nil;
}

+ (void)updateTitle {
    NSMenuItem *const titleItem = [self titleItem];
    NSStatusBarButton *const button = [[self statusItem] button];

    [button setImage:[titleItem image]];
    [button setTitle:[self showsApplicationName] ? [titleItem title] : @""];
}

+ (NSMenuItem *)titleItem {
    return _titleItem;
}

+ (void)setTitleItem:(NSMenuItem *)titleItem {
    _titleItem = titleItem;
    [self updateTitle];

    NSMenu *const menu = [[self statusItem] menu];
    [menu removeItem:titleItem];
    [menu insertItem:titleItem atIndex:0];
}

+ (void)pullDownMenuItemSelected:(id)sender {
    assert([sender isKindOfClass:[NSMenuItem self]]);
    NSMenuItem *const menuItem = (NSMenuItem *)sender;

    const id representedObject = [menuItem representedObject];
    assert([representedObject isKindOfClass:[NSRunningApplication self]]);
    NSRunningApplication *const selectedApplication = (NSRunningApplication *)representedObject;

    const NSEventModifierFlags modifierFlags = [NSEvent modifierFlags];

    if (modifierFlags == NSEventModifierFlagCommand) {
        [[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs:@[[selectedApplication bundleURL]]];
    } else {
        [selectedApplication activateWithOptions:(NSApplicationActivateAllWindows | NSApplicationActivateIgnoringOtherApps)];

        if (modifierFlags == NSEventModifierFlagOption) {
            for (NSRunningApplication *application in [[NSWorkspace sharedWorkspace] runningApplications]) {
                if (![application isEqual:selectedApplication]) {
                    [application hide];
                }
            }
        }
    }
}

+ (void)addMenuItemForApplication:(NSRunningApplication *)application {
    NSMenuItem *const menuItem = [[NSMenuItem alloc] init];
    [menuItem setTitle:[application localizedName]];

    NSImage *const icon = [[application icon] copyWithZone:NULL];
    [icon setSize:NSMakeSize(16., 16.)];
    [menuItem setImage:icon];

    [menuItem setTarget:self];
    [menuItem setAction:@selector(pullDownMenuItemSelected:)];
    [menuItem setRepresentedObject:application];

    // Add the new item above the separator.
    NSMenu *const menu = [[self statusItem] menu];
    [menu insertItem:menuItem atIndex:([menu numberOfItems] - 3)];
}

+ (nullable NSMenuItem *)menuItemForApplication:(NSRunningApplication *)application {
    NSMenuItem *applicationMenuItem = nil;
    NSMenu *const menu = [[self statusItem] menu];

    for (NSMenuItem *menuItem in [menu itemArray]) {
        if ([[menuItem representedObject] isEqual:application]) {
            applicationMenuItem = menuItem;
        }
    }

    return applicationMenuItem;
}

+ (void)applicationDidActivate:(NSNotification *)notification {
    const id object = [[notification userInfo] objectForKey:NSWorkspaceApplicationKey];
    assert([object isKindOfClass:[NSRunningApplication self]]);
    NSRunningApplication *const application = (NSRunningApplication *)object;

#if LOG_EVENTS
    NSLog(@"activate: %@", application);
#endif /* LOG_EVENTS */

    NSMenuItem *const menuItem = [self menuItemForApplication:application];

    if (menuItem != nil) {
        [self setTitleItem:menuItem];
    }
}

+ (void)applicationWillLaunch:(NSNotification *)notification {
    const id object = [[notification userInfo] objectForKey:NSWorkspaceApplicationKey];
    assert([object isKindOfClass:[NSRunningApplication self]]);
    NSRunningApplication *const application = (NSRunningApplication *)object;

#if LOG_EVENTS
    NSLog(@"launch: %@", application);
#endif /* LOG_EVENTS */

    if ([self showsApplication:application]) {
        [self addMenuItemForApplication:application];
    }
}

+ (void)applicationDidQuit:(NSNotification *)notification {
    const id object = [[notification userInfo] objectForKey:NSWorkspaceApplicationKey];
    assert([object isKindOfClass:[NSRunningApplication self]]);
    NSRunningApplication *const application = (NSRunningApplication *)object;

#if LOG_EVENTS
    NSLog(@"quit: %@", application);
#endif /* LOG_EVENTS */

    NSMenuItem *const menuItem = [self menuItemForApplication:application];

    if (menuItem != nil) {
        [[[self statusItem] menu] removeItem:menuItem];
    }
}

static NSString *const showsApplicationNameKey = @"showsApplicationName";

+ (BOOL)showsApplicationName {
    static dispatch_once_t once;

    dispatch_once(&once, ^{
        NSUserDefaults *const standardUserDefaults = [NSUserDefaults standardUserDefaults];

        if ([standardUserDefaults objectForKey:showsApplicationNameKey]) {
            _showsApplicationName = [standardUserDefaults boolForKey:showsApplicationNameKey];
        } else {
            _showsApplicationName = YES;
        }
    });

    return _showsApplicationName;
}

+ (void)setShowsApplicationName:(BOOL)showsApplicationName {
    _showsApplicationName = showsApplicationName;

    [[NSUserDefaults standardUserDefaults] setBool:showsApplicationName forKey:showsApplicationNameKey];

    [self updateTitle];
}

+ (NSStatusItem *)statusItem {
    static dispatch_once_t once;
    static NSStatusItem *statusItem;

    dispatch_once(&once, ^{
        statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];

        NSStatusBarButton *const button = [statusItem button];

        NSFontDescriptor *const originalFontDescriptor = [[button font] fontDescriptor];
        NSFontDescriptor *const semiBoldFontDescriptor = [originalFontDescriptor fontDescriptorByAddingAttributes:@{NSFontTraitsAttribute : @{NSFontWeightTrait : @(NSFontWeightSemibold)}}];
        NSFont *const semiBoldFont = [NSFont fontWithDescriptor:semiBoldFontDescriptor size:0.];
        [button setFont:semiBoldFont];

        [button setImagePosition:NSImageLeading];

        NSMenu *const menu = [[NSMenu alloc] init];
        [menu addItem:[NSMenuItem separatorItem]];

        NSMenuItem *const showApplicationNameItem = [[NSMenuItem alloc] init];
        [showApplicationNameItem setTitle:@"Show App Name"];
        [showApplicationNameItem bind:NSValueBinding toObject:self withKeyPath:@"showsApplicationName" options:nil];
        [menu addItem:showApplicationNameItem];

        NSMenuItem *const quitItem = [[NSMenuItem alloc] init];
        [quitItem setTitle:@"Quit Switcher"];
        [quitItem setTarget:[NSApplication sharedApplication]];
        [quitItem setAction:@selector(terminate:)];
        [menu addItem:quitItem];

        [statusItem setMenu:menu];
    });

    return statusItem;
}

+ (BOOL)showsApplication:(NSRunningApplication *)application {
    return ([application activationPolicy] == NSApplicationActivationPolicyRegular);
}

+ (void)run {
    NSApplication *const sharedApplication = [NSApplication sharedApplication];
    NSWorkspace *const sharedWorkspace = [NSWorkspace sharedWorkspace];

    for (NSRunningApplication *application in [sharedWorkspace runningApplications]) {
        if ([self showsApplication:application]) {
            [self addMenuItemForApplication:application];
        }
    }

    [self setTitleItem:[self menuItemForApplication:[sharedWorkspace frontmostApplication]]];

    NSNotificationCenter *const workspaceCenter = [sharedWorkspace notificationCenter];
    [workspaceCenter addObserver:self selector:@selector(applicationDidActivate:) name:NSWorkspaceDidActivateApplicationNotification object:nil];
    [workspaceCenter addObserver:self selector:@selector(applicationWillLaunch:) name:NSWorkspaceWillLaunchApplicationNotification object:nil];
    [workspaceCenter addObserver:self selector:@selector(applicationDidQuit:) name:NSWorkspaceDidTerminateApplicationNotification object:nil];

    [sharedApplication run];
}

@end

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        [Switcher run];
        return 0;
    }
}
