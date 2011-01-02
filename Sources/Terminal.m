//
//  Terminal.m
//  SleepTrackerX
//
//  2010 tuxella after Serial Tools from Kok Chen
//

#import "Terminal.h"


#include <sys/select.h>
#include <termios.h>
#include <sys/ioctl.h>
#include <unistd.h>



@implementation Terminal

- (void)initTerminal
{
	inputfd = outputfd = -1 ;
	connState = [[ConnectionState alloc] init];
}

- (id)init
{
	self = [super init] ;
	[self initTerminal] ;
	return self;
}

- (id)initWithCoder:(NSCoder*)decoder
{
	self =  [ super initWithCoder:decoder ] ;
	[ self initTerminal ] ;
	return self ;
}
//  common function to open port and set up serial port parameters
int openPort( const char *path, int speed, int bits, int parity, int stops, int openFlags, Boolean input )
{
	int fd, cflag ;
	struct termios termattr ;
	
	fd = open( path, openFlags ) ;
	if ( fd < 0 ) return -1 ;
	
	//  build other flags
	cflag = 0 ;
	cflag |= ( bits == 7 ) ? CS7 : CS8 ;			//  bits
	if ( parity != 0 ) {
		cflag |= PARENB ;							//  parity
		if ( parity == 1 ) cflag |= PARODD ;
	}
	if ( stops > 1 ) cflag |= CSTOPB ;
	
	//  merge flags into termios attributes
	tcgetattr( fd, &termattr ) ;
	termattr.c_cflag &= ~( CSIZE | PARENB | PARODD | CSTOPB ) ;	// clear all bits and merge in our selection
	termattr.c_cflag |= cflag ;
	
	// set speed, split speed not support on Mac OS X?
	cfsetispeed( &termattr, speed ) ;
	cfsetospeed( &termattr, speed ) ;
	//  set termios
	tcsetattr( fd, TCSANOW, &termattr ) ;

	return fd ;
}

- (void)closeInputConnection
{
	if ( inputfd > 0 ) close( inputfd ) ;
	inputfd = -1 ;
}

- (void)closeOutputConnection
{
	if ( outputfd >= 0 ) close( outputfd ) ;
	outputfd = -1 ;
}

/* Quite hackish. The good solution would be to move the connectTerminal logic from GUI.m to Terminal.m or
 * maybe a third party object that would be in charge of the control of the protocol (finitie state automaton
 * would be overkill for the simple protocol we have to deal with)
 */
- (Boolean) changeConnectionParams:(int)baud bits:(int)bits parity:(int)parity stopBits:(int)stops
{
	[self closeConnections];

	pbaudrate = (NSInteger) baud;
	pbits = (NSInteger) bits;
	pparity = (NSInteger) parity;
	pstopBits = (NSInteger) stops;
	
	inputfd = openPort([pport cString], baud, bits, parity, stops, ( O_RDONLY | O_NOCTTY | O_NDELAY ), YES ) ;
	if ( inputfd < 0 ) return NO ;	
	
	outputfd = openPort([pport cString], baud, bits, parity, stops, ( O_WRONLY | O_NOCTTY | O_NDELAY ), NO ) ;
	if ( outputfd < 0 ) {
		[ self closeInputConnection ] ;
		return NO ;
	}
	return YES;
}


- (Boolean)openConnections:(const char*)port baudrate:(int)baud bits:(int)bits parity:(int)parity stopBits:(int)stops
{
	pport = [[NSString alloc] initWithCString:port];
	pbaudrate = (NSInteger) baud;
	pbits = (NSInteger) bits;
	pparity = (NSInteger) parity;
	pstopBits = (NSInteger) stops;
	
	inputfd = openPort( port, baud, bits, parity, stops, ( O_RDONLY | O_NOCTTY | O_NDELAY ), YES ) ;
	if ( inputfd < 0 ) return NO ;	
		
	outputfd = openPort( port, baud, bits, parity, stops, ( O_WRONLY | O_NOCTTY | O_NDELAY ), NO ) ;
	if ( outputfd < 0 ) {
		[ self closeInputConnection ] ;
		return NO ;
	}
	//  start the read thread

	
	[ NSThread detachNewThreadSelector:@selector(readThread) toTarget:self withObject:nil ] ;
	return YES ;
}

 - (void)closeConnections
 {
	[ self closeInputConnection ] ;
	[ self closeOutputConnection ] ;
 }



- (void)transmitCharacters:(NSString*)string
{
	const char *s ;
	int length ;
	
	if ( outputfd >= 0 ) {
		s = [ string cStringUsingEncoding:NSASCIIStringEncoding ] ;
		if ( s && ( length = [ string length ] ) > 0 ) {
			if ( *s && length > 0 ) write( outputfd, s, length ) ;
		}
	}
}

- (void)transmitBytes:(const char *)bytes length:(NSInteger) len
{
	const char *s ;
	
	if ( outputfd >= 0 ) {
		s = bytes;
		if ( *s && len > 0 ) write( outputfd, s, len );
	}
}


