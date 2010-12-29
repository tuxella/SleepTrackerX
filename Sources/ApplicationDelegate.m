//
//  ApplicationDelegate.m
//  SleepTrackerX
//
//  2010 tuxella. GPL 3+
//

#import "ApplicationDelegate.h"
#import "serial.h"

@implementation ApplicationDelegate

- (id)init
{
	NSUserDefaults *defaults ;
	NSArray *recent ;
	
	self = [ super init ] ;
	if ( self ) {
		openedFromFile = NO ;
		[ NSApp setDelegate:self ] ;
		guis = [ [ NSMutableArray alloc ] initWithCapacity:4 ] ;
		recentGUIs = [ [ NSMutableArray alloc ] initWithCapacity:4 ] ;
		uniqueCount = 1 ;
		activeGUI = nil ;
		//  create and update recent file array from user defaults if neccessary
		recentFiles = [ [ NSMutableArray alloc ] initWithCapacity:4 ] ;
		defaults = [ [ NSUserDefaultsController sharedUserDefaultsController ] defaults ] ;
		recent = [ defaults objectForKey:kRecentFiles ] ;
		if ( recent ) [ recentFiles addObjectsFromArray:recent ] ;
		[ self startNotification ] ;
	}
	return self ;
}

- (void)awakeFromNib
{
	[ recentMenu setDelegate:self ] ;
	//  enable menus explicitly in menuNeedsUpdate
	[ recentMenu setAutoenablesItems:NO ] ;
	//  start a session if it is not done by application:openFile
	[ NSTimer scheduledTimerWithTimeInterval:0.75 target:self selector:@selector(openSession:) userInfo:self repeats:NO ] ;
}

- (void)openSession:(NSTimer*)timer
{
	if ( openedFromFile ) return ;
	openedFromFile = YES ;
	[ self newSession:self ] ;
}

- (void)guiBecameActive:(GUI*)which
{
	activeGUI = which ;
	[ recentGUIs removeObject:which ] ;
	[ recentGUIs addObject:which ] ;
}

- (void)guiClosing:(GUI*)which
{
	int count ;
	
	[ guis removeObject:which ] ;
	[ recentGUIs removeObject:which ] ;
	//  check recent guis and activate the most recent one (last one in array)
	count = [ recentGUIs count ] ;
	if ( count == 0 ) {
		activeGUI = nil ;
		return ;
	}
	activeGUI = [ recentGUIs objectAtIndex:count-1 ] ;
	[ activeGUI activate ] ;
}

- (IBAction)newSession:(id)sender
{
	GUI *gui ;
	
	gui = [ [ GUI alloc ] initWithUntitled:[ NSString stringWithFormat:@"Untitled %d", uniqueCount++ ] dictionary:nil ] ;
	if ( gui ) [ guis addObject:gui ] ;
}



- (void)startNotification
{
	CFMutableDictionaryRef matchingDict ;
	
	notifyPort = IONotificationPortCreate( kIOMasterPortDefault ) ;
	CFRunLoopAddSource( CFRunLoopGetCurrent(), IONotificationPortGetRunLoopSource( notifyPort ), kCFRunLoopDefaultMode ) ;
	matchingDict = IOServiceMatching( kIOSerialBSDServiceValue ) ;
	CFRetain( matchingDict ) ;
	CFDictionarySetValue( matchingDict, CFSTR(kIOSerialBSDTypeKey), CFSTR( kIOSerialBSDAllTypes ) ) ;
	
//	IOServiceAddMatchingNotification( notifyPort, kIOFirstMatchNotification, matchingDict, deviceAdded, self, &addIterator ) ;
	//deviceAdded( nil, addIterator ) ;	//  set up addIterator

//	IOServiceAddMatchingNotification( notifyPort, kIOTerminatedNotification, matchingDict, deviceRemoved, self, &removeIterator ) ;
	//deviceRemoved( nil, removeIterator ) ;	// set up removeIterator
}

- (void)stopNotification
{
	if ( addIterator ) {
		IOObjectRelease( addIterator ) ;
		addIterator = 0 ; 
	}
	
	if ( removeIterator ) {
		IOObjectRelease( removeIterator ) ;
		removeIterator = 0 ;
	}
	if ( notifyPort ) {
		CFRunLoopRemoveSource( CFRunLoopGetCurrent(), IONotificationPortGetRunLoopSource( notifyPort ), kCFRunLoopDefaultMode ) ;
		IONotificationPortDestroy( notifyPort ) ;
		notifyPort = nil ;
	}
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication*)sender
{
	int i, count ;
		
	count = [ guis count ] ;
	for ( i = 0; i < count; i++ ) {
		if ( [ [ guis objectAtIndex:i ] shouldTerminate ] == NO ) return NSTerminateCancel ;
	}
	[ self stopNotification ] ;
	
	return NSTerminateNow ;
}


@end
