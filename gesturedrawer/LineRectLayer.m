//
//  LineRectLayer.m
//  gesturedrawer
//
//  Created by Bill So on 7/10/12.
//  Copyright (c) 2012 Headnix. All rights reserved.
//

#import "LineRectLayer.h"

@implementation LineRectLayer

+ (id)layerAtPosition:(CGPoint)aPoint {
	LineRectLayer * theLayer = [[LineRectLayer alloc] init];
	
	theLayer.position = aPoint;
	theLayer.anchorPoint = aPoint;
	
	return theLayer;
}

- (id)init {
	self = [super init];
	
	CGColorRef theColor = CGColorCreateGenericRGB(0.0, 0.0, 1.0, 1.0);
	self.backgroundColor = theColor;
	CGColorRelease(theColor);
	
	self.cornerRadius = 7.0;
	self.bounds = CGRectMake(0.0, 0.0, 14.0, 14.0);
	
	return self;
}

@end