- (void) startDataRetrieval
{
	// Need to close / reopen the port with new parameters ? (baudrate = 19600 ?)
	[self sendCommand:cmdGetDataV1];
	[NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
	
	if (cstDataRetrieved == [connState state]) {
		return;
	}
	[self sendCommand:cmdGetToBedAndAlarmV2];
	[NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];

	if (cstDataRetrieved != [connState state]) {
		//Fail
		[ [ NSAlert alertWithMessageText:[ NSString stringWithFormat:@"Cannot retrieve the alarm time from the watch." ] defaultButton:@"OK" alternateButton:nil otherButton:nil 
			   informativeTextWithFormat:@"This is a case that shouldn't happen, maybe a bug ?" ] runModal ] ;
	}
	
	[self sendCommand:cmdGetDataV2];
	[NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
	[connState setState:cstReady];

}

- (void) sendCommand:(NSInteger) command
{
	switch (command) {
		case cmdGetDataV1:
			NSLog(@"Sending V command (V1 watches)\n");
			[self transmitCharacters:@"V"];
			[connState setState:cstWaitingForDataV1];
			break;
		case cmdGetDataV2:
			NSLog(@"Sending Get Data command (V2 watches)\n");
			char cmdData[5] = {0xC0, 0x05, 0x33, 0x00, 0};
			[self transmitBytes:cmdData length:4];
			[connState setState:cstWaitingForDataV2];
			break;
		case cmdGetToBedAndAlarmV2:
			NSLog(@"Sending Get Bet Time and Alarm command (V2 watches)\n");
			char cmdBedAlarm[5] = {0xC0, 0x04, 0x33, 0x00, 0};
			[self transmitBytes:cmdBedAlarm length:4];
			[connState setState:cstWaitingForAlarmsAndToBed];
			break;
		default:
			NSLog(@"Unknown command\n");
			[connState setState:cstReady];
			break;
	}
}


//  insert input (called into the main runloop from -readThread to avaoid ThreadSafe issues of NSView).
- (void)insertInput:(NSString*)input
{
	NSRange insertion ;
	const char * buffer = [input cStringUsingEncoding:NSASCIIStringEncoding];
	printf("[BEGIN]\n");
	NSMutableString *viewableData = [[NSMutableString alloc] initWithString:@""];
	
	myND = [[NightData alloc] initWithBuffer:(const char *)buffer];
	if (nil == myND)
	{
		return;
	}
	
	//Retrieve 
	NSString * report = [myND newReport];
	[viewableData appendFormat:@"%@", report];
	[report release];
	
	//Retrieve URL and open it in the default browser of the user
	NSString * sleeptrackerNetURL = [myND newURL];
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:sleeptrackerNetURL]];
	[sleeptrackerNetURL release];
	
	insertion.location = [ [ self string ] length ] ;

	insertion.length = 0 ;
	[ self setSelectedRange:insertion ] ;
	[ self insertText:viewableData ] ;
	[ self setNeedsDisplay:YES ] ;		//  v0.2
}

//  thread that loops on a select() call, waiting for input (so that the main thread does not block)
- (void)readThread
{
	NSAutoreleasePool *pool = [ [ NSAutoreleasePool alloc ] init ] ;
	NSString *string ;
	fd_set readfds, basefds, errfds ;
	int selectCount, bytesRead, i;
	char buffer[1024];
	char outBuffer[250];
	for (int i = 0; i < 250; ++i) outBuffer[i] = 0;
	int outBitsWritten= 0;
	int outBitsToWrite = 250;
	
	FD_ZERO( &basefds ) ;
	FD_SET( inputfd, &basefds ) ;	
	struct timeval oneSec;
	oneSec.tv_sec = 1;
	
	//Waiting betwwen the thread start and the first command sent
	while (cstNotReadyYet == [connState state]) {
		[NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]] ;
	}  
	NSInteger cStatus;
	while ((cstReady != (cStatus = [connState state])) && 
		   (cstDataRetrieved != (cStatus = [connState state]))) {
		if (cstWaitingForDataV1 == cStatus) {
			while ( outBitsWritten < outBitsToWrite) {
				FD_COPY( &basefds, &readfds ) ;
				FD_COPY( &basefds, &errfds ) ;
				selectCount = select( inputfd+1, &readfds, NULL, &errfds, nil ) ;
				if ( selectCount > 0 ) {
					if ( FD_ISSET( inputfd, &errfds ) ) break ;		//  exit if error in stream
					if ( selectCount > 0 && FD_ISSET( inputfd, &readfds ) )
					{
						//  read into buffer, cnvert to NSString and send to the NSTextView.
						[ NSThread sleepUntilDate:[ NSDate dateWithTimeIntervalSinceNow:0.01 ] ] ;
						bytesRead = read( inputfd, buffer, 1024 ) ;

						for ( i = 0; (i < bytesRead) && (outBitsWritten < outBitsToWrite) ; i++ )
						{
							if (outBitsWritten >= 1) //prevent from getting the command sent to the watch
							{
								outBuffer[outBitsWritten - 1] = buffer[i];
								if (9 == outBitsWritten)
									outBitsToWrite = buffer[i] * 3 + 9 + 1; // (Hours + minutes + seconds) *3 + initial bits + V (the sent byte)
							}
							outBitsWritten++;
						}
					}
				}
			}
			[connState setState:cstDataRetrieved];
			outBuffer[outBitsWritten ] = 0;
			string = [ [ [ NSString alloc ] initWithBytes:outBuffer length:outBitsWritten - 1 encoding:NSASCIIStringEncoding ] autorelease ] ;
			[ self performSelectorOnMainThread:@selector(insertInput:) withObject:string waitUntilDone:YES ] ;
		}
	}

	[self closeInputConnection];
	[pool release];
}

@end
