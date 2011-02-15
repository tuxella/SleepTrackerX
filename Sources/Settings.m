//
//  Settings.m
//  SleepTrackerX
//
//  Created by Thomas CORDIVAL on 2/14/11.
//  Copyright 2011 tuxella. All rights reserved.
//

#import "Settings.h"

#include <pwd.h>
#include <sys/stat.h>
#include <errno.h>
#include <unistd.h>


@implementation Settings
+ (NSString *) makeSettingFileName
{
	struct passwd *passwd; 
	passwd = getpwuid ( getuid());
	
	NSString * userName = [[[NSString alloc] initWithCString:passwd->pw_name encoding:NSASCIIStringEncoding] autorelease];
	
	
	NSString *opath = @"/Users/";
	opath = [opath stringByAppendingString:userName];
	opath = [opath stringByAppendingString:@"/.SleepTrackerX/"];
	
	struct stat buf;
	int i = stat ( [opath cStringUsingEncoding:NSASCIIStringEncoding], &buf );
	
	if ( i ) // File exists
	{
		int ret = mkdir([opath cStringUsingEncoding:NSASCIIStringEncoding], S_IRWXU);
		
		if (ret)
		{
			NSLog(@"Error while creating dir : %d", ret);
			return (nil);
		}
	}
	chown([opath cStringUsingEncoding:NSASCIIStringEncoding], passwd->pw_uid, passwd->pw_gid);
	opath = [opath stringByAppendingString:@"Settings.plist"];	
	
	return(opath);
}


+ (NSString *) copyUsername
{
	NSString *ipath = [self makeSettingFileName];
	
	NSString * username;
	
	struct stat buf;
	NSInteger statResult;
	statResult = stat ([ipath cStringUsingEncoding:NSASCIIStringEncoding], &buf);
	
	if (!statResult) // File exists
	{
		NSMutableDictionary *plistData = [NSDictionary dictionaryWithContentsOfFile:ipath];
		username = [[plistData valueForKey:@"Username"] copy];
		//[plistData release];
	}
	else {
		username = [[NSString alloc] initWithFormat:@"No username"];
	}
	
	return(username);
}

+ (NSString *) copyPassword
{
	NSString *ipath = [self makeSettingFileName];
	
	NSString * password;
	
	struct stat buf;
	NSInteger statResult;
	statResult = stat ([ipath cStringUsingEncoding:NSASCIIStringEncoding], &buf);
	
	if (!statResult) // File exists
	{
		NSMutableDictionary *plistData = [NSDictionary dictionaryWithContentsOfFile:ipath];
		password = [[plistData valueForKey:@"Password"] copy];
		//[plistData release];
	}
	else {
		password = [[NSString alloc] initWithFormat:@"No password"];
	}

	return(password);
}

+ (BOOL) setPassword:(NSString *) password;
{
	NSString *opath = [self makeSettingFileName];
	
//	NSMutableDictionary *plistData = [[NSMutableDictionary alloc] init];
	NSMutableDictionary *plistData = [NSDictionary dictionaryWithContentsOfFile:opath];

	
	if ((nil != password) && ([password length]))
	{
		NSLog(@"Pass : %@", password);
		[plistData setObject:password forKey:@"Password"];
	}
	
	[plistData writeToFile:opath atomically: YES];
	[plistData release];
	[self chownFromPath:opath];
	
	return(YES);
}

+ (BOOL) setUsername:(NSString *) username;
{
	NSString *opath = [self makeSettingFileName];
	
//	NSMutableDictionary *plistData = [[NSMutableDictionary alloc] init];
	NSMutableDictionary *plistData = [NSDictionary dictionaryWithContentsOfFile:opath];

	
	if ((nil != username) && ([username length]))
	{
		NSLog(@"username : %@", username);
		[plistData setObject:username forKey:@"Username"];
	}
	
	[plistData writeToFile:opath atomically: YES];
	[plistData release];
	[self chownFromPath:opath];
	
	return(YES);
}

+ (void) chownFromPath:(NSString *) filePath
{
	struct passwd *passwd;
	passwd = getpwuid ( getuid());
	chown([filePath cStringUsingEncoding:NSASCIIStringEncoding], passwd->pw_uid, passwd->pw_gid);
}


@end
