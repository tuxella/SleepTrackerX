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
- (void)initTerminal
{
	inputfd = outputfd = -1 ;
}

- (id)init
{
	self = [super init] ;
	[self initTerminal] ;
	return self ;
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
	
	NSString * report = [myND newReport];
	[viewableData appendFormat:@"%@", report];
	[report release];
	
	//Retrieve URL and open it in the default browser of the user
	NSString * sleeptrackerNetURL = [myND newURL];
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:sleeptrackerNetURL]];
	[sleeptrackerNetURL release];
	
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

	[ self closeInputConnection ];
	[ pool release ] ;
}

@end
