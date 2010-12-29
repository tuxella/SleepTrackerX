//
//  NightData.m
//  SleepTrackerX
//
//  2010 tuxella. GPL 3+
//

#import "NightData.h"

#include <termios.h>
#include <pwd.h>
#include <sys/stat.h>
#include <errno.h>
#include <unistd.h>


@implementation NightData



- (BOOL) ThreeHoursAreOrdered:(int)h1 m1:(int) m1 h2:(int) h2 m2:(int) m2 h3:(int) h3 m3:(int) m3
{
	if ((h1 > h2) || (h2 > h3))
	{
		return(NO);
	}
	if (h1 == h2)
	{
		if (m1 > m2)
		{
			return(NO);
		}
	}
	if (h2 == h3)
	{
		if (m2 > m3)
		{
			return(NO);
		}
	}
	
	return(YES);
}

- (BOOL) isAGreaterOrEqualThanB :(NSDateComponents *) A B:(NSDateComponents*) B
{
	NSCalendar *gregorian = [[NSCalendar alloc]
							 initWithCalendarIdentifier:NSGregorianCalendar];
	
	NSDate *dateA = [gregorian dateFromComponents:A];
	NSDate *dateB = [gregorian dateFromComponents:B];
	
	BOOL ret = (NSOrderedDescending == [dateA compare:dateB]);
	return (ret);
	
}

- (NSString *) stringFromNSDateComponents:(NSDateComponents *) D
{
	NSCalendar *gregorian = [[NSCalendar alloc]
							 initWithCalendarIdentifier:NSGregorianCalendar];
	
	NSDate *date = [gregorian dateFromComponents:D];
	
	static NSDateFormatter *df;
	if (nil == df)
	{
		df = [[NSDateFormatter alloc] init];
		[df setDateFormat:@"dd-MM-yyyy HH:mm:ss"];			
	}
	return ([df stringFromDate:date]);
}

typedef enum nightCase 
{
    NoneSameDay = 0,
    NoneDayAfter = 1,
	DuringSleeping = 2,
	SinceAlarm = 3
} midnightCrossing;

- (int) MidnightCrossingCase
{
	NSDate *myNow = [[NSDate alloc] initWithTimeIntervalSinceNow:0];
	
	NSCalendar *calendar = [NSCalendar currentCalendar];
	NSDateComponents *tmpDateComponents = [calendar components:( NSHourCalendarUnit | NSMinuteCalendarUnit | NSSecondCalendarUnit ) fromDate:myNow];
	
	BOOL haveCrossedMidnight = NO;	
	int i;
	int pos = 0;
	
	NSDateComponents *lastDateComponents = [calendar components:( NSHourCalendarUnit | NSMinuteCalendarUnit | NSSecondCalendarUnit ) fromDate:TBDate];
	for (i = 0; i <= [aaArray count] + 1; ++i)
	{
		pos ++;
		if (0 == i)
		{
			tmpDateComponents = [calendar components:( NSHourCalendarUnit | NSMinuteCalendarUnit | NSSecondCalendarUnit ) fromDate:TBDate];
		}
		else
		{
			if ([aaArray count] == i)
			{
				tmpDateComponents = [calendar components:( NSHourCalendarUnit | NSMinuteCalendarUnit | NSSecondCalendarUnit ) fromDate:ADate];
				//ret = 
			}
			else
			{
				tmpDateComponents = [calendar components:( NSHourCalendarUnit | NSMinuteCalendarUnit | NSSecondCalendarUnit ) fromDate:[aaArray objectAtIndex:i - 1]];
			}
		}
		NSLog(@"tmpDate : %@; lastDate : %@", [self stringFromNSDateComponents:tmpDateComponents], [self stringFromNSDateComponents:lastDateComponents]);
		if ( [self isAGreaterOrEqualThanB:lastDateComponents B:tmpDateComponents])
		{
			haveCrossedMidnight = YES;
			break;
		}
		lastDateComponents = tmpDateComponents;
	}
	
	if (haveCrossedMidnight)
	{
		//If we are still the same day as the watch publishes
	}
	
	pos = SinceAlarm;
	if (0 == i)
	{
		// WTF ?
	}
	if (1 == i)
	{
//		pos = 
	}
	return 0;
}


