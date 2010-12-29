//
//  GUI.c
//  SleepTrackerX
//
//  2010 tuxella. GPL 3+
//

#import "GUI.h"
#import "ApplicationDelegate.h"
#include "serial.h"
#import "Terminal.h"

#include <termios.h>
#include <pwd.h>
#include <sys/stat.h>
#include <errno.h>
#include <unistd.h>


@implementation GUI

- (id)initCommon:(Boolean)iUnnamed name:(NSString*)fname plist:(NSDictionary*)dict
{
	filename = [ fname retain ] ;
	displayBacklog = 0 ;
	unnamed = iUnnamed ;
	terminalOpened = snifferOpened = NO ;
	
	termioLock = [ [ NSLock alloc ] init ] ;
	
	//  dictionary for plist items
	dictionary = [ [ NSMutableDictionary alloc ] initWithCapacity:8 ] ;		//  v0.2 was initing with nil dictionary
	//  create initial values for dictionary
	[ dictionary setObject:[ NSNumber numberWithInt:0 ] forKey:kTool ] ;
	[ dictionary setObject:@"" forKey:kTerminalPort ] ;
	[ dictionary setObject:[ NSNumber numberWithInt:9600 ] forKey:kTerminalBaudRate ] ;
	[ dictionary setObject:[ NSNumber numberWithInt:8 ] forKey:kTerminalBits ] ;
	[ dictionary setObject:[ NSNumber numberWithInt:1 ] forKey:kTerminalStopbits ] ;
	[ dictionary setObject:[ NSNumber numberWithInt:0 ] forKey:kTerminalParity ] ;
	[ dictionary setObject:[ NSNumber numberWithBool:YES ] forKey:kTerminalCRLF ] ;
	[ dictionary setObject:[ NSNumber numberWithBool:NO ] forKey:kTerminalRaw ] ;
	[ dictionary setObject:[ NSNumber numberWithBool:NO ] forKey:kTerminalRTS ] ;
	[ dictionary setObject:[ NSNumber numberWithBool:NO ] forKey:kTerminalDTR ] ;
	//  sniffer
	[ dictionary setObject:@"" forKey:kSnifferPortA ] ;
	[ dictionary setObject:@"" forKey:kSnifferPortB ] ;
	[ dictionary setObject:[ NSNumber numberWithBool:1 ] forKey:kAutoRTS ] ;
	[ dictionary setObject:[ NSNumber numberWithBool:NO ] forKey:kSnifferRaw ] ;
	[ dictionary setObject:[ NSNumber numberWithBool:NO ] forKey:kSnifferRTSa ] ;
	[ dictionary setObject:[ NSNumber numberWithBool:NO ] forKey:kSnifferDTRa ] ;
	[ dictionary setObject:[ NSNumber numberWithBool:NO ] forKey:kSnifferRTSb ] ;
	[ dictionary setObject:[ NSNumber numberWithBool:NO ] forKey:kSnifferDTRb ] ;
	[ dictionary setObject:[ NSNumber numberWithInt:9600 ] forKey:kSnifferBaudRate ] ;
	[ dictionary setObject:[ NSNumber numberWithInt:8 ] forKey:kSnifferBits ] ;
	[ dictionary setObject:[ NSNumber numberWithInt:1 ] forKey:kSnifferStopbits ] ;
	[ dictionary setObject:[ NSNumber numberWithInt:0 ] forKey:kSnifferParity ] ;


	
	//  now merge in any plist that is passed in
	if ( dict ) [ dictionary addEntriesFromDictionary:dict ] ;
	initialDictionary = [ [ NSMutableDictionary alloc ] initWithDictionary:dictionary ] ;
	
	originalTerminalPort = [ dict objectForKey:kTerminalPort ] ;
	if ( originalTerminalPort == nil ) originalTerminalPort = [ NSString stringWithString:@"" ] ;
	[ originalTerminalPort retain ] ;

	originalSnifferPortA = [ dict objectForKey:kSnifferPortA ] ;
	if ( originalSnifferPortA == nil ) originalSnifferPortA = [ NSString stringWithString:@"" ] ;
	[ originalSnifferPortA retain ] ;

	originalSnifferPortB = [ dict objectForKey:kSnifferPortB ] ;
	if ( originalSnifferPortB == nil ) originalSnifferPortB = [ NSString stringWithString:@"" ] ;
	[ originalSnifferPortB retain ] ;

	if ( [ NSBundle loadNibNamed:@"GUI" owner:self ] ) {
		return self ;
	}
	[ filename release ] ;
	[ dictionary release ] ;
	[ initialDictionary release ] ;
	return nil ;
}

