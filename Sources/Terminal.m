//
//  Terminal.m
//  SleepTrackerX
//
//  2010 tuxella after Serial Tools from Kok Chen
//

#import "Terminal.h"
#import "RetrievedBuffer.h"

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
	
	inputfd = openPort([pport cStringUsingEncoding:NSASCIIStringEncoding], baud, bits, parity, stops, ( O_RDONLY | O_NOCTTY | O_NDELAY ), YES ) ;
	if ( inputfd < 0 ) return NO ;	
	
	outputfd = openPort([pport cStringUsingEncoding:NSASCIIStringEncoding], baud, bits, parity, stops, ( O_WRONLY | O_NOCTTY | O_NDELAY ), NO ) ;
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

	
	//[ NSThread detachNewThreadSelector:@selector(readThread) toTarget:self withObject:nil ] ;
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

- (NSInteger)transmitBytes:(const char *)bytes length:(NSInteger) len
{
	const char *s ;
	NSInteger bytesCount = 0;
	if ( outputfd >= 0 ) {
		s = bytes;
		if ( *s && len > 0 )
		{
			bytesCount = write( outputfd, s, len );
			return bytesCount;
		}
	}
	return (-1);
}


- (void) startDataRetrieval
{
	// Need to close / reopen the port with new parameters ? (baudrate = 19600 ?)
	[NSThread detachNewThreadSelector:@selector(readThreadDataV1) toTarget:self withObject:nil] ;
	lastDataHasBeenProcessed = NO;
	[self sendCommand:cmdGetDataV1];
	[NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:2]];
	
	if (cstDataRetrieved == [connState state]) {
		return;
	}

	[self changeConnectionParams:19200 bits:pbits parity:pparity stopBits:1];

	/*
	 This could be used to retrieve the date from the watch, but by now we will just use the date of the computer
	 Current state of the understanding of the buffer format : (Command = {0xC0, 0x02, 0x00, 0xC0})
	 192	C0	Init token		
	 2	Command	Get Date ?		
	 4	len	4 bytes		
	 0		+ 0 bytes		
	 25		25		
	 1		January		
	 219		2011 ?	2015 = 223	2012=220
	 221				
	 7				
	 192	C0	End token		
 
	 
	[self sendCommand:cmdGetDate];
	[NSThread detachNewThreadSelector:@selector(readThreadDebug) toTarget:self withObject:nil] ;
	*/
	lastDataHasBeenProcessed = NO;
	[self sendCommand:cmdGetToBedAndAlarmV2];
	
	[NSThread detachNewThreadSelector:@selector(readThreadBedTime) toTarget:self withObject:nil] ;
	
//	[NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:5]];
	//return;
	if (cstDataRetrieved != [connState state]) {
		//Fail
//		[ [ NSAlert alertWithMessageText:[ NSString stringWithFormat:@"Cannot retrieve the alarm time from the watch." ] defaultButton:@"OK" alternateButton:nil otherButton:nil 
//			   informativeTextWithFormat:@"This is a case that shouldn't happen, maybe a bug ?" ] runModal ] ;
	}
	while ((cstDataProcessed != [connState state]) &&
		   (cstTimedOut != [connState state])) {
		[NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:1]];
		NSLog(@"Waiting for the ToBedDate to be read");
	}
	while (!lastDataHasBeenProcessed) {
		[NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:1]];
		NSLog(@"Waiting for the ToBedDate to be processed");
	}	
	lastDataHasBeenProcessed = NO;
	[self sendCommand:cmdGetDataV2];	
	[NSThread detachNewThreadSelector:@selector(readThreadDataV2) toTarget:self withObject:nil] ;
//	[NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
	while ((cstDataProcessed != [connState state]) &&
		   (cstTimedOut != [connState state])) {
		[NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.2]];		
	}
	
	//[connState setState:cstReady];
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
			char cmdData[4] = {0xC0, 0x05, 0x00, 0xC0};
			[self transmitBytes:cmdData length:4];
			[connState setState:cstWaitingForDataV2];
			break;
		case cmdGetToBedAndAlarmV2:
			NSLog(@"Sending Get Bet Time and Alarm command (V2 watches)\n");
			char cmdBedAlarm[4] = {0xC0, 0x04, 0x00, 0xC0};
			[self transmitBytes:cmdBedAlarm length:4];
			[connState setState:cstWaitingForAlarmsAndToBed];
			break;
		case cmdGetDate:
			NSLog(@"Sending Get Date command (V2 watches)\n");
			char cmdGDate[4] = {0xC0, 0x02, 0x00, 0xC0};
			//char cmdGDate[4] = {0xC0, 0x03, 0x00, 0xC0}; => Not getDate
			[self transmitBytes:cmdGDate length:4];
			[connState setState:cstWaitingForDate];
			break;
		default:
			NSLog(@"Unknown command\n");
			[connState setState:cstReady];
			break;
	}
}


