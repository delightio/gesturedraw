//
//  RenderingUnit.m
//  gesturedrawer
//
//  Created by Bill So on 5/22/12.
//  Copyright (c) 2012 Headnix. All rights reserved.
//

#import "TouchLayer.h"
#import "RenderingUnit.h"

NSString * DLTouchCurrentLocationKey = @"curLoc";
NSString * DLTouchPreviousLocationKey = @"prevLoc";
NSString * DLTouchSequenceNumKey = @"seq";
NSString * DLTouchPhaseKey = @"phase";
NSString * DLTouchTimeKey = @"time";
NSString * DLTouchTapCountKey = @"tapCount";
NSString * DLTouchPrivateKey = @"private";

@implementation RenderingUnit
@synthesize touchBounds;
@synthesize videoDuration;

- (id)initWithVideoAtPath:(NSString *)vdoPath destinationPath:(NSString *)dstPath touchesPropertyList:(NSDictionary *)tchPlist {
	self = [super init];
	onscreenLayerBuffer = [[NSMutableArray alloc] initWithCapacity:2];
	unassignedLayerBuffer = [[NSMutableArray alloc] initWithCapacity:2];
	sourceFilePath = vdoPath;
	destinationFilePath = dstPath;
	touches = [tchPlist objectForKey:@"touches"];
	touchBounds = NSRectFromString([tchPlist objectForKey:@"touchBounds"]);
	
	return self;
}

- (void)exportVideoWithCompletionHandler:(void (^)(void))handler {
}

- (TouchLayer *)layerWithPreviousLocation:(NSPoint)prevLoc {
	TouchLayer * shapeLayer = nil;
	if ( [onscreenLayerBuffer count] == 1 ) {
		shapeLayer = [onscreenLayerBuffer objectAtIndex:0];
	} else {
		double d = 0.0;
		double minDist = 9999.0;
		for (TouchLayer * theLayer in onscreenLayerBuffer) {
			d = [theLayer discrepancyWithPreviousLocation:prevLoc];
			if ( d < minDist ) {
				shapeLayer = theLayer;
				minDist = d;
			}
		}
	}
	return shapeLayer;
}

- (TouchLayer *)layerForTouch:(NSDictionary *)aTouchDict parentLayer:(CALayer *)pLayer {
	UITouchPhase ttype = [[aTouchDict objectForKey:DLTouchPhaseKey] integerValue];
	TouchLayer * shapeLayer = nil;//[touchIDLayerMapping objectForKey:aTouchID];
	switch (ttype) {
		case UITouchPhaseBegan:
			// create new touch
			shapeLayer = [unassignedLayerBuffer lastObject];
			if ( shapeLayer ) {
				[unassignedLayerBuffer removeObject:shapeLayer];
			} else {
				// create the layer
				shapeLayer = [TouchLayer layer];
				[pLayer addSublayer:shapeLayer];
			}
			[onscreenLayerBuffer addObject:shapeLayer];
			break;
			
		case UITouchPhaseEnded:
		case UITouchPhaseCancelled:
			// get layer from previous location
			shapeLayer = [self layerWithPreviousLocation:NSPointFromString([aTouchDict objectForKey:DLTouchPreviousLocationKey])];
			if ( shapeLayer ) {
				// this is the last touch of the touch sequence
				[unassignedLayerBuffer addObject:shapeLayer];
				[onscreenLayerBuffer removeObject:shapeLayer];
			}
			break;
			
		default:
			// get layer from previous location
			shapeLayer = [self layerWithPreviousLocation:NSPointFromString([aTouchDict objectForKey:DLTouchPreviousLocationKey])];
			break;
	}
	return shapeLayer;
}

- (void)setupGestureAnimationsForLayer:(CALayer *)parentLayer {
}

@end
