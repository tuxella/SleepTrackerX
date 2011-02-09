//
//  NightDataTest.h
//  SleepTrackerX
//
//  Created by Thomas CORDIVAL on 12/29/10.
//  Copyright 2010 tuxella. All rights reserved.
//

#import <SenTestingKit/SenTestingKit.h>


@interface NightDataTest : SenTestCase {
	
}

- (void) testReferenceNightDataURLV1;
- (void) testloadedStatusOK;
//- (void) testReferenceNightDataURLV2;
- (void) testNightIntervalsCount;
- (void) testNightDataV2;
- (void) testNightDataV2DataA;
- (void) testAlarmAndToBed;
- (void) testCoalesceAAarray;
@end
