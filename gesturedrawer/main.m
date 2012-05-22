//
//  main.m
//  gesturedrawer
//
//  Created by Bill So on 5/11/12.
//  Copyright (c) 2012 Headnix. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import "RenderingUnit.h"

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
			NSLog(@"usage: gesturedrawer -f movie_file -p plist_file -d destination_directory");
			return 0;
		}
		// start the processing pipeline
		RenderingUnit * rndUnit = [[RenderingUnit alloc] initWithVideoAtPath:vdoFilePath touchesPListPath:plistFilePath destinationPath:dstFilePath];
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

