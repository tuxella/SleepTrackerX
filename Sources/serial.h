//
//  serial.h
//  SleepTrackerX
//
//  2010 tuxella. GPL 3+
//
 
#include <IOKit/IOKitLib.h>
#include <IOKit/serial/IOSerialKeys.h>

int findPorts( CFStringRef *stream, CFStringRef *path, int maxDevice ) ;

