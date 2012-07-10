//
//  TouchPathLayer.m
//  gesturedrawer
//
//  Created by Bill So on 7/10/12.
//  Copyright (c) 2012 Headnix. All rights reserved.
//

#import "TouchPathLayer.h"
#import "LineRectLayer.h"

@implementation TouchPathLayer

- (void)addPoint:(CGPoint)aPoint phase:(UITouchPhase)thePhase {
	switch (thePhase) {
		case UITouchPhaseBegan:
			// add the first point
			break;
			
		case UITouchPhaseEnded:
			break;
			
		default:
			// just add a normal point
			break;
	}
}

@end
