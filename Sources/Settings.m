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

+ (NSString *) copyValue:(NSString *) objectKey
{
	NSString *ipath = [self makeSettingFileName];
	
	NSString * ret;
	
	struct stat buf;
	NSInteger statResult;
	statResult = stat ([ipath cStringUsingEncoding:NSASCIIStringEncoding], &buf);
	
	if (!statResult) // File exists
	{
		NSMutableDictionary *plistData = [NSDictionary dictionaryWithContentsOfFile:ipath];
		ret = [[plistData valueForKey:objectKey] copy];

	}
	else {
		ret = [[NSString alloc] initWithFormat:@"No %@", objectKey];
	}
	
	return(ret);
}

+ (BOOL) setValue:(NSString *) value objectKey:(NSString *) objectKey
{
	NSString *opath = [self makeSettingFileName];
	
	struct stat buf;
	NSInteger statResult;
	statResult = stat ([opath cStringUsingEncoding:NSASCIIStringEncoding], &buf);
	NSMutableDictionary *plistData;
	if (!statResult) // File exists
	{
		plistData = [NSDictionary dictionaryWithContentsOfFile:opath];
	}
	else {
		plistData = [[NSMutableDictionary alloc] init];
	}
	
	if ((nil != value) && ([value length]) && (nil != objectKey) && ([objectKey length]))
	{
		NSLog(@"%@ : %@", objectKey, value);
		[plistData setObject:value forKey:objectKey];
		
	}
	NSLog(@"Saved setting into file : %@", opath);
	[plistData writeToFile:opath atomically: YES];
	[self chownFromPath:opath];
	
	return(YES);
}

+ (NSString *) copyUsername
{
	return([self copyValue:@"Username"]);
}

+ (NSString *) copyPassword
{
	return([self copyValue:@"Password"]);
}

+ (BOOL) setPassword:(NSString *) password;
{
	[self setValue:password objectKey:@"Password"];
	return(YES);
}

+ (BOOL) setUsername:(NSString *) username;
{
	[self setValue:username objectKey:@"Username"];
	return(YES);
}

+ (void) chownFromPath:(NSString *) filePath
{
	struct passwd *passwd;
	passwd = getpwuid ( getuid());
	chown([filePath cStringUsingEncoding:NSASCIIStringEncoding], passwd->pw_uid, passwd->pw_gid);
}


@end
