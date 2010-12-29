//
//  NightData.h
//  SleepTrackerX
//
//  2010 tuxella. GPL 3+
//

#import <Cocoa/Cocoa.h>


@interface NightData : NSObject {
	NSTimeInterval dataA;
	NSNumber *window;
	NSDate *TBDate;
	NSDate *ADate;
	NSMutableArray *aaArray;
}

- (id)initWithBuffer:(const char *)buffer;

- (NSString *) generateReport;

- (NSString *) generateURL;



@end
