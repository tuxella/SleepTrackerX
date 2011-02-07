//
//  NightDataTest.m
//  SleepTrackerX
//
//  Created by Thomas CORDIVAL on 12/29/10.
//  Copyright 2010 tuxella. All rights reserved.
//

#import "NightDataTest.h"
#import "NightData.h"


@implementation NightDataTest

- (void) testReferenceNightDataURLV1 {
	NSString *expected = @"http://www.sleeptracker.net/import.php?a=14:00&w=20&t=11:09&dt=a=11:09,11:22,11:34&da=42:45&email=sleeptrackertest@lukita.fr&pwd=123456&login=1&code=";
	const char buffer [18]= {12, 29, 4, 20, 11, 9, 14, 0, 3, 11, 9, 9, 11, 22, 42, 11, 34, 34};
	
	NightData * myND = [[NightData alloc] initWithBuffer:(const char *)&buffer];
	STAssertEqualObjects(expected, [myND newURL], @"Error in the url generated, shouldnt be this : ");
	
}

- (void) testloadedStatusOK {
	return;
	const char buffer[50] = {0xC0, 0x05, 0x33, 0x00, //header
							0x4E, 0X04, // unknown
							0x05, // data count
							02, 03, 04, //data1 : h, m, s
							02, 04, 04,
							02, 05, 04,
							02, 06, 04,
							02, 07, 04,
							0xC0};
	NightData *myND = [[NightData alloc] init];
	[myND readAlmostAwake:buffer];
	STAssertTrue(myND.nightDataIsLoaded, @"Fail :%d");
	STAssertFalse(myND.alarmAndBedTimeAreLoaded, @"Fail %c");
}

- (void) testAlarmAndToBed {
	const char buffer[50] = {0xC0, 0x04, 0x0E, 0x00, //header
		14, 0,		// window1 min, sec
		0x00, 0X00, // window2 min, sec
		0x00, 0X00, // window3 min, sec
		6,			//alarm 1 hour
		0x00,		//alarm 2 hour
		0x00,		//alarm 3 hour
		9,			//alarm 1 min
		0x00,		//alarm 2 min
		0x00,		//alarm 3 min
		23,			// to bed Hour
		12,			// to bed min
		0xC0};		// end token
	NightData *myND = [[NightData alloc] init];
	[myND readToBedAndAlarm:buffer];
	STAssertFalse(myND.nightDataIsLoaded, nil);
	STAssertTrue(myND.alarmAndBedTimeAreLoaded, nil);
	
	static NSDateFormatter *df;
	if (nil == df)
	{
		df = [[NSDateFormatter alloc] init];
		[df setDateFormat:@"dd-MM-yyyy HH:mm:ss"];
	}
	NSDate *myYesterday = [[NSDate alloc] initWithTimeIntervalSinceNow:-24 * 3600]; //This test case tests a sleep sequence over a day shift
	NSDate* expectedTBDate = [df dateFromString:[[NSString alloc] initWithFormat:@"%d-%d-%d %d:%d:%d",
								[[myYesterday dateWithCalendarFormat:nil timeZone:nil] dayOfMonth],		//This must be fixed when the date will be retrieved from the watch
								[[myYesterday dateWithCalendarFormat:nil timeZone:nil] monthOfYear],			//This must be fixed when the date will be retrieved from the watch
								[[myYesterday dateWithCalendarFormat:nil timeZone:nil] yearOfCommonEra],	//This must be fixed when the date will be retrieved from the watch
								23, 12, 0]];
	STAssertEqualObjects(myND.TBDate, expectedTBDate, nil);
	
	NSDate *myNow = [[NSDate alloc] initWithTimeIntervalSinceNow:-0];
	NSDate* expectedADate = [df dateFromString:[[NSString alloc] initWithFormat:@"%d-%d-%d %d:%d:%d",
												 [[myNow dateWithCalendarFormat:nil timeZone:nil] dayOfMonth],		//This must be fixed when the date will be retrieved from the watch
												 [[myNow dateWithCalendarFormat:nil timeZone:nil] monthOfYear],			//This must be fixed when the date will be retrieved from the watch
												 [[myNow dateWithCalendarFormat:nil timeZone:nil] yearOfCommonEra],	//This must be fixed when the date will be retrieved from the watch
												 6, 9, 0]];
	STAssertEqualObjects(myND.ADate, expectedADate, nil);
	
}

