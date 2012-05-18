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

- (id)init {
	self = [super init];
	
	[self setOpacity:0.0];
	
	NSImage * img = [NSImage imageNamed:@"dot"];
	self.contents = (id)img;
	self.bounds = CGRectMake(0.0, 0.0, img.size.width, img.size.height);

	_pathKeyTimes = [[NSMutableArray alloc] initWithCapacity:10];
	_opacityKeyTimes = [[NSMutableArray alloc] initWithCapacity:10];
	_pathValues = [[NSMutableArray alloc] initWithCapacity:10];
	_opacityValues = [[NSMutableArray alloc] initWithCapacity:10];
	[self setShouldRasterize:YES];
	
	return self;
}

@end