- (void)processData:(RetrievedBuffer *)input
{
	unsigned char * buffer;
	buffer = (unsigned char *) [[input buffer] bytes];
	NSMutableString *viewableData = [[NSMutableString alloc] initWithString:@""];
	switch ([input kind]) {
		case rbuUndef:
			// Should handle the error
			break;
		case rbuDataV1:
			NSLog(@"Got a buffer for retrieved Data V1");
			myND = [[NightData alloc] initWithBuffer:(const char *)buffer];
			if (nil == myND)
			{
				return;
			}
			break;
		case rbuDataV2:
			NSLog(@"Got a buffer for retrieved Data V2");
			if (nil == myND)
			{
				myND = [[NightData alloc] init];
			}
			[myND readAlmostAwake:(const char *) buffer];
			break;
		case rbuToBedAndAlarm:
			NSLog(@"Got a buffer for retrieved To bed and alarm");
			if (nil == myND)
			{
				myND = [[NightData alloc] init];
			}
			[myND readToBedAndAlarm:(const char *) buffer];
			break;

		default:
			break;
	}
	[connState setState:cstDataProcessed];
	lastDataHasBeenProcessed = YES;
	if ([myND isReady]) {
		//Retrieve
		NSString * report = [myND newReport];
		[viewableData appendFormat:@"%@", report];
		[report release];
	
		//Retrieve URL and open it in the default browser of the user
		NSString * sleeptrackerNetURL = [myND newURL];
		[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:sleeptrackerNetURL]];
		[sleeptrackerNetURL release];

		NSRange insertion ;
		insertion.location = [ [ self string ] length ] ;
		insertion.length = 0 ;
		[ self setSelectedRange:insertion ] ;
		[ self insertText:viewableData ] ;
		[ self setNeedsDisplay:YES ] ;		//  v0.2
	}
}


- (BOOL) readThreadDataV1
{
	NSString *string ;
	fd_set readfds, basefds, errfds ;
	int selectCount, bytesRead, i;
	char buffer[1024];
	char outBuffer[250];
	for (int i = 0; i < 250; ++i) outBuffer[i] = 0;
	int outBitsWritten= 0;
	int outBitsToWrite = 250;
	
	FD_ZERO( &basefds ) ;
	FD_SET( inputfd, &basefds );
	struct timeval oneSec;
	oneSec.tv_sec = 1;
	
	//Waiting betwwen the thread start and the first command sent
	while (cstNotReadyYet == [connState state]) {
		[NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]] ;
	}  
	NSInteger cStatus;
	BOOL timedOut = NO;
	//////////////////// Read DATA V1
	while ((cstReady != (cStatus = [connState state])) && 
		   (cstDataRetrieved != (cStatus = [connState state]))) {
		if (cstWaitingForDataV1 == cStatus) {
			timedOut = NO;
			while ((outBitsWritten < outBitsToWrite) && (!timedOut)) {
				FD_COPY( &basefds, &readfds ) ;
				FD_COPY( &basefds, &errfds ) ;
				//selectCount = select( inputfd+1, &readfds, NULL, &errfds, nil ) ;
				selectCount = select( inputfd+1, &readfds, NULL, &errfds, &oneSec) ;
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
					timedOut = YES;
				}
				else {
					timedOut = YES;
				}
			}
			if (!timedOut)
			{
				[connState setState:cstDataRetrieved];
				outBuffer[outBitsWritten ] = 0;
				string = [ [ [ NSString alloc ] initWithBytes:outBuffer length:outBitsWritten - 1 encoding:NSASCIIStringEncoding ] autorelease ] ;
				RetrievedBuffer * rBuffer = [[RetrievedBuffer alloc] init];
				//IWH
				[rBuffer setBuffer:(unsigned char *)outBuffer length:outBitsWritten + 1];
				[rBuffer setLength:outBitsWritten];
				[rBuffer setBufferKind:rbuDataV1];
				[ self performSelectorOnMainThread:@selector(processData:) withObject:rBuffer waitUntilDone:NO ] ;
				return (YES);
			}
		}
	}
	return (NO);
}