- (id)initWithName:(NSString*)fname dictionary:(NSDictionary*)dict
{
	self = [ super init ] ;
	if ( self ) return [ self initCommon:NO name:@"SleepTrackerX" plist:dict ] ;
	return nil ;
}

- (id)initWithUntitled:(NSString*)fname dictionary:(NSDictionary*)dict
{
	self = [ super init ] ;
	if ( self ) return [ self initCommon:YES name:@"SleepTrackerX" plist:dict ] ;
	return nil ;
}

- (NSString *) makeSettingFileName
{
	struct passwd *passwd; 
	passwd = getpwuid ( getuid());
	
	NSString * userName = [[NSString alloc] initWithCString:passwd->pw_name encoding:NSASCIIStringEncoding] ;
	
	
	NSString *opath = @"/Users/";
	opath = [opath stringByAppendingString:userName];
	opath = [opath stringByAppendingString:@"/.SleepTrackerX/"];
	
	struct stat buf;
	int i = stat ( [opath cStringUsingEncoding:NSASCIIStringEncoding], &buf );
	
	if ( i ) // File exists
	{
		int ret = mkdir([opath cStringUsingEncoding:NSASCIIStringEncoding], S_IRWXU);
		
		if (ret)
		{
			NSLog(@"Error while creating dir : %d", ret);
			return (@"");
		}
	}
	chown([opath cStringUsingEncoding:NSASCIIStringEncoding], passwd->pw_uid, passwd->pw_gid);
	opath = [opath stringByAppendingString:@"Settings.plist"];	
	
	return(opath);
}

- (void) myChown:(NSString *) filePath
{
	struct passwd *passwd; 
	passwd = getpwuid ( getuid());
	chown([filePath cStringUsingEncoding:NSASCIIStringEncoding], passwd->pw_uid, passwd->pw_gid);
}


- (void) saveSettings:(id)sender
{

	NSString *opath = [self makeSettingFileName];

	NSMutableDictionary *plistData = [[NSMutableDictionary alloc] init];
	
	if (nil != pass)
	{
		NSLog(@"Pass : %@", [pass stringValue]);
		[plistData setObject:[pass stringValue] forKey:@"Password"];
	}
	if (nil != user)
	{
		NSLog(@"User : %@", [user stringValue]);
		[plistData setObject:[user stringValue] forKey:@"Username"];
	}

	[plistData writeToFile:opath atomically: YES];
	[plistData release];
	[self myChown:opath];
}

- (void) loadSettings:(id)sender
{
	NSString *ipath = [self makeSettingFileName];
	
	struct stat buf;
	int i = stat ( [ipath cStringUsingEncoding:NSASCIIStringEncoding], &buf );
	
	if ( !i ) // File exists
	{
		NSMutableDictionary *plistData = [NSDictionary dictionaryWithContentsOfFile:ipath];
		NSString * userName = [plistData valueForKey:@"Username"];
		NSString * passWord = [plistData valueForKey:@"Password"];
		[user setStringValue:userName];
		[pass setStringValue:passWord];
	}
}

- (void)dealloc
{
	[ filename release ] ;
	[ dictionary release ] ;
	[ initialDictionary release ] ;
	[ originalTerminalPort release ] ;
	[ originalSnifferPortA release ] ;
	[ originalSnifferPortB release ] ;
	[ super dealloc ] ;
}

- (void)setInterface:(NSControl*)object to:(SEL)selector
{
	[ object setAction:selector ] ;
	[ object setTarget:self ] ;
}