- (id)initWithBuffer:(const char *)buffer
{
	if (self = [super init])
	{
		if (nil == buffer)
			[ [ NSAlert alertWithMessageText:[ NSString stringWithFormat:@"The watch didn't send any data" ] defaultButton:@"OK" alternateButton:nil otherButton:nil 
				   informativeTextWithFormat:@"The watch didn't send any correct data. Maybe there isn't any data in the watch" ] runModal ] ;
		int i;
		int d, m, w, tbh, tbmin, ah, amin, s;
		
		m = buffer[0];
		d = buffer[1];
		NSLog(@"Day : %d, month : %d", m, d);
		w = buffer [3];
		window = [NSNumber numberWithInt:w];
		tbh = buffer [4];
		tbmin = buffer [5];
		ah = buffer [6];
		amin = buffer [7];
		s = buffer[8];
		
		NSDate *myNow = [[NSDate alloc] initWithTimeIntervalSinceNow:0];
		
//		NSDateFormatter *df = [[[NSDateFormatter alloc] init] autorelease]; // format dd-MM-yyyy
		static NSDateFormatter *df;
		if (nil == df)
		{
			df = [[NSDateFormatter alloc] init];
			[df setDateFormat:@"dd-MM-yyyy HH:mm:ss"];			
		}
		static NSNumberFormatter *nf;
		if (nf == nil) {
			nf = [[NSNumberFormatter alloc] init];
			[nf setNumberStyle:NSNumberFormatterDecimalStyle];
			[nf setMaximumFractionDigits:3];
			[nf setFormatWidth:2];
			[nf setPaddingCharacter:@"0"];
		}
		
		NSString *stringSTDate = [[[NSString alloc] initWithFormat:@"%@-%@-%d %@:%@:%@", [nf stringFromNumber:[NSNumber numberWithInt:d]],
																						[nf stringFromNumber:[NSNumber numberWithInt:m]],
																						[[myNow dateWithCalendarFormat:nil timeZone:nil] yearOfCommonEra],
																						[nf stringFromNumber:[NSNumber numberWithInt:tbh]],
																						[nf stringFromNumber:[NSNumber numberWithInt:tbmin]],
																						[nf stringFromNumber:[NSNumber numberWithInt:0]]]
								autorelease];
		
		
		TBDate =  [df dateFromString:stringSTDate];
		stringSTDate = [[[NSString alloc] initWithFormat:@"%@-%@-%d %@:%@:%@", [nf stringFromNumber:[NSNumber numberWithInt:d]],
						 [nf stringFromNumber:[NSNumber numberWithInt:m]],
						 [[myNow dateWithCalendarFormat:nil timeZone:nil] yearOfCommonEra],
						 [nf stringFromNumber:[NSNumber numberWithInt:ah]],
						 [nf stringFromNumber:[NSNumber numberWithInt:amin]],
						 [nf stringFromNumber:[NSNumber numberWithInt:0]]]
						autorelease];
		
		ADate = [df dateFromString:stringSTDate];

		stringSTDate = [[[NSString alloc] initWithFormat:@"%@-%@-%d %@:%@:%@", [nf stringFromNumber:[NSNumber numberWithInt:d]],
						 [nf stringFromNumber:[NSNumber numberWithInt:m]],
						 [[myNow dateWithCalendarFormat:nil timeZone:nil] yearOfCommonEra],
						 [nf stringFromNumber:[NSNumber numberWithInt:0]],
						 [nf stringFromNumber:[NSNumber numberWithInt:0]],
						 [nf stringFromNumber:[NSNumber numberWithInt:0]]]
						autorelease];
		
		int aah, aam, aas;
		NSDate *tmpDate;
		aaArray = [[NSMutableArray alloc] init];
		
		for (i = 0; i < s; ++i)
		{
			aah = buffer[9 + 3 * i + 0];
			aam = buffer[9 + 3 * i + 1];
			aas = buffer[9 + 3 * i + 2];
			stringSTDate = [[[NSString alloc] initWithFormat:@"%@-%@-%d %@:%@:%@", [nf stringFromNumber:[NSNumber numberWithInt:d]],
							 [nf stringFromNumber:[NSNumber numberWithInt:m]],
							 [[myNow dateWithCalendarFormat:nil timeZone:nil] yearOfCommonEra],
							 [nf stringFromNumber:[NSNumber numberWithInt:aah]],
							 [nf stringFromNumber:[NSNumber numberWithInt:aam]],
							 [nf stringFromNumber:[NSNumber numberWithInt:aas]]]
							autorelease];
			tmpDate = [df dateFromString:stringSTDate];
			NSLog(@"To Bed Date");
			NSString *tmpS = [df stringFromDate:TBDate];
			NSLog(@"Alarm Date");
			tmpS = [df stringFromDate:ADate];
			
			[aaArray addObject:tmpDate];
		}
		NSInteger numberOfSleepIntervals = [aaArray count] + 1;
		NSDate * lastAwakening = ADate;
		NSDate * actualToBed = TBDate;
		//[ADate timeIntervalSinceDate [aaArray objectAtIndex:([aaArray count] - 1)]];
		float timeIntBtwAlarmAndLastAwakening = [ADate timeIntervalSinceDate:[aaArray objectAtIndex:([aaArray count] - 1)]];
		NSLog(@"WIndow = %@", window);
		NSLog(@"TBDate = %@", TBDate);
		NSLog(@"ADate = %@", ADate);
		if ([window compare:[[NSNumber alloc] initWithFloat:(timeIntBtwAlarmAndLastAwakening / 60)]] == NSOrderedDescending) // last awakening in the window
		{
			lastAwakening = [aaArray objectAtIndex:([aaArray count] - 1)];
			numberOfSleepIntervals = [aaArray count];
		}
		if ([TBDate compare:lastAwakening] == NSOrderedDescending) // TBDate > Last awakening
		{
			NSLog(@"To bed > lastAwakening");
			actualToBed = [TBDate dateByAddingTimeInterval:(float) -60*60*24];
		}
		
		
		NSTimeInterval sleepLength = [lastAwakening timeIntervalSinceDate:actualToBed];
		dataA = sleepLength / numberOfSleepIntervals;
		return(self);
	}
	return(nil);
}


			  
- (NSString *) generateReport
{
	NSMutableString *ret = [[NSMutableString alloc] init];
	[ret appendFormat:@"%@", @"Sleep report : \n"];

	NSString *tmpS;
	static NSDateFormatter *df;
	if (nil == df)
	{
		df = [[NSDateFormatter alloc] init];
		[df setDateFormat:@"dd-MM-yyyy HH:mm:ss"];			
	}
	

	tmpS = [df stringFromDate:TBDate];
	[ret appendFormat:@"%@\n", @"To Bed time"];
	[ret appendFormat:@"%@\n", tmpS];

	NSLog(@"Alarm time");
	tmpS = [df stringFromDate:ADate];
	[ret appendFormat:@"%@\n",@"Alarm time"];
	[ret appendFormat:@"%@\n", tmpS];
	 
	int i;
	NSLog(@"Almost awake dates");
	[ret appendFormat:@"%@\n",@"Almost awake time"];

	for (i = 0; i < [aaArray count]; ++i)
	{
		tmpS = [df stringFromDate:[aaArray objectAtIndex:i]];
		[ret appendFormat:@"%@\n", tmpS];
	}
	NSLog(@"DataA");
	NSString *unixTime = [NSString stringWithFormat:@"%d:%d", (int)(dataA / 60), ((int)dataA % 60)];
	[ret appendFormat:@"%@\n",@"dataA"];
	[ret appendFormat:@"%@\n", unixTime];
	 
	 return(ret);
}