- (BOOL) readThreadBedTime
{
	fd_set readfds, basefds, errfds ;
	int selectCount, bytesRead;
	char outBuffer[250];
	for (int i = 0; i < 250; ++i) outBuffer[i] = 0;
	
	FD_ZERO( &basefds ) ;
	FD_SET( inputfd, &basefds );
	struct timeval oneSec;
//	oneSec.tv_sec = 1;
	oneSec.tv_usec = 100;

	unsigned char buffer[20];
	
	//Waiting betwwen the thread start and the first command sent
	while (cstNotReadyYet == [connState state]) {
		[NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]] ;
	}  
	NSInteger cStatus;
	BOOL timedOut = NO;
	//////////////////// Read DATA V2
	while ((cstReady != (cStatus = [connState state])) && 
		   (cstDataRetrieved != (cStatus = [connState state]))) {
		if (cstWaitingForAlarmsAndToBed == cStatus) {
			timedOut = NO;
			BOOL readData = NO;
			for (int i = 0; i < 20; ++i) buffer[i] = 0;
			while ((!readData) && (!timedOut)) {
				FD_COPY( &basefds, &readfds ) ;
				FD_COPY( &basefds, &errfds ) ;
				selectCount = select( inputfd+1, &readfds, NULL, &errfds, &oneSec) ;
				if ( selectCount > 0 ) {
					if ( FD_ISSET( inputfd, &errfds ) ) break ;		//  exit if error in stream
					if ( selectCount > 0 && FD_ISSET( inputfd, &readfds ) )
					{
						//  read into buffer, cnvert to NSString and send to the NSTextView.
						[ NSThread sleepUntilDate:[ NSDate dateWithTimeIntervalSinceNow:0.1 ] ] ;
						bytesRead = read(inputfd, buffer, 19) ;
						if ((bytesRead < 19) ||
							(0xC0 != buffer[0]) ||
							(0x04 != buffer[1]) ||
							(0x0E != buffer[2]) ||
							(0x00 != buffer[3]) ||
							(0xC0 != buffer[18])) // Here we expect the packet to always be of the same size
						{
							NSLog(@"The packet got as an answer to the Get To Bed command doesn't match the expected format");
							timedOut = YES;
						}
						else {
							readData = YES;
						}
					}
					else
					{
						timedOut = YES;
					}	
				}
				else {
					timedOut = YES;
				}
				
			}
			if ((!timedOut) && (readData))
			{
				[connState setState:cstDataRetrieved];
				RetrievedBuffer * rBuffer = [[RetrievedBuffer alloc] init];
				[rBuffer setBuffer:(unsigned char *)buffer length:19];
				[rBuffer setLength:19];
				[rBuffer setBufferKind:rbuToBedAndAlarm];
				[self processData:rBuffer];
				return(YES);
			}
		}
	}
	return (NO);
}


- (BOOL) readThreadDataV2
{
	fd_set readfds, basefds, errfds ;
	int selectCount, bytesRead;
	unsigned char * buffer = malloc(1024);
	unsigned char outBuffer[250];
	for (int i = 0; i < 250; ++i) outBuffer[i] = 0;
	int outBitsWritten= 0;
	int outBitsToWrite = 250;
	
	FD_ZERO( &basefds ) ;
	FD_SET( inputfd, &basefds );
	struct timeval oneSec;
	oneSec.tv_sec = 1;
	
	//Waiting betwwen the thread start and the first command sent
	while (cstNotReadyYet == [connState state]) {
		[NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]] ;
	}
	NSInteger cStatus;
	BOOL timedOut = NO;
	//////////////////// Read DATA V2
	while ((cstDataRetrieved != (cStatus = [connState state]) ) && (!timedOut)) {
		
		if (cstWaitingForDataV2 == cStatus) {
			timedOut = NO;
			while ((outBitsWritten < outBitsToWrite) && (!timedOut)) {
				if (FD_ISSET( inputfd + 1, &readfds ))
				{
					[ NSThread sleepUntilDate:[ NSDate dateWithTimeIntervalSinceNow:0.01 ] ] ;
					bytesRead = read( inputfd, buffer, 1024 ) ;
					if ((0 == buffer[0]) && (0xC0 == buffer[1]))
					{
						buffer = &(buffer[1]);
						-- bytesRead;
					}
					if ((0 == outBitsWritten) && (4 < bytesRead))
					{
						outBitsToWrite = buffer[2] + 0x100 * buffer[3] + 5;
					}						
					for(int i = 0; i < bytesRead; ++i)
					{
						outBuffer[outBitsWritten + i + outBitsWritten] = buffer[i];
					}
					outBitsWritten += bytesRead;
				}
				else {
					//NSInteger err = errno;
					
					timedOut = YES;
				}
				
			}
			if ((outBitsWritten < 11) ||
				(0xC0 != buffer[0]) ||
				(0x05 != buffer[1]) ||
				(0xC0 != buffer[outBitsWritten - 2])) /* We didn't read everything, thus the problem might come from a slow serial port communication
												  * 5 is for : Start token + Command + 2 Length bytes + End Token
												  */
			{
				NSLog(@"The packet got as an answer to the Get Data V2 command doesn't match the expected format");
			}
			
			if (!timedOut)
			{
				[connState setState:cstDataRetrieved];
				//				[ self performSelectorOnMainThread:@selector(processData:) withObject:toBedBuffer waitUntilDone:NO ] ;
				
				RetrievedBuffer * rBuffer = [[RetrievedBuffer alloc] init];
				[rBuffer setBuffer:(unsigned char *)outBuffer length:bytesRead];
				[rBuffer setLength:bytesRead];
				[rBuffer setBufferKind:rbuDataV2];
			
				[self processData:rBuffer];
			}
		}
	}
	free(buffer);
	return (YES);
}

@end
