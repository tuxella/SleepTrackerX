//
//  RetrievedBuffer.m
//  SleepTrackerX
//
//  Created by Thomas CORDIVAL on 1/2/11.
//  Copyright 2011 tuxella. All rights reserved.
//

#import "RetrievedBuffer.h"

#include <stdlib.h>

@implementation RetrievedBuffer

- (void) setBuffer:(unsigned char *) buffer length:(NSInteger) length
{
	_buffer = [[NSData alloc] initWithBytes:buffer length:length];
}

- (void) setLength:(NSInteger) length
{
	_length = length;
}
- (void) setBufferKind:(NSInteger) kind
{
	_bufferKind = kind;
}

- (NSData *) buffer
{
	return (_buffer);
}

- (NSInteger) length
{
	return (_length);
}

- (NSInteger) kind
{
	return (_bufferKind);
}


@end
