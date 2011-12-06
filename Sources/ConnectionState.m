//
//  ConnectionState.m
//  SleepTrackerX
//
//  Created by Thomas CORDIVAL on 12/29/10.
//  Copyright 2010 tuxella. All rights reserved.
//

#import "ConnectionState.h"


@implementation ConnectionState

- (id) init {
	[self setState:cstNotReadyYet];
	return (self);
}

- (void) setState:(NSInteger) state {
	@synchronized(self) {
		connectionState = state;
		NSLog(@"Connection state changed to: %ld", state);
	}
}

- (NSInteger) state {
	@synchronized(self) {
		return(connectionState);
	}
	return (cstNotReadyYet);
}


@end
