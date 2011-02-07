//
//  RetrievedBuffer.h
//  SleepTrackerX
//
//  Created by Thomas CORDIVAL on 1/2/11.
//  Copyright 2011 tuxella. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface RetrievedBuffer : NSObject {
	NSData * _buffer;
	NSInteger _length;
	NSInteger _bufferKind;
}


- (void) setBuffer:(unsigned char *) buffer length:(NSInteger) length;
- (void) setLength:(NSInteger) length;
- (void) setBufferKind:(NSInteger) kind;

- (NSData *) buffer;
- (NSInteger) length;
- (NSInteger) kind;

@end
//cst stands for Connection STate
#define rbuUndef						0
#define rbuDataV1						1
#define rbuDataV2						2
#define rbuToBedAndAlarm				3
#define rbuDate							4
