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
	
	_pathKeyTimes = [[NSMutableArray alloc] initWithCapacity:10];
	_opacityKeyTimes = [[NSMutableArray alloc] initWithCapacity:10];
	_pathValues = [[NSMutableArray alloc] initWithCapacity:10];
	_opacityValues = [[NSMutableArray alloc] initWithCapacity:10];
	
	return self;
}

@end
