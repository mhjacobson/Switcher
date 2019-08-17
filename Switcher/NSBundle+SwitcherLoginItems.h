//
//  NSBundle+SwitcherLoginItems.h
//  Switcher
//
//  Created by Matt Jacobson on 8/17/19.
//  Copyright © 2019 Matt Jacobson. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSBundle (SwitcherLoginItems)

@property (getter=switcher_isLoginItem, setter=switcher_setLoginItem:) BOOL switcher_loginItem;

@end