- (void)awakeFromNib
{
	[ window setTitle:filename ] ;
	[ window setDelegate:self ] ;
	[ window makeKeyAndOrderFront:self ] ;
	
	[ self setInterface:connectButton to:@selector(connectButtonChanged:) ] ;
	
	[self setInterface:sendButton to:@selector(requestData:)];

	[self setInterface:saveSettingdButton to:@selector(saveSettings:)];

	[ progressIndicator setUsesThreadedAnimation:YES ] ;
	
	
	//  terminal window
	
	[ self findPorts ] ;
	[self loadSettings:self];

//	[ NSThread detachNewThreadSelector:@selector(terminalControlThread) toTarget:self withObject:nil ] ;
//	[ NSThread detachNewThreadSelector:@selector(snifferControlThread) toTarget:self withObject:nil ] ;
}

- (void)activate
{
	[ window makeKeyAndOrderFront:self ] ;
}
	

- (int)findPorts
{
	CFStringRef cstream[32], cpath[32] ;
	int i, count ;
	
	count = findPorts( cstream, cpath, 32 ) ;
	for ( i = 0; i < count; i++ ) {
		stream[i] = [ [ NSString stringWithString:(NSString*)cstream[i] ] retain ] ;
		CFRelease( cstream[i] ) ;
		path[i] = [ [ NSString stringWithString:(NSString*)cpath[i] ] retain ] ;
		CFRelease( cpath[i] ) ;
	}
	return count ;
}


- (void)closeTerminal
{
	[ terminal closeConnections ] ;
	terminalOpened = NO ;
}

- (void)disconnectTerminal
{
	if ( terminalOpened ) {
		[ self closeTerminal ] ;
		[ connectButton setTitle:@"Upload Data" ] ;
		[ connectButton display ] ;
	}
}

- (void)connectTerminal
{
	const char *port ;
	Boolean opened ;
	
	if ( terminalOpened == NO ) {
		
		[ progressIndicator startAnimation:self ] ;
		
		const char *usbSerialPath = NULL;
		for (int i = 0; path[i]; ++i)
		{
			if (NULL != strstr( [ path[i] cStringUsingEncoding:NSASCIIStringEncoding ], "usbserial"))
			{
				usbSerialPath = [ path[i] cStringUsingEncoding:NSASCIIStringEncoding ];
				break;
			}
		}
		if (!usbSerialPath)
		{
			[ [ NSAlert alertWithMessageText:[ NSString stringWithFormat:@"Cannot find usb serial port." ] defaultButton:@"OK" alternateButton:nil otherButton:nil 
				   informativeTextWithFormat:@"No usbSerial port found, maybe you didn't install the usbserial driver or the watch isn't pluged to the computer" ] runModal ] ;
			//NSLog(@"No usbSerial port found, maybe you didn't install the usbserial driver or the watch isn't pluged to the computer");
			exit(-1);
		}
		
		port = usbSerialPath;
		opened = [ terminal openConnections:port baudrate:2400 bits:8 parity:0 stopBits:1 ];
		
		if ( opened == NO ) {
			[ [ NSAlert alertWithMessageText:[ NSString stringWithFormat:@"Cannot open terminal port." ] defaultButton:@"OK" alternateButton:nil otherButton:nil 
				informativeTextWithFormat:@"The selected terminal port would not open." ] runModal ] ;
			[ progressIndicator stopAnimation:self ] ;
			return ;
		}
		
		//  successful open connection
		terminalOpened = YES ;
		//TODO : check crlf status
//		[ terminal setCrlfEnable:( [ crlf state ] == NSOnState ) ] ;
//		[ terminal setRawEnable:( [ rawCheckbox state ] == NSOnState ) ] ;

		[ connectButton setTitle:@"Disconnect" ] ;
		[ progressIndicator stopAnimation:self ] ;
	}
}


- (void)connectButtonChanged:(id)sender ;
{
	if ( terminalOpened )
	{
		[ self disconnectTerminal ];
	}
	else
	{
		[ self connectTerminal ] ;
		NSLog(@"Envoie de V\r");
		[terminal transmitCharacters:@"V"];
	}
}

- (void)terminalParamsChanged:(id)sender
{
}

- (void)paRtsCheckboxChanged:(id)sender
{
}

- (void)paDtrCheckboxChanged:(id)sender
{
}



static int hex( NSString *str )
{
	int value ;
	
	sscanf( [ str cStringUsingEncoding:NSASCIIStringEncoding ], "%x", &value ) ;
	return value & 0xff ;
}

