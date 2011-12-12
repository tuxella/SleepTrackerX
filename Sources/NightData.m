//
//  NightData.m
//  SleepTrackerX
//
//  2010 tuxella. GPL 3+
//

#import "NightData.h"
#import "Settings.h"

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
	[gregorian dealloc];
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
	[gregorian dealloc];
	return ([df stringFromDate:date]);
}

- (id)init
{
	self = [super init];
	self.alarmAndBedTimeAreLoaded = NO;
	self.nightDataIsLoaded = NO;
	[self readDate:nil]; //FIXME when the date will be retrieved from the watch
	
	return(self);
}


- (BOOL)readToBedAndAlarm:(const char *)buffer
{
	static NSDateFormatter *df;
	if (nil == df)
	{
		df = [[NSDateFormatter alloc] init];
	}
	//ToBedTime
	
	NSInteger toBedHour = buffer [16];
	NSInteger toBedMinute = buffer [17];

	[df setDateFormat:@"dd"];
	NSString * watchDay = [df stringFromDate:_watchDate];
	
	[df setDateFormat:@"MM"];
	NSString * watchMonth = [df stringFromDate:_watchDate];
	
	[df setDateFormat:@"yyyy"];
	NSString * watchYear = [df stringFromDate:_watchDate];

	NSString *TBDateString = [[NSString alloc] initWithFormat:@"%@-%@-%@ %d:%d:%d", watchDay, watchMonth, watchYear,
							   toBedHour, toBedMinute, 0];
	[df setDateFormat:@"dd-MM-yyyy HH:mm:ss"];

	[self setTBDate:[df dateFromString:TBDateString]];
    if (![self TBDate]) {
        NSLog(@"To bed time wasn't right : %@", TBDateString);
        return (NO);
    } else {
        NSLog(@"To bed time read %@", TBDateString);
    }
    [TBDateString release];    
	//Window
	[self setWindow:[NSNumber numberWithInt:buffer[4]]];
	
	//Alarm
	
	NSInteger alarmHour = buffer [10];
	NSInteger alarmMinute = buffer [13];
	
	NSString *AlarmDateString = [[NSString alloc] initWithFormat:@"%@-%@-%@ %d:%d:%d", watchDay, watchMonth, watchYear,
							  alarmHour, alarmMinute, 0];
	[df setDateFormat:@"dd-MM-yyyy HH:mm:ss"];			
	[self setADate:[df dateFromString:AlarmDateString]];
	
	
	//Correct the Bed Time if greater than Alarm
	if ([[self TBDate] isGreaterThan:[self ADate]]) {
		[self setTBDate:[[self TBDate] dateByAddingTimeInterval:(-60 * 60 * 24)]]; //To Bed must be the day before the alarm
	}
	
	self.alarmAndBedTimeAreLoaded = YES;
	return (YES);
}

- (BOOL)readAlmostAwake:(const char *)buffer
{
	NSLog(@"raa 1");
	static NSDateFormatter *df;
	df = [[NSDateFormatter alloc] init];
	NSLog(@"raa 2");
	//The day you get to bed might be the day you first awake
	[df setDateFormat:@"dd"];
    NSLog(@"Just before reading the _TBDate");
    if (!_TBDate) {
        NSLog(@"_TBDate is null ...");
    } else {
        NSLog(@"_TBDate is NOT null ...");

    }
    
	NSString * currentDay = [df stringFromDate:[self TBDate]];
	
	[df setDateFormat:@"MM"];
	NSString * currentMonth = [df stringFromDate:_TBDate];
	
	[df setDateFormat:@"yyyy"];
	NSString * currentYear = [df stringFromDate:_TBDate];
	
	NSInteger almostAwokenCount = buffer[6];
	NSLog([[NSString alloc] initWithFormat:@"Ready to read %d almost awoken moments", almostAwokenCount]);
	
	[df setDateFormat:@"dd-MM-yyyy HH:mm:ss"];
	NSLog(@"raa 3");
	
	if (nil == _aaArray) {
		_aaArray = [[NSMutableArray alloc] initWithCapacity:0];
	}

	[_aaArray addObject:_TBDate];
	NSDate * previousAaTime = _TBDate;
    
	NSTimeInterval dayShift = 0;
	
	for(int i = 0; i < almostAwokenCount; ++i)
	{
		NSLog(@"raa 3.1");
		NSInteger aaHour = buffer[7 + 3 * i + 0];
		NSInteger aaMinute = buffer[7 + 3 * i + 1];
		NSInteger aaSecond = buffer[7 + 3 * i + 2];
		
		NSDate * almostAwokenTime;
		NSString *aaString = [[NSString alloc] initWithFormat:@"%@-%@-%@ %d:%d:%d", currentDay, currentMonth, currentYear,
								  aaHour, aaMinute, aaSecond];
		almostAwokenTime = [df dateFromString:aaString];
        if (!almostAwokenTime) {
            NSLog(@"Almost awoken time wasn't right : %@", aaString);
            return (NO);
        }
		if ([previousAaTime isGreaterThan:almostAwokenTime])
		{
			dayShift = 3600 * 24;
		}
		almostAwokenTime = [almostAwokenTime dateByAddingTimeInterval:dayShift];
		[_aaArray addObject:almostAwokenTime];
		previousAaTime = [self TBDate];
	}
	NSLog(@"raa 4");

    [[self aaArray] addObject:[self ADate]];

    [self coalesceAAarray];
	self.nightDataIsLoaded = YES;
	
	NSLog(@"raa 5");
	
	return (YES);
}

