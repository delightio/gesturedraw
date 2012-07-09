//
//  TouchPathProxy.m
//  gesturedrawer
//
//  Created by Bill So on 7/10/12.
//  Copyright (c) 2012 Headnix. All rights reserved.
//

#import "TouchPathProxy.h"

@implementation TouchPathProxy
@synthesize pathKeyTimes = _pathKeyTimes;
@synthesize opacityKeyTimes = _opacityKeyTimes;
@synthesize pathStartSegmentIndexSet = _pathStartSegmentIndexSet;
@synthesize pathEndSegmentIndexSet = _pathEndSegmentIndexSet;
@synthesize pathValues = _pathValues;
@synthesize startTime = _startTime;
@synthesize previousLocation = _previousLocation;
@synthesize previousTime = _previousTime;
@synthesize currentSequence = _currentSequence;
@synthesize needFadeIn = _needFadeIn;

- (id)init {
	self = [super init];
	
	_needFadeIn = YES;
	_pathKeyTimes = [[NSMutableArray alloc] initWithCapacity:10];
	_opacityKeyTimes = [[NSMutableArray alloc] initWithCapacity:10];
	_pathValues = [[NSMutableArray alloc] initWithCapacity:10];
	_previousLocation = NSMakePoint(-9999.0, -9999.0);
	_pathStartSegmentIndexSet = [[NSMutableIndexSet alloc] init];
	_pathEndSegmentIndexSet = [[NSMutableIndexSet alloc] init];

	return self;
}

- (double)discrepancyWithPreviousLocation:(NSPoint)prevLoc {
	double xDist = _previousLocation.x - prevLoc.x;
	double yDist = _previousLocation.y - prevLoc.y;
	return sqrt((xDist * xDist) + (yDist * yDist));
}

@end
