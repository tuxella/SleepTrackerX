//
//  ConnectionState.h
//  SleepTrackerX
//  2010 tuxella. GPL 3+

#import <Cocoa/Cocoa.h>


@interface ConnectionState : NSObject {
	NSInteger connectionState;
}

- (void) setState:(NSInteger) s;
- (NSInteger) state;
- (id) init;


@end
//cst stands for Connection STate
#define cstReady						0
#define cstWaitingForDataV1				1
#define cstWaitingForAlarmsAndToBed		2
#define	cstWaitingForDataV2				3
#define	cstTimedOut						4
#define	cstNotReadyYet					5
#define	cstDataRetrieved				6