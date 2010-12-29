//
//  Terminal.m
//  SleepTrackerX
//
//  2010 tuxella. GPL 3+
//

#import "Terminal.h"
#import "NightData.h"

#include <sys/select.h>
#include <termios.h>
#include <sys/ioctl.h>
#include <unistd.h>



@implementation Terminal

//  Terminal.m is a subclass of NSTextView which is connected through a serial port.
//  Anything that is typed into the view is sent out throught the serial port and anything that comes in is displayed in the view.
//
//  Use -openInputConnection and -openOutputConnection to open either direction of the serial port, or -openConnections to open both directions.
//  Close the ports with -closeInputConnection, -closeOutputConnection or -closeConnections.
//
//  Use -setCrlfEnable to convert outgoing newlines to cr/lf pairs.

//  common init code
- (void)initTerminal
{
	inputfd = outputfd = -1 ;
}

- (id)init
{
	self = [ super init ] ;
	[ self initTerminal ] ;
	return self ;
}

- (id)initWithCoder:(NSCoder*)decoder
{
	self =  [ super initWithCoder:decoder ] ;
	[ self initTerminal ] ;
	return self ;
}

- (id)initWithFrame:(NSRect)frameRect
{
	self = [ super initWithFrame:frameRect ] ;
	[ self initTerminal ] ;
	return self ;
}


- (int)getTermios
{
	int bits ;
	
	if ( inputfd ) {
		ioctl( inputfd, TIOCMGET, &bits ) ;
		return bits ;
	}
	return 0 ;
}

- (void)setRTS:(Boolean)state
{
	int bits ;

	if ( inputfd ) {
		ioctl( inputfd, TIOCMGET, &bits ) ;
		if ( state ) bits |= TIOCM_RTS ; else bits &= ~( TIOCM_RTS ) ;
		ioctl( inputfd, TIOCMSET, &bits ) ;
	}
}

- (void)setDTR:(Boolean)state
{
	int bits ;

	if ( inputfd ) {
		ioctl( inputfd, TIOCMGET, &bits ) ;
		if ( state ) bits |= TIOCM_DTR ; else bits &= ~( TIOCM_DTR ) ;
		ioctl( inputfd, TIOCMSET, &bits ) ;
	}
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

- (Boolean)openInputConnection:(const char*)port baudrate:(int)baud bits:(int)bits parity:(int)parity stopBits:(int)stops
{
	[ self closeInputConnection ] ;		//  v0.2  sanity check
	
	inputfd = openPort( port, baud, bits, parity, stops, ( O_RDONLY | O_NOCTTY | O_NDELAY ), YES ) ;
	if ( inputfd < 0 ) return NO ;
	
	//  If the input is opened successfully, start a thread to monitor characters from it and echoing received
	//  characters to the text view.
	[ NSThread detachNewThreadSelector:@selector(readThread) toTarget:self withObject:nil ] ;

	return YES ;
}

- (void)closeInputConnection
{
	if ( inputfd > 0 ) close( inputfd ) ;
	inputfd = -1 ;
}

- (Boolean)openOutputConnection:(const char*)port baudrate:(int)baud bits:(int)bits parity:(int)parity stopBits:(int)stops
{	
	[ self closeOutputConnection ] ;	//  v0.2  sanity check
	
	outputfd = openPort( port, baud, bits, parity, stops, ( O_WRONLY | O_NOCTTY | O_NDELAY ), NO ) ;
	return ( outputfd > 0 ) ;
}

- (void)closeOutputConnection
{
	if ( outputfd >= 0 ) close( outputfd ) ;
	outputfd = -1 ;
}

- (Boolean)inputConnected
{
	return ( inputfd > 0 ) ;
}

- (Boolean)outputConnected
{
	return ( outputfd > 0 ) ;
}

- (Boolean)connected
{
	return ( [ self inputConnected ] && [ self outputConnected ] ) ;
}


- (Boolean)openConnections:(const char*)port baudrate:(int)baud bits:(int)bits parity:(int)parity stopBits:(int)stops
{
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

- (int)inputFileDescriptor
{
	return inputfd ;
}

- (int)outputFileDescriptor
{
	return outputfd ;
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

- (void)keyDown:(NSEvent*)event
{
	/*
	NSRange insertion ;
	int inserting, deleting ;
	
	//  only allow appends
	insertion.location = [ [ self string ] length ] ;
	insertion.length = 0 ;
	[ self setSelectedRange:insertion ] ;
	//  don't delete beyond the beginning of a line
	inserting = [ [ event characters ] characterAtIndex:0 ] ;
	if ( inserting == 127 ) {
		if ( insertion.location == 0 ) {
			NSBeep() ;
			return ;
		}
		deleting = [ [ self string ] characterAtIndex:insertion.location-1 ] ;
		if ( deleting == 10 || deleting == 13 ) {
			//  trying to delete past a newline character
			NSBeep() ;
			return ;
		}
	}
	[ self transmitCharacters:[ event characters ] ] ;
	[ super keyDown:event ] ;
	 */
}

//  insert input (called into the main runloop from -readThread to avaoid ThreadSafe issues of NSView).
- (void)insertInput:(NSString*)input
{
	NSRange insertion ;
//	NSLog("len : %d", [input length]);
//	const char * buffer = [input cStringUsingEncoding:NSASCIIStringEncoding];
	const char * buffer = [input cStringUsingEncoding:NSASCIIStringEncoding];
	printf("[BEGIN]\n");
	NSMutableString *viewableData = [[NSMutableString alloc] initWithString:@""];
	
	myND = [[NightData alloc] initWithBuffer:(const char *)buffer];

	[viewableData appendFormat:@"%@", [myND generateReport]];
	
	//Retrieve URL and open it in the default browser of the user
	NSString * sleeptrackerNetURL = [myND generateURL];
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:sleeptrackerNetURL]];
	
	insertion.location = [ [ self string ] length ] ;
	NSLog(@"- (void)insertInput:(NSString*)string");
	

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


	
	while ( outBitsWritten < outBitsToWrite) {
		FD_COPY( &basefds, &readfds ) ;
		FD_COPY( &basefds, &errfds ) ;
		selectCount = select( inputfd+1, &readfds, NULL, &errfds, nil ) ;
//		selectCount = select( inputfd+1, &readfds, NULL, &errfds, &oneSec ) ;
// TODO : Pop an error message if no data has been retrieved withing 1 second
		if ( selectCount > 0 ) {
			if ( FD_ISSET( inputfd, &errfds ) ) break ;		//  exit if error in stream
			if ( selectCount > 0 && FD_ISSET( inputfd, &readfds ) )
			{
				//  read into buffer, cnvert to NSString and send to the NSTextView.
				[ NSThread sleepUntilDate:[ NSDate dateWithTimeIntervalSinceNow:0.01 ] ] ;	// v0.2
				bytesRead = read( inputfd, buffer, 1024 ) ;

				for ( i = 0; (i < bytesRead) && (outBitsWritten < outBitsToWrite) ; i++ )
				{
					if (outBitsWritten >= 1) //prevent from getting the command sent to the watch
					{
						outBuffer[outBitsWritten - 1] = buffer[i];
						if (9 == outBitsWritten) outBitsToWrite = buffer[i] * 3 + 9 + 1; // (Hours + minutes + seconds) *3 + initial bits + V (the sent byte)
					}

					outBitsWritten++;
				}

			}
		}
	}
	outBuffer[outBitsWritten ] = 0;
	string = [ [ [ NSString alloc ] initWithBytes:outBuffer length:outBitsWritten - 1 encoding:NSASCIIStringEncoding ] autorelease ] ;
	[ self performSelectorOnMainThread:@selector(insertInput:) withObject:string waitUntilDone:YES ] ; // v0.2

	[ self closeInputConnection ] ;			//  v0.2  use this instead of close()
	[ pool release ] ;
}

@end