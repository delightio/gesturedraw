//
//  main.m
//  gesturedrawer
//
//  Created by Bill So on 5/11/12.
//  Copyright (c) 2012 Headnix. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

int main(int argc, char * argv[])
{

	@autoreleasepool {
		NSString * vdoFilePath = nil;
		NSString * plistFilePath = nil;
		int c = 0;
	    while ( (c = getopt(argc, argv, "p:f:")) != -1 ) {
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
					
				default:
					break;
			}
		}
		if ( vdoFilePath == nil || plistFilePath == nil ) {
			// error running the command
			NSLog(@"usage: gesturedrawer -f movie_file -p plist_file");
			return 0;
		}
		// start the processing pipeline
		
	}
    return 0;
}

