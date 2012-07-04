//
//  TouchPathLayer.m
//  gesturedrawer
//
//  Created by Bill So on 7/4/12.
//  Copyright (c) 2012 Headnix. All rights reserved.
//

#import "TouchPathLayer.h"

@implementation TouchPathLayer
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
	
	// line with and stroke color
	CGColorRef theColor = CGColorCreateGenericRGB(0.0, 0.0, 1.0, 1.0);
	self.strokeColor = theColor;
	CGColorRelease(theColor);
	self.lineWidth = 24.0;
	self.lineCap = kCALineCapRound;
	
	_needFadeIn = YES;
	_pathKeyTimes = [[NSMutableArray alloc] initWithCapacity:10];
	_opacityKeyTimes = [[NSMutableArray alloc] initWithCapacity:10];
	_pathValues = [[NSMutableArray alloc] initWithCapacity:10];
	_opacityValues = [[NSMutableArray alloc] initWithCapacity:10];
	_previousLocation = NSMakePoint(-9999.0, -9999.0);

	return self;
}

- (void)addPoint:(CGPoint)aPoint {
	CGPathRef fixedPath = self.path;
	CGMutablePathRef thePath = nil;
	if ( fixedPath == nil ) {
		thePath = CGPathCreateMutable();
	} else {
		thePath = CGPathCreateMutableCopy(fixedPath);
	}
	CGPathAddLineToPoint(thePath, NULL, aPoint.x, aPoint.y);
	self.path =  thePath;
}

- (double)discrepancyWithPreviousLocation:(NSPoint)prevLoc {
	double xDist = _previousLocation.x - prevLoc.x;
	double yDist = _previousLocation.y - prevLoc.y;
	return sqrt((xDist * xDist) + (yDist * yDist));
}

@end
