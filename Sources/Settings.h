//
//  Settings.h
//  SleepTrackerX
//
//  Created by Thomas CORDIVAL on 2/14/11.
//  Copyright 2011 tuxella. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface Settings : NSObject {

}
+ (NSString *) makeSettingFileName;
+ (NSString *) copyUsername;
+ (NSString *) copyPassword;
+ (BOOL) setPassword:(NSString *) password;
+ (BOOL) setUsername:(NSString *) username;
+ (void) chownFromPath:(NSString *) filePath;

@end
