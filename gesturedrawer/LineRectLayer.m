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
	theLayer.anchorPoint = CGPointMake(0.0, 0.5);
	
	return theLayer;
}

- (id)init {
	self = [super init];
	
	CGColorRef theColor = CGColorCreateGenericRGB(0.0, 0.0, 1.0, 1.0);
	self.backgroundColor = theColor;
	CGColorRelease(theColor);
	
	self.cornerRadius = 7.0;
	self.bounds = CGRectMake(0.0, 0.0, 0.0, 14.0);
	
	return self;
}

- (CGRect)getBoundsAndSetTransformationToPoint:(CGPoint)aPoint {
	CGRect theBounds = self.bounds;
	// set rotation
	CGPoint curPosition = self.position;
	CGPoint abVec = CGPointMake(aPoint.x - curPosition.x, aPoint.y - curPosition.y);
	// flip the vector about x-axis (reason: the coordinates are flipped)
	abVec.y = -abVec.y;
	double rotationAng = 0.0;
	// check the quadrant to set rotation angle
	if ( abVec.x == 0.0 ) {
		rotationAng = abVec.y > 0.0 ? -M_PI_2 : M_PI_2;
	} else if ( abVec.y == 0.0 ) {
		rotationAng = abVec.x > 0.0 ? 0.0 : M_PI;
	} else if ( abVec.x > 0.0 && abVec.y > 0.0 ) {
		// first quadrant
		rotationAng = -atan(abVec.y / abVec.x);
	} else if ( abVec.x < 0.0 && abVec.y > 0.0 ) {
		// 2nd quadrant
		rotationAng = -(M_PI + atan(abVec.y / abVec.x));
	} else if ( abVec.x < 0.0 && abVec.y < 0.0 ) {
		// 3rd quadrant
		rotationAng = (M_PI - atan(abVec.y / abVec.x));
	} else {
		// 4th quadrant
		rotationAng = atan(abVec.y / abVec.x);
	}
//	if ( abVec.x == 0.0 ) {
//		rotationAng = abVec.y > 0.0 ? M_PI_2 : 0.0;
//	} else {
//		rotationAng = atan(abVec.y / abVec.x);
//	}
	self.transform = CATransform3DTranslate(CATransform3DMakeRotation(rotationAng, 0.0, 0.0, 1.0), -7.0, 0.0, 0.0);
//	self.transform = CATransform3DMakeRotation(rotationAng, 0.0, 0.0, 1.0);
	theBounds.size.width = sqrt( abVec.x * abVec.x + abVec.y * abVec.y );
	return theBounds;
}

@end