/*
 * Remove the alarm from the aa if the last awoken date is in the window
 */
- (void) coalesceAAarray
{
	NSTimeInterval windowTimeInterval;
	windowTimeInterval = [_window intValue] * 60; // FIXME : when window will be a NSInteger
	if ([_ADate timeIntervalSinceDate:[_aaArray objectAtIndex:[_aaArray count] - 2]] < windowTimeInterval)
	{
		NSLog(@"Removing last date (alarm date) because it is in the window: %@", _ADate);
		_ADate = [_aaArray objectAtIndex:[_aaArray count] - 2];
		[_aaArray removeLastObject];
	}
	NSLog(@"AAARay : %@", _aaArray);
}

- (BOOL) readDate:(const char *) buffer
{
	//FIXME : should use the actual date from the watch, but by now we can't retrieve it...
	_watchDate = [[NSDate alloc] initWithTimeIntervalSinceNow:0];
	return(YES);
}

- (NSInteger) sleepIntervalCount
{
	//[self coalesceAAarray];
	if (1 >= [_aaArray count]) {
		return (0);
	}
	else
	{
		return ([_aaArray count] - 1);
	}
}

- (NSTimeInterval)dataARaw
{
	NSTimeInterval nightLength = 0;
//		[self coalesceAAarray];
//		NSLog(@"night length before: %@", nightLength);
	NSLog(@"Adate : %@, TBDate: %@", [self ADate], [self TBDate]);
	nightLength = [_ADate timeIntervalSinceDate:[self TBDate]];

	NSLog(@"night length : %f", nightLength);
	return (nightLength / [self sleepIntervalCount]);
}

- (NSString *) dataAStr {
    NSLog(@"Processing dataA");
    int da = [self dataARaw];
    int h = (int)(da / 60);
    int m = (int)(da % 60);
    
    return ([[NSString alloc] initWithFormat:@"%d:%d", h, m]);           
}

