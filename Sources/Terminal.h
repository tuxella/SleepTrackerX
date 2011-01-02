//
//  Terminal.h
//  SleepTrackerX
//
//  2010 tuxella after Serial Tools from Kok Chen
//

#include "NightData.h"
#import "ConnectionState.h"

#import <Cocoa/Cocoa.h>


@interface Terminal : NSTextView {
	int outputfd ;
	int inputfd ;
	NightData * myND;
	ConnectionState * connState;
	NSString *pport;
	NSInteger pbaudrate;
	NSInteger pbits;
	NSInteger pparity;
	NSInteger pstopBits;	
}

- (void)initTerminal ;

- (Boolean)openConnections:(const char*)port baudrate:(int)baud bits:(int)bits parity:(int)parity stopBits:(int)stops ;

- (void)closeConnections ;
- (void)closeInputConnection ;
- (void)closeOutputConnection ;

- (void)transmitBytes:(const char *)bytes length:(NSInteger)len;

- (void)transmitCharacters:(NSString*)string;

int openPort( const char *path, int speed, int bits, int parity, int stops, int openFlags, Boolean input ) ;

- (void) sendCommand:(NSInteger) command;

- (void) startDataRetrieval;


@end

#define cmdGetDataV1			0
#define cmdGetDataV2			1
#define cmdGetToBedAndAlarmV2	2
