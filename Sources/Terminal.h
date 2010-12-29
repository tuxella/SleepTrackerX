//
//  Terminal.h
//  SleepTrackerX
//
//  2010 tuxella. GPL 3+
//

#include "NightData.h"
#import <Cocoa/Cocoa.h>


@interface Terminal : NSTextView {
	int outputfd ;
	int inputfd ;
	NightData * myND;
}

- (void)initTerminal ;

- (Boolean)openConnections:(const char*)port baudrate:(int)baud bits:(int)bits parity:(int)parity stopBits:(int)stops ;

- (void)closeConnections ;
- (void)closeInputConnection ;
- (void)closeOutputConnection ;

- (void)transmitCharacters:(NSString*)string;

int openPort( const char *path, int speed, int bits, int parity, int stops, int openFlags, Boolean input ) ;

@end
