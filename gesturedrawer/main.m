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
#import "RenderingUnitV03.h"

int main(int argc, char * argv[])
{

	@autoreleasepool {
		NSString * vdoFilePath = nil;
		NSString * plistFilePath = nil;
		NSString * dstFilePath = nil;
		NSString * oriFilePath = nil;
		int c = 0;
	    while ( (c = getopt(argc, argv, "p:f:d:o")) != -1 ) {
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
				case 'o':
					if ( optarg ) {
						oriFilePath = [NSString stringWithCString:optarg encoding:NSUTF8StringEncoding];
					}
					break;
					
				default:
					break;
			}
		}
		if ( vdoFilePath == nil || plistFilePath == nil || dstFilePath == nil ) {
			// error running the command
			NSLog(@"usage: gesturedrawer -f movie_file -p plist_file -d destination_file -o orientation_file");
			return 0;
		}
		// check if file exists.
		NSFileManager * fm = [NSFileManager defaultManager];
		if ( [fm fileExistsAtPath:dstFilePath] ) {
			[fm removeItemAtPath:dstFilePath error:nil];
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
			RenderingUnitV03 * v3RndUnit = [[RenderingUnitV03 alloc] initWithVideoAtPath:vdoFilePath destinationPath:dstFilePath touchesPropertyList:touchInfo];
			NSData * propData = nil;
			if ( oriFilePath ) {
				propData = [NSData dataWithContentsOfFile:oriFilePath];
			}
			if ( propData ) {
				NSPropertyListFormat listFmt;
				NSError * err;
				NSDictionary * dict = [NSPropertyListSerialization propertyListWithData:propData options:0 format:&listFmt error:&err];
				[v3RndUnit checkMajorOrientationForTrack:[dict objectForKey:@"orientationChanges"]];
			}
			rndUnit = v3RndUnit;
		} else {
			NSLog(@"wrong plist file version, expect version 0.1 or 0.2");
			[NSApp terminate:nil];
		}
		NSConditionLock * cndLock = [[NSConditionLock alloc] initWithCondition:0];
		[rndUnit exportVideoWithCompletionHandler:^{
			[cndLock lock];
			[cndLock unlockWithCondition:100];
		} errorHandler:^{
			[cndLock lock];
			[cndLock unlockWithCondition:100];
		}];
		[cndLock lockWhenCondition:100];
		[cndLock unlock];
		return rndUnit.encountersExportError ? -1 : 0;
	}
    return 0;
}