- (void) testNightDataV2 {
	const char buffer[50] = {0xC0, 0x04, 0x0E, 0x00, //header
		14, 0,		// window1 min, sec
		0x00, 0X00, // window2 min, sec
		0x00, 0X00, // window3 min, sec
		6,			//alarm 1 hour
		0x00,		//alarm 2 hour
		0x00,		//alarm 3 hour
		9,			//alarm 1 min
		0x00,		//alarm 2 min
		0x00,		//alarm 3 min
		23,			// to bed Hour
		12,			// to bed min
		0xC0};		// end token
	NightData *myND = [[NightData alloc] init];
	[myND readToBedAndAlarm:buffer];
	STAssertFalse(myND.nightDataIsLoaded, nil);
	STAssertTrue(myND.alarmAndBedTimeAreLoaded, nil);
	
	const char bufferAA[50] = {0xC0, 0x05, 0x33, 0x00, //header
		0x4E, 0X04, // unknown
		0x05, // data count
		23, 33, 04, //data1 : h, m, s
		02, 04, 04,
		02, 05, 04,
		02, 06, 04,
		06, 07, 04,
		0xC0};
	[myND readAlmostAwake:bufferAA];
	STAssertTrue(myND.nightDataIsLoaded, nil);
	STAssertTrue(myND.alarmAndBedTimeAreLoaded, nil);
	
	NSMutableArray * expectedAADate = [[NSMutableArray alloc] init];
	
	static NSDateFormatter *df;
	if (nil == df)
	{
		df = [[NSDateFormatter alloc] init];
		[df setDateFormat:@"dd-MM-yyyy HH:mm:ss"];
	}
	
	[expectedAADate addObject:myND.TBDate];
	
	NSDate *myYesterday = [[NSDate alloc] initWithTimeIntervalSinceNow:-24 * 3600]; //This test case tests a sleep sequence over a day shift
	NSDate* expectedDate = [df dateFromString:[[NSString alloc] initWithFormat:@"%d-%d-%d %d:%d:%d",
												 [[myYesterday dateWithCalendarFormat:nil timeZone:nil] dayOfMonth],		//This must be fixed when the date will be retrieved from the watch
												 [[myYesterday dateWithCalendarFormat:nil timeZone:nil] monthOfYear],			//This must be fixed when the date will be retrieved from the watch
												 [[myYesterday dateWithCalendarFormat:nil timeZone:nil] yearOfCommonEra],	//This must be fixed when the date will be retrieved from the watch
												 23, 33, 04]];
	[expectedAADate addObject:expectedDate];
	
	NSDate *myNow = [[NSDate alloc] initWithTimeIntervalSinceNow:0];
	expectedDate = [df dateFromString:[[NSString alloc] initWithFormat:@"%d-%d-%d %d:%d:%d",
										[[myNow dateWithCalendarFormat:nil timeZone:nil] dayOfMonth],		//This must be fixed when the date will be retrieved from the watch
										[[myNow dateWithCalendarFormat:nil timeZone:nil] monthOfYear],			//This must be fixed when the date will be retrieved from the watch
										[[myNow dateWithCalendarFormat:nil timeZone:nil] yearOfCommonEra],	//This must be fixed when the date will be retrieved from the watch
										2, 4, 4]];
	[expectedAADate addObject:expectedDate];
	expectedDate = [df dateFromString:[[NSString alloc] initWithFormat:@"%d-%d-%d %d:%d:%d",
									   [[myNow dateWithCalendarFormat:nil timeZone:nil] dayOfMonth],		//This must be fixed when the date will be retrieved from the watch
									   [[myNow dateWithCalendarFormat:nil timeZone:nil] monthOfYear],			//This must be fixed when the date will be retrieved from the watch
									   [[myNow dateWithCalendarFormat:nil timeZone:nil] yearOfCommonEra],	//This must be fixed when the date will be retrieved from the watch
									   2, 5, 4]];
	[expectedAADate addObject:expectedDate];
	expectedDate = [df dateFromString:[[NSString alloc] initWithFormat:@"%d-%d-%d %d:%d:%d",
									   [[myNow dateWithCalendarFormat:nil timeZone:nil] dayOfMonth],		//This must be fixed when the date will be retrieved from the watch
									   [[myNow dateWithCalendarFormat:nil timeZone:nil] monthOfYear],			//This must be fixed when the date will be retrieved from the watch
									   [[myNow dateWithCalendarFormat:nil timeZone:nil] yearOfCommonEra],	//This must be fixed when the date will be retrieved from the watch
									   2, 6, 4]];
	[expectedAADate addObject:expectedDate];
	expectedDate = [df dateFromString:[[NSString alloc] initWithFormat:@"%d-%d-%d %d:%d:%d",
									   [[myNow dateWithCalendarFormat:nil timeZone:nil] dayOfMonth],		//This must be fixed when the date will be retrieved from the watch
									   [[myNow dateWithCalendarFormat:nil timeZone:nil] monthOfYear],			//This must be fixed when the date will be retrieved from the watch
									   [[myNow dateWithCalendarFormat:nil timeZone:nil] yearOfCommonEra],	//This must be fixed when the date will be retrieved from the watch
									   6, 7, 4]];
	[expectedAADate addObject:expectedDate];

	[expectedAADate addObject:myND.ADate];
	NSLog(@"Actual dates : ");
	
	for (int i = 0; i < [myND.aaArray count]; ++i)
	{
		NSLog([df stringFromDate:[myND.aaArray objectAtIndex:i]]);
	}
	
	NSLog(@"Expected dates : ");	
	for (int i = 0; i < [expectedAADate count]; ++i)
	{
		NSLog([df stringFromDate:[expectedAADate objectAtIndex:i]]);
	}
	STAssertEqualObjects(myND.aaArray, expectedAADate, nil);	
}

