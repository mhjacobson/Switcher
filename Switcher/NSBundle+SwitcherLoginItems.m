//
//  NSBundle+SwitcherLoginItems.m
//  Switcher
//
//  Created by Matt Jacobson on 8/17/19.
//  Copyright © 2019 Matt Jacobson. All rights reserved.
//

#import "NSBundle+SwitcherLoginItems.h"
#import <Foundation/Foundation.h>
#import <CoreServices/CoreServices.h>

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

@implementation NSBundle (SwitcherLoginItems)

static LSSharedFileListItemRef findSFLItemWithURL(LSSharedFileListRef sfl, NSURL *url) {
    UInt32 seed;
    const CFArrayRef snapshot = LSSharedFileListCopySnapshot(sfl, &seed);
    const CFIndex count = CFArrayGetCount(snapshot);

    LSSharedFileListItemRef itemWithURL = NULL;

    for (CFIndex i = 0; i < count; i++) {
        const LSSharedFileListItemRef item = (LSSharedFileListItemRef)CFArrayGetValueAtIndex(snapshot, i);

        const CFURLRef itemURL = LSSharedFileListItemCopyResolvedURL(item, (kLSSharedFileListNoUserInteraction | kLSSharedFileListDoNotMountVolumes), NULL);

        if ([(__bridge NSURL *)itemURL isEqual:url]) {
            itemWithURL = (LSSharedFileListItemRef)CFRetain(item);
            CFRelease(itemURL);
            break;
        } else {
            CFRelease(itemURL);
        }
    }

    CFRelease(snapshot);

    return itemWithURL ? (LSSharedFileListItemRef)CFAutorelease(itemWithURL) : NULL;
}

- (BOOL)switcher_isLoginItem {
    LSSharedFileListRef sfl = LSSharedFileListCreate(kCFAllocatorDefault, kLSSharedFileListSessionLoginItems, NULL);

    const BOOL isLoginItem = (findSFLItemWithURL(sfl, [self bundleURL]) != NULL);

    CFRelease(sfl);
    
    return isLoginItem;
}

- (void)switcher_setLoginItem:(BOOL)loginItem {
    NSURL *const url = [self bundleURL];

    const LSSharedFileListRef sfl = LSSharedFileListCreate(kCFAllocatorDefault, kLSSharedFileListSessionLoginItems, NULL);
    const LSSharedFileListItemRef item = findSFLItemWithURL(sfl, url);

    if (loginItem && item == NULL) {
        NSString *const displayName = [[self localizedInfoDictionary] objectForKey:@"CFBundleDisplayName"];
        LSSharedFileListInsertItemURL(sfl, kLSSharedFileListItemLast, (__bridge CFStringRef)displayName, NULL, (__bridge CFURLRef)url, NULL, NULL);
    } else if (!loginItem && item != NULL) {
        LSSharedFileListItemRemove(sfl, item);
    }
}

@end

#pragma clang diagnostic pop
