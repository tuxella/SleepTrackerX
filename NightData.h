//
//  NightData.h
//  SleepTrackerX
//
//  2010 tuxella. GPL 3+
//

#if __OBJC__
#import <Cocoa/Cocoa.h>
#endif


@interface NightData : NSObject {
	NSTimeInterval _dataA;
	NSNumber *_window;
	NSDate * _watchDate;
	NSDate *_TBDate;
	NSDate *_ADate;
	NSMutableArray *_aaArray;
	
	BOOL _alarmAndBedTimeAreLoaded;
	BOOL _nightDataIsLoaded;
}


@property BOOL alarmAndBedTimeAreLoaded;
@property BOOL nightDataIsLoaded;

//These properties are only used for the unit tests by now
@property(readonly) NSTimeInterval dataA;
@property(readonly) NSNumber * window;
@property(readonly) NSMutableArray * aaArray;
@property(readonly) NSDate * TBDate;
@property(readonly) NSDate * ADate;


- (id)init;
- (id)initWithBuffer:(const char *)buffer;

- (BOOL)readToBedAndAlarm:(const char *)buffer;
- (BOOL)readAlmostAwake:(const char *)buffer;
- (BOOL)readDate:(const char *) buffer;

- (BOOL) isReady;

- (NSTimeInterval)dataA;

- (NSString *) newReport;
- (NSString *) newURL;



@end
