//
//  serial.c
//  SleepTrackerX
//
//  2010 tuxella after Serial Tools from Kok Chen
//
 
#include "serial.h"

//  Find list of ports and their /dev paths 
//  NOTE: client is responsible for releasing the CFStrings.
int findPorts( CFStringRef *stream, CFStringRef *path, int maxDevice )
{
    kern_return_t kernResult ; 
    mach_port_t masterPort ;
	io_iterator_t serialPortIterator ;
	io_object_t modemService ;
    CFMutableDictionaryRef classesToMatch ;
	CFStringRef cfString ;
	int count ;

    kernResult = IOMasterPort( MACH_PORT_NULL, &masterPort ) ;
    if ( kernResult != KERN_SUCCESS ) return 0 ;
	
    classesToMatch = IOServiceMatching( kIOSerialBSDServiceValue ) ;
    if ( classesToMatch == NULL ) return 0 ;

	// get iterator for serial ports (including modems)
	// CFDictionarySetValue( classesToMatch, CFSTR(kIOSerialBSDTypeKey), CFSTR(kIOSerialBSDRS232Type) ) ;	-- use this if modems are not included
	
	CFDictionarySetValue( classesToMatch, CFSTR(kIOSerialBSDTypeKey), CFSTR(kIOSerialBSDAllTypes) ) ;
    //kernResult = IOServiceGetMatchingServices( masterPort, classesToMatch, &serialPortIterator ) ;    
    IOServiceGetMatchingServices( masterPort, classesToMatch, &serialPortIterator ) ;    
	// walk through the iterator
	count = 0 ;
	while ( ( modemService = IOIteratorNext( serialPortIterator ) ) ) {
		if ( count >= maxDevice ) break ;
        cfString = IORegistryEntryCreateCFProperty( modemService, CFSTR(kIOTTYDeviceKey), kCFAllocatorDefault, 0 ) ;
        if ( cfString ) {
			stream[count] = cfString ;
			cfString = IORegistryEntryCreateCFProperty( modemService, CFSTR(kIOCalloutDeviceKey), kCFAllocatorDefault, 0 ) ;
			if ( cfString )  {
				path[count] = cfString ;
				count++ ;
			}
		}
        IOObjectRelease( modemService ) ;
    }
	IOObjectRelease( serialPortIterator ) ;
	return count ;
}
