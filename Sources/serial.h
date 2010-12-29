//
//  serial.h
//  SleepTrackerX
//
//  2010 tuxella after Serial Tools from Kok Chen
//
 
#include <IOKit/IOKitLib.h>
#include <IOKit/serial/IOSerialKeys.h>

int findPorts( CFStringRef *stream, CFStringRef *path, int maxDevice ) ;

