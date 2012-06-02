//
//  main.m
//  gesturedrawer
//
//  Created by Bill So on 5/11/12.
//  Copyright (c) 2012 Headnix. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import "RenderingUnitV01.h"
#import "RenderingUnitV02.h"

int main(int argc, char * argv[])
{

	@autoreleasepool {
		NSString * vdoFilePath = nil;
		NSString * plistFilePath = nil;
		NSString * dstFilePath = nil;
		int c = 0;
	    while ( (c = getopt(argc, argv, "p:f:d:")) != -1 ) {
			switch (c) {
				case 'f':
					if ( optarg ) {
						vdoFilePath = [NSString stringWithCString:optarg encoding:NSUTF8StringEncoding];
					}
					break;
				case 'p':
					if ( optarg ) {
						plistFilePath = [NSString stringWithCString:optarg encoding:NSUTF8StringEncoding];
					}
					break;
				case 'd':
					if ( optarg ) {
						dstFilePath = [NSString stringWithCString:optarg encoding:NSUTF8StringEncoding];
					}
					break;
					
				default:
					break;
			}
		}
		if ( vdoFilePath == nil || plistFilePath == nil || dstFilePath == nil ) {
			// error running the command
			NSLog(@"usage: gesturedrawer -f movie_file -p plist_file -d destination_file");
			return 0;
		}
		// start the processing pipeline
		// read the touches
		NSData * propData = [NSData dataWithContentsOfFile:plistFilePath];
		NSPropertyListFormat listFmt = 0;
		NSError * err = nil;
		NSDictionary * touchInfo = [NSPropertyListSerialization propertyListWithData:propData options:0 format:&listFmt error:&err];
		NSString * fmtVersion = [touchInfo objectForKey:@"formatVersion"];
		if ( fmtVersion == nil ) {
			NSLog(@"no version number in plist file");
			[NSApp terminate:nil];
		}
		RenderingUnit * rndUnit = nil;
		if ( [fmtVersion isEqualToString:@"0.1"] ) {
			rndUnit = [[RenderingUnitV01 alloc] initWithVideoAtPath:vdoFilePath destinationPath:dstFilePath touchesPropertyList:touchInfo];
		} else if ( [fmtVersion isEqualToString:@"0.2"] ) {
			rndUnit = [[RenderingUnitV02 alloc] initWithVideoAtPath:vdoFilePath destinationPath:dstFilePath touchesPropertyList:touchInfo];
		} else {
			NSLog(@"wrong plist file version, expect version 0.1 or 0.2");
			[NSApp terminate:nil];
		}
		NSConditionLock * cndLock = [[NSConditionLock alloc] initWithCondition:0];
		[rndUnit exportVideoWithCompletionHandler:^{
			[cndLock lock];
			[cndLock unlockWithCondition:100];
		}];
		[cndLock lockWhenCondition:100];
		[cndLock unlock];
	}
    return 0;
}