- (id)initWithBuffer:(const char *)buffer
{
	if (self = [super init])
	{
		if ((nil == buffer) || (!buffer))
		{
			[ [ NSAlert alertWithMessageText:[ NSString stringWithFormat:@"The watch didn't send any data" ] defaultButton:@"OK" alternateButton:nil otherButton:nil 
				   informativeTextWithFormat:@"The watch didn't send any correct data. Maybe there isn't any data in the watch" ] runModal ] ;
			return (nil);
		}
		int i;
		int d, m, w, tbh, tbmin, ah, amin, s;
		
		m = buffer[0];
		d = buffer[1];
		NSLog(@"Day : %d, month : %d", m, d);
		w = buffer [3];
		_window = [NSNumber numberWithInt:w];
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
		
		
		[self setTBDate:[df dateFromString:stringSTDate]];
		stringSTDate = [[[NSString alloc] initWithFormat:@"%@-%@-%d %@:%@:%@", [nf stringFromNumber:[NSNumber numberWithInt:d]],
						 [nf stringFromNumber:[NSNumber numberWithInt:m]],
						 [[myNow dateWithCalendarFormat:nil timeZone:nil] yearOfCommonEra],
						 [nf stringFromNumber:[NSNumber numberWithInt:ah]],
						 [nf stringFromNumber:[NSNumber numberWithInt:amin]],
						 [nf stringFromNumber:[NSNumber numberWithInt:0]]]
						autorelease];
		
		_ADate = [df dateFromString:stringSTDate];

		int aah, aam, aas;
		NSDate *tmpDate;
		_aaArray = [[NSMutableArray alloc] init];
		
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
			[_aaArray addObject:tmpDate];
		}
		NSInteger numberOfSleepIntervals = [[self aaArray] count] + 1;
		NSDate * lastAwakening = [self ADate];
		NSDate * actualToBed = [self TBDate];
		//[ADate timeIntervalSinceDate [aaArray objectAtIndex:([aaArray count] - 1)]];
		NSTimeInterval timeIntBtwAlarmAndLastAwakening = [_ADate timeIntervalSinceDate:[_aaArray objectAtIndex:([_aaArray count] - 1)]];
		NSLog(@"WIndow = %@", [self window]);
		NSLog(@"TBDate = %@", [self TBDate]);
		NSLog(@"ADate = %@", [self ADate]);
		if ([[self window] compare:[[NSNumber alloc] initWithFloat:(timeIntBtwAlarmAndLastAwakening / 60)]] == NSOrderedDescending) // last awakening in the window
		{
			lastAwakening = [_aaArray objectAtIndex:([_aaArray count] - 1)];
			numberOfSleepIntervals = [_aaArray count];
		}
		if ([[self TBDate] compare:lastAwakening] == NSOrderedDescending) // TBDate > Last awakening
		{
			NSLog(@"To bed > lastAwakening");
			actualToBed = [[self TBDate] dateByAddingTimeInterval:(float) -60*60*24];
		}
		
		
		NSTimeInterval sleepLength = [lastAwakening timeIntervalSinceDate:actualToBed];
//		_dataA = sleepLength / numberOfSleepIntervals;
		[myNow dealloc];
		
		self.alarmAndBedTimeAreLoaded = YES;
		self.nightDataIsLoaded = YES;
		
		return(self);
	}
	return(nil);
}


			  
- (NSString *) newReport
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
	

	tmpS = [df stringFromDate:[self TBDate]];
	[ret appendFormat:@"%@\n", @"To Bed time"];
	[ret appendFormat:@"%@\n", tmpS];

	NSLog(@"Alarm time");
	tmpS = [df stringFromDate:[self ADate]];
	[ret appendFormat:@"%@\n",@"Alarm time"];
	[ret appendFormat:@"%@\n", tmpS];
	 
	int i;
	NSLog(@"Almost awake dates");
	[ret appendFormat:@"%@\n",@"Almost awake time including Alarm time:"];

	for (i = 0; i < [[self aaArray] count]; ++i)
	{   
		tmpS = [df stringFromDate:[[self aaArray] objectAtIndex:i]];
		[ret appendFormat:@"%@\n", tmpS];
	}

	NSLog(@"DataA : %@", [self dataAStr]);
	NSString *unixTime = [NSString stringWithFormat:[self dataAStr]];;

	[ret appendFormat:@"%@\n",@"dataA"];
	[ret appendFormat:@"%@\n", unixTime];
	 
	 return(ret);
}



- (NSString*) newURL
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
	[ret appendFormat:@"a=%@", [df stringFromDate:_ADate]];
	[ret appendFormat:@"&w=%@", _window];
	[ret appendFormat:@"&t=%@", [df stringFromDate:_TBDate]];
	[ret appendFormat:@"&dt="];
	int i;

	NSInteger itemsAppened = 0;
	for (i = 0; i < [[self aaArray] count]; ++i)
	{
		NSLog(@"TB : %@, A : %@, aa = %@", _TBDate, _ADate, [[self aaArray] objectAtIndex:i]);
		if (![_TBDate isEqualToDate:[[self aaArray] objectAtIndex:i]] &&
			![_ADate isEqualToDate:[[self aaArray] objectAtIndex:i]])
		{
			if (0 < itemsAppened)
			{
				[ret appendString:@","];
			}
			[ret appendFormat:@"%@", [df stringFromDate:[[self aaArray] objectAtIndex:i]]];
			itemsAppened ++;
		}
	}
//	NSNumberFormatter *formatter = [[[NSNumberFormatter alloc] init] autorelease];
//	[formatter setFormatterBehavior:NSNumberFormatterBehavior10_4];
//	[formatter setFormatWidth:2];
	
//	[formatter setPaddingPosition:NSNumberFormatterPadBeforePrefix];
//	[formatter setPaddingCharacter:@"0"];
	
//	[ret appendFormat:@"&da=%@", [NSString stringWithFormat:[self dataAStr]]];
	 
	NSString * username = [Settings copyUsername];
	NSString * password = [Settings copyPassword];

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

- (BOOL) isReady //FIXME: should be a 
{
	return (self.nightDataIsLoaded && self.alarmAndBedTimeAreLoaded);
}

@synthesize nightDataIsLoaded = _nightDataIsLoaded;
@synthesize alarmAndBedTimeAreLoaded = _alarmAndBedTimeAreLoaded;

@synthesize dataA = _dataA;
@synthesize window = _window;
@synthesize aaArray = _aaArray;
@synthesize TBDate = _TBDate;
@synthesize ADate = _ADate;


@end
