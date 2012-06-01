//
//  RectLayer.m
//  gesturedrawer
//
//  Created by Bill So on 5/31/12.
//  Copyright (c) 2012 Headnix. All rights reserved.
//

#import "RectLayer.h"

@implementation RectLayer
@synthesize opacityKeyTimes = _opacityKeyTimes;
@synthesize opacityValues = _opacityValues;
@synthesize startTime = _startTime;
@synthesize previousTime = _previousTime;
@synthesize currentSequence = _currentSequence;
@synthesize touchCount = _touchCount;
@synthesize needFadeIn = _needFadeIn;

- (id)init {
	self = [super init];
	
	CGColorRef blueColor = CGColorCreateGenericRGB(0.0, 0.0, 1.0, 1.0);
	[self setBackgroundColor:blueColor];
	[self setOpacity:0.0];
		
	_opacityKeyTimes = [[NSMutableArray alloc] initWithCapacity:10];
	_opacityValues = [[NSMutableArray alloc] initWithCapacity:10];
	_needFadeIn = YES;
	[self setShouldRasterize:YES];
	
	CGColorRelease(blueColor);
	
	return self;
}

@end