- (NSString *) makeSettingFileName
{
	struct passwd *passwd; 
	passwd = getpwuid ( getuid());
	
	NSString * userName = [[NSString alloc] initWithCString:passwd->pw_name encoding:NSASCIIStringEncoding] ;
	
	
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


- (NSString*) generateURL
{
	NSLog(@"URL Generation");
	static NSDateFormatter *df;
	if (nil == df)
	{
		df = [[NSDateFormatter alloc] init];
		[df setDateFormat:@"HH:mm"];			
	}
	NSMutableString *ret = [[NSMutableString alloc] init];
	[ret appendFormat:@"%@", @"http://www.sleeptracker.net/import.php?"];
	[ret appendFormat:@"a=%@", [df stringFromDate:ADate]];
	[ret appendFormat:@"&w=%@", window];
	[ret appendFormat:@"&t=%@", [df stringFromDate:TBDate]];
	[ret appendFormat:@"&dt="];
	int i;
	[ret appendFormat:@"a="];
	for (i = 0; i < [aaArray count] - 1; ++i)
	{
		[ret appendFormat:@"%@,", [df stringFromDate:[aaArray objectAtIndex:i]]];
	}
	[ret appendFormat:@"%@", [df stringFromDate:[aaArray objectAtIndex:i]]];
	
	
	[ret appendFormat:@"&da=%@", [NSString stringWithFormat:@"%d:%d", (int)dataA/60, (int)dataA%60]];
	
	NSString *ipath = [self makeSettingFileName];
	
	NSString * username;
	NSString * password;

	struct stat buf;
	i = stat ([ipath cStringUsingEncoding:NSASCIIStringEncoding], &buf);
	
	if ( !i ) // File exists
	{
		NSMutableDictionary *plistData = [NSDictionary dictionaryWithContentsOfFile:ipath];
		username = [plistData valueForKey:@"Username"];
		password = [plistData valueForKey:@"Password"];
	}
	if (([username length] <= 0) || ([password length] <= 0))
	{
		[ [ NSAlert alertWithMessageText:[ NSString stringWithFormat:@"Username / Password have not been set" ] defaultButton:@"OK" alternateButton:nil otherButton:nil 
			   informativeTextWithFormat:@"Username or Password have not been set. You must set them in the 'Settings' tab to be able to load your data" ] runModal ] ;
		return @"Error : no username / password";
	}
	[ret appendFormat:@"&email=%@",username];
	[ret appendFormat:@"&pwd=%@&login=1&code=",password];

	return ret;
}
@end
