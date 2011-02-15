//
//  GUI.h
//  SleepTrackerX
//
//  2010 tuxella after Serial Tools from Kok Chen
//

#import <Cocoa/Cocoa.h>


typedef struct {
	NSString *p ;
	NSString *name ;
} NamePair ;

@interface GUI : NSObject {
	IBOutlet id window ;
	IBOutlet id tab ;
	
	//  terminal
	IBOutlet id terminal ;
	IBOutlet id connectButton ;

	IBOutlet id sendButton ;
	IBOutlet id saveSettingdButton;

	
	IBOutlet id progressIndicator ;
	
	
	IBOutlet NSTextField * userTextField;
	IBOutlet NSTextField * passTextField;
	
	NSLock *termioLock ;
	
	NSString *filename ;
	NSMutableDictionary *dictionary, *initialDictionary ;
	NSString *originalTerminalPort, *originalSnifferPortA, *originalSnifferPortB ;
	
	//  serial ports
	NSString *stream[32] ;
	NSString *path[32] ;
	
	Boolean unnamed ;
	Boolean terminalOpened, snifferOpened ;
	int displayBacklog ;
}

- (id)initWithUntitled:(NSString*)filename dictionary:(NSDictionary*)dict ;

- (int)findPorts ;

- (void)saveSettings:(id)sender;

- (Boolean)shouldTerminate ;

#define kGUIWindowPosition		@"GUI Position"
#define kTermWindowPosition		@"Term Position"
#define	kGUIDomain				@"w7ay.Serial Tools"
#define	kTerminalPort			@"Terminal Serial Port"
#define	kTerminalBaudRate		@"Terminal Baud Rate"
#define	kTerminalBits			@"Terminal Bits"
#define	kTerminalStopbits		@"Terminal Stop Bits"
#define	kTerminalParity			@"Terminal Parity"
#define	kTerminalCRLF			@"Terminal Send CRLF"
#define	kTerminalRaw			@"Terminal Raw"
#define	kTerminalRTS			@"Terminal RTS"
#define	kTerminalDTR			@"Terminal DTR"

#define	kSnifferPortA			@"Sniffer Port A"
#define	kSnifferPortB			@"Sniffer Port B"
#define	kSnifferBaudRate		@"Sniffer Baud Rate"
#define	kSnifferBits			@"Sniffer Bits"
#define	kSnifferStopbits		@"Sniffer Stop Bits"
#define	kSnifferParity			@"Sniffer Parity"
#define	kSnifferRaw				@"Sniffer Raw"
#define	kSnifferRTSa			@"Sniffer RTSa"
#define	kSnifferDTRa			@"Sniffer DTRa"
#define	kSnifferRTSb			@"Sniffer RTSb"
#define	kSnifferDTRb			@"Sniffer DTRb"
#define	kAutoRTS				@"Sniffer Auto RTS"

#define	kTool					@"GUI Tool"

@end