- (void) testNightIntervalsCount
{
	const char buffer[50] = {0xC0, 0x04, 0x0E, 0x00, //header
	14, 0,		// window1 min, sec
	0x00, 0X00, // window2 min, sec
	0x00, 0X00, // window3 min, sec
	6,			// alarm 1 hour
	0x00,		// alarm 2 hour
	0x00,		// alarm 3 hour
	9,			// alarm 1 min
	0x00,		// alarm 2 min
	0x00,		// alarm 3 min
	23,			// to bed Hour
	12,			// to bed min
	0xC0};		// end token
	NightData *myND = [[NightData alloc] init];
	[myND readToBedAndAlarm:buffer];
	STAssertFalse(myND.nightDataIsLoaded, nil);
	STAssertTrue(myND.alarmAndBedTimeAreLoaded, nil);
	
	const char bufferAA[50] = {0xC0, 0x05, 0x33, 0x00, //header
		0x4E, 0X04, // unknown
		0x05, // data count
		23, 33, 04, //data1 : h, m, s
		02, 04, 04,
		02, 05, 04,
		02, 06, 04,
		06, 07, 04,
		0xC0};
	[myND readAlmostAwake:bufferAA];
	STAssertTrue(myND.nightDataIsLoaded, nil);
	STAssertTrue(myND.alarmAndBedTimeAreLoaded, nil);
	STAssertEqualObjects([myND sleepIntervalCount], 4, nil);
}

- (void) testNightDataV2DataA {
	const char buffer[50] = {0xC0, 0x04, 0x0E, 0x00, //header
		14, 0,		// window1 min, sec
		0x00, 0X00, // window2 min, sec
		0x00, 0X00, // window3 min, sec
		6,			//alarm 1 hour
		0x00,		//alarm 2 hour
		0x00,		//alarm 3 hour
		9,			//alarm 1 min
		0x00,		//alarm 2 min
		0x00,		//alarm 3 min
		23,			// to bed Hour
		12,			// to bed min
		0xC0};		// end token
	NightData *myND = [[NightData alloc] init];
	[myND readToBedAndAlarm:buffer];
	STAssertFalse(myND.nightDataIsLoaded, nil);
	STAssertTrue(myND.alarmAndBedTimeAreLoaded, nil);
	
	const char bufferAA[50] = {0xC0, 0x05, 0x33, 0x00, //header
		0x4E, 0X04, // unknown
		0x05, // data count
		23, 33, 04, //data1 : h, m, s
		02, 04, 04,
		02, 05, 04,
		02, 06, 04,
		06, 07, 04,
		0xC0};
	[myND readAlmostAwake:bufferAA];
	STAssertTrue(myND.nightDataIsLoaded, nil);
	STAssertTrue(myND.alarmAndBedTimeAreLoaded, nil);
	
	NSTimeInterval nightLength = 26 * 60 + 54 + 6 * 3600 + 7 * 60 + 4;
	NSTimeInterval expectedDataA = nightLength / 4;
	[myND coalesceAAarray];
	STAssertEquals(myND.dataA, expectedDataA, nil);	
}

@end
