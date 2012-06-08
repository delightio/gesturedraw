//
//  main.m
//  majororientation
//
//  Created by Bill So on 6/8/12.
//  Copyright (c) 2012 Headnix. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef enum {
    UIDeviceOrientationUnknown,
    UIDeviceOrientationPortrait,            // Device oriented vertically, home button on the bottom
    UIDeviceOrientationPortraitUpsideDown,  // Device oriented vertically, home button on the top
    UIDeviceOrientationLandscapeLeft,       // Device oriented horizontally, home button on the right
    UIDeviceOrientationLandscapeRight,      // Device oriented horizontally, home button on the left
    UIDeviceOrientationFaceUp,              // Device oriented flat, face up
    UIDeviceOrientationFaceDown             // Device oriented flat, face down
} UIDeviceOrientation;

typedef enum {
    UIInterfaceOrientationPortrait           = UIDeviceOrientationPortrait,
    UIInterfaceOrientationPortraitUpsideDown = UIDeviceOrientationPortraitUpsideDown,
    UIInterfaceOrientationLandscapeLeft      = UIDeviceOrientationLandscapeRight,
    UIInterfaceOrientationLandscapeRight     = UIDeviceOrientationLandscapeLeft
} UIInterfaceOrientation;

static NSString * DLDeviceOrientationKey = @"deviceOrientation";
static NSString * DLInterfaceOrientationKey = @"interfaceOrientation";
static NSString * DLOrientationTimeKey = @"time";

UIInterfaceOrientation checkMajorOrientationForTrack(NSArray * track, NSInteger vdoDuration) {
	NSUInteger c = [track count];
	NSDictionary * oriDict = nil;
	UIInterfaceOrientation majorOrientation;
	if ( c == 0 ) {
		// just use default portrait
		majorOrientation = UIInterfaceOrientationPortrait;
	} else if ( c == 1 ) {
		oriDict = [track lastObject];
		majorOrientation = [[oriDict objectForKey:DLInterfaceOrientationKey] integerValue];
	} else {
		NSDictionary * prevOriDict;
		// prepare the previous dictionary
		prevOriDict = [track objectAtIndex:0];
		NSMutableDictionary * timeDurationDict = [NSMutableDictionary dictionaryWithCapacity:4];
		NSNumber * oriNum, * accuTimeNum;
		NSTimeInterval timeVal;
		for (NSInteger i = 1; i < c; i++) {
			oriDict = [track objectAtIndex:i];
			oriNum = [prevOriDict objectForKey:DLInterfaceOrientationKey];
			// time interval since last change
			timeVal = [[oriDict objectForKey:DLOrientationTimeKey] doubleValue] - [[prevOriDict objectForKey:DLOrientationTimeKey] doubleValue];
			// accumulate time duration inbetween change
			accuTimeNum = [timeDurationDict objectForKey:oriNum];
			if ( accuTimeNum ) {
				accuTimeNum = [NSNumber numberWithDouble:[accuTimeNum doubleValue] + timeVal];
			} else {
				accuTimeNum = [NSNumber numberWithDouble:timeVal];
			}
			[timeDurationDict setObject:accuTimeNum forKey:oriNum];
			prevOriDict = oriDict;
		}
		// calculate the duration of the last instance
		oriNum = [prevOriDict objectForKey:DLInterfaceOrientationKey];
		// time interval since last change
		timeVal = (double)vdoDuration - [[prevOriDict objectForKey:DLOrientationTimeKey] doubleValue];
		// accumulate time duration inbetween change
		accuTimeNum = [timeDurationDict objectForKey:oriNum];
		if ( accuTimeNum ) {
			accuTimeNum = [NSNumber numberWithDouble:[accuTimeNum doubleValue] + timeVal];
		} else {
			accuTimeNum = [NSNumber numberWithDouble:timeVal];
		}
		[timeDurationDict setObject:accuTimeNum forKey:oriNum];

		// look for the major orientation
		timeVal = -9999.0;
		NSTimeInterval curVal;
		NSNumber * curMajorOriNum;
		for (oriNum in timeDurationDict) {
			curVal = [[timeDurationDict objectForKey:oriNum] doubleValue];
			if ( curVal > timeVal ) {
				// this is the current max
				curMajorOriNum = oriNum;
			}
		}
		// this is the major orientation
		majorOrientation = [oriNum integerValue];
	}
	return majorOrientation;
}

int main(int argc, char * argv[])
{
	int c = 0;
	@autoreleasepool {
		NSString * oriFilePath = nil;
		NSInteger vdoDur = 0;
	    while ( (c = getopt(argc, argv, "f:d:")) != -1 ) {
			switch (c) {
				case 'f':
					if ( optarg ) {
						oriFilePath = [NSString stringWithCString:optarg encoding:NSUTF8StringEncoding];
					}
					break;
				case 'd':
					if ( optarg ) {
						vdoDur = [[NSString stringWithCString:optarg encoding:NSUTF8StringEncoding] integerValue];
					}
					break;
				default:
					break;
			}
		}
		if ( oriFilePath == nil  ) {
			// error running the command
			NSLog(@"usage: gesturedrawer -f orientation_plist_file\nIt returns 0, 90, 180, 270 as angle to rotate");
			return -1;
		}
		// start the processing pipeline
		// read the orientation
		NSPropertyListFormat listFmt = 0;
		NSError * err = nil;
		NSData * propData = nil;
		c = 0;
		if ( oriFilePath ) {
			propData = [NSData dataWithContentsOfFile:oriFilePath];
		}
		if ( propData ) {
			NSDictionary * dict = [NSPropertyListSerialization propertyListWithData:propData options:0 format:&listFmt error:&err];
			UIInterfaceOrientation o = checkMajorOrientationForTrack([dict objectForKey:@"orientationChanges"], vdoDur);
			switch (o) {
				case UIInterfaceOrientationPortrait:
					c = 0;
					break;
				case UIInterfaceOrientationPortraitUpsideDown:
					c = 180;
					break;
				case UIInterfaceOrientationLandscapeLeft:
					c = 90;
					break;
				case UIInterfaceOrientationLandscapeRight:
					c = 270;
					break;
				default:
					c = 0;
					break;
			}
		}
	}
    return c;
}