- (void)setTextField:(NSTextField*)field forKey:(NSString*)key
{
	[ dictionary setObject:[ field stringValue ] forKey:key ] ;
}

- (void)setPopUpButton:(NSPopUpButton*)field forKey:(NSString*)key alternative:(NSString*)alt
{
	NSString *title ;
	
	title = [ field titleOfSelectedItem ] ;
	if ( title == nil ) title = alt ;
	[ dictionary setObject:title forKey:key ] ;
}

- (void)updatePlist
{

}

//  called when window is closing or app is terminating
- (Boolean)shouldTerminate
{
	int reply ;
	
	[ self updatePlist ] ;
	
	if ( [ initialDictionary isEqualToDictionary:dictionary ] == NO ) {
		reply = [ [ NSAlert alertWithMessageText:[ NSString stringWithFormat:@"Do you want save changes made to %s?", 
			[ filename cStringUsingEncoding:NSASCIIStringEncoding ] ] defaultButton:@"Save" alternateButton:@"Don't Save" otherButton:@"Cancel" informativeTextWithFormat:@"" ] 
			runModal ] ;	

		if ( reply == -1 ) /* cancel */ return NO ;
		if ( reply == 1 ) {
			/* save */ 
			[ dictionary setObject:[ window stringWithSavedFrame ] forKey:kGUIWindowPosition ] ;
			if ( unnamed ) [ self saveGUIAs ] ; else [ dictionary writeToFile:filename atomically:YES ] ;
			[ self disconnectTerminal ] ;
			return YES ;
		}
	}
	if ( !unnamed ) {
		//  always update window positions
		[ initialDictionary setObject:[ window stringWithSavedFrame ] forKey:kGUIWindowPosition ] ;
		[ initialDictionary writeToFile:filename atomically:YES ] ;
	}
	[ self disconnectTerminal ] ;
	return YES ;
}

//  local
- (void)save
{
	[ self updatePlist ] ;		//  v0.2
	[ dictionary writeToFile:filename atomically:YES ] ;
	//  make the save dictionay our "initial" dictionary
	[ initialDictionary autorelease ] ;
	initialDictionary = [ [ NSMutableDictionary alloc ] initWithDictionary:dictionary ] ;
}

- (void)saveGUI
{
	if ( unnamed ) [ self saveGUIAs ] ; else [ self save ] ;
}

- (void)saveGUIAs
{
	NSSavePanel *panel ;
	int resultCode ;
	
	panel = [ NSSavePanel savePanel ] ;
	[ panel setTitle:@"Save..." ] ;   
	[ panel setRequiredFileType:@"sertool" ] ;
	
	resultCode = [ panel runModalForDirectory:nil file:[ filename lastPathComponent ] ] ;
	if ( resultCode != NSOKButton ) return ;
	
	if ( filename ) [ filename autorelease ] ;
	filename = [ [ panel filename ] retain ] ;
	[ self save ] ;
	
	[ window setTitle:filename ] ;
//	[ (ApplicationDelegate*)[ NSApp delegate ] addToRecentFiles:filename ] ;
	unnamed = NO ;
}

- (IBAction)clear:(id)sender
{
}

//  window delegate
- (void)windowDidBecomeMain:(NSNotification *)notification
{
	[ (ApplicationDelegate*)[ NSApp delegate ] guiBecameActive:self ] ;
}

//  window delegate
- (BOOL)windowShouldClose:(id)win
{
	Boolean closing ;
	
	[ self closeTerminal ] ;
	closing = [ self shouldTerminate ] ;
	if ( closing ) [ [ NSApp delegate ] guiClosing:self ] ;
	exit(0);
}


- (void)requestData:(id)sender ; 
{
	NSLog(@"Send de V\r");
	[terminal transmitCharacters:@"V"];

}


- (void)terminalControlThread
{
	NSAutoreleasePool *pool = [ [ NSAutoreleasePool alloc ] init ] ;
	
	while ( 1 ) {
		if ( terminalOpened ) {
			[ NSThread sleepUntilDate:[ NSDate dateWithTimeIntervalSinceNow:0.25 ] ] ;
		}
		else {
			[ NSThread sleepUntilDate:[ NSDate dateWithTimeIntervalSinceNow:1.0 ] ] ;
		}
	}
	[ pool release ] ;
}

@end
