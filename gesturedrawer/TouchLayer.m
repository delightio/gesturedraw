//
//  TouchLayer.m
//  gesturedrawer
//
//  Created by Bill So on 5/17/12.
//  Copyright (c) 2012 Headnix. All rights reserved.
//

#import "TouchLayer.h"

@implementation TouchLayer
@synthesize pathKeyTimes = _pathKeyTimes;
@synthesize opacityKeyTimes = _opacityKeyTimes;
@synthesize pathValues = _pathValues;
@synthesize opacityValues = _opacityValues;
@synthesize startTime = _startTime;
@synthesize previousLocation = _previousLocation;
@synthesize previousTime = _previousTime;
@synthesize currentSequence = _currentSequence;
@synthesize needFadeIn = _needFadeIn;

- (id)init {
	self = [super init];
	
	[self setOpacity:0.0];
	
	NSImage * img = [NSImage imageNamed:@"dot"];
	if ( img == nil ) {
		// try opening the dot file from library folder
		NSURL * baseURL = [[[NSFileManager defaultManager] URLsForDirectory:NSApplicationSupportDirectory inDomains:NSLocalDomainMask] objectAtIndex:0];
		NSURL * imgURL = [baseURL URLByAppendingPathComponent:@"gesturedrawer/dot.png"];
		img = [[NSImage alloc] initWithContentsOfURL:imgURL];
		if ( img == nil ) {
			NSLog(@"Can't load image file at %@\nExport aborted", imgURL);
			exit(-1);
		}
	}
	_needFadeIn = YES;
	self.contents = (id)img;
	self.bounds = CGRectMake(0.0, 0.0, img.size.width, img.size.height);

	_pathKeyTimes = [[NSMutableArray alloc] initWithCapacity:10];
	_opacityKeyTimes = [[NSMutableArray alloc] initWithCapacity:10];
	_pathValues = [[NSMutableArray alloc] initWithCapacity:10];
	_opacityValues = [[NSMutableArray alloc] initWithCapacity:10];
	_previousLocation = NSMakePoint(-9999.0, -9999.0);
	[self setShouldRasterize:YES];
	
	return self;
}

- (double)discrepancyWithPreviousLocation:(NSPoint)prevLoc {
	double xDist = _previousLocation.x - prevLoc.x;
	double yDist = _previousLocation.y - prevLoc.y;
	return sqrt((xDist * xDist) + (yDist * yDist));
}

@end
