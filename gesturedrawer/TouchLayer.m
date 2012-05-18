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
	
	CGPathRef cirPath = CGPathCreateWithEllipseInRect(CGRectMake(0.0, 0.0, 22.0, 22.0), NULL);
	[self setLineWidth:0.0];
	[self setOpacity:0.0];
	CGColorRef redColor = CGColorCreateGenericRGB(1.0, 0.0, 0.0, 1.0);
	[self setFillColor:redColor];
	CGColorRelease(redColor);
	
	[self setPath:cirPath];
	CGPathRelease(cirPath);
//	NSImage * img = [NSImage imageNamed:@"dot"];
//	self.contents = (id)img;
//	self.bounds = CGRectMake(0.0, 0.0, img.size.width, img.size.height);

	_pathKeyTimes = [[NSMutableArray alloc] initWithCapacity:10];
	_opacityKeyTimes = [[NSMutableArray alloc] initWithCapacity:10];
	_pathValues = [[NSMutableArray alloc] initWithCapacity:10];
	_opacityValues = [[NSMutableArray alloc] initWithCapacity:10];
	[self setShouldRasterize:YES];
	
	return self;
}

@end
