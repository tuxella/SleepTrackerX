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

	[progressIndicator setUsesThreadedAnimation:YES];
	
	
	[self findPorts];
	[self loadSettings:self];
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
		
		terminalOpened = YES ;

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
		[self connectTerminal] ;
		NSLog(@"Sending V command (V1 watches)\r");
		[terminal transmitCharacters:@"V"];
	}
}


- (void)updatePlist
{

}

//  called when window is closing or app is terminating
- (Boolean)shouldTerminate
{
	[self updatePlist];
	[self disconnectTerminal];
	return YES ;
}


//  window delegate
- (void)windowDidBecomeMain:(NSNotification *)notification
{
	[ (ApplicationDelegate*)[ NSApp delegate ] guiBecameActive:self ] ;
}

//  window delegate
- (BOOL)windowShouldClose:(id) win
{
	Boolean closing ;
	
	[ self closeTerminal ] ;
	closing = [ self shouldTerminate ] ;
	if ( closing ) [ [ NSApp delegate ] guiClosing:self ] ;
	exit(0);
}


@end
