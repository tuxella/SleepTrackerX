//
//  ApplicationDelegate.h
//  SleepTrackerX
//
//  2010 tuxella after Serial Tools from Kok Chen
//


#if __OBJC__
#import <Cocoa/Cocoa.h>
#endif
#import "GUI.h"
#import <CoreFoundation/CFRunLoop.h>


@interface ApplicationDelegate : NSObject {
	IBOutlet id recentMenu ;
	NSString *plistPath ;
	NSMutableArray *guis, *recentGUIs ;
	NSMutableArray *recentFiles ;
	int uniqueCount ;
	GUI *activeGUI ;
	
	IONotificationPortRef notifyPort ;
	CFRunLoopSourceRef runLoopSource ;
	io_iterator_t addIterator, removeIterator ;
	
	Boolean openedFromFile ;
}

- (IBAction)newSession:(id)sender ;

- (void)startNotification ;

- (void)guiBecameActive:(GUI*)which ;
- (void)guiClosing:(GUI*)which ;


#define kPlistDirectory		@"~/Library/Preferences/"
#define	kRecentFiles		@"Serial Tools Recent Files"

@end
