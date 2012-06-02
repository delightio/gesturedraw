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
NSString * DLTouchPrivateFrameKey = @"privateFrame";

@implementation RenderingUnit
@synthesize parentLayer;
@synthesize touchBounds;
@synthesize videoDuration;

- (id)initWithVideoAtPath:(NSString *)vdoPath destinationPath:(NSString *)dstPath touchesPropertyList:(NSDictionary *)tchPlist {
	self = [super init];
	onscreenDotLayerBuffer = [[NSMutableArray alloc] initWithCapacity:2];
	unassignedDotLayerBuffer = [[NSMutableArray alloc] initWithCapacity:2];
	sourceFilePath = vdoPath;
	destinationFilePath = dstPath;
	touches = [tchPlist objectForKey:@"touches"];
	touchBounds = NSRectFromString([tchPlist objectForKey:@"touchBounds"]);
	
	return self;
}

- (void)exportVideoWithCompletionHandler:(void (^)(void))handler {
}

- (TouchLayer *)layerWithPreviousLocation:(NSPoint)prevLoc forSequence:(NSInteger)seqNum {
	TouchLayer * shapeLayer = nil;
	if ( [onscreenDotLayerBuffer count] == 1 ) {
		shapeLayer = [onscreenDotLayerBuffer objectAtIndex:0];
	} else {
		double d = 0.0;
		double minDist = 9999.0;
		for (TouchLayer * theLayer in onscreenDotLayerBuffer) {
			if ( theLayer.currentSequence != seqNum ) {
				// try to do the comparison only when the sequence number of the layer is not the same as the requested one. If they are the same, the layer has been compared and matached another points already.
				d = [theLayer discrepancyWithPreviousLocation:prevLoc];
				if ( d < minDist ) {
					shapeLayer = theLayer;
					minDist = d;
				}
			}
		}
	}
	shapeLayer.currentSequence = seqNum;
	return shapeLayer;
}

- (TouchLayer *)layerForTouch:(NSDictionary *)aTouchDict parentLayer:(CALayer *)pLayer {
	UITouchPhase ttype = [[aTouchDict objectForKey:DLTouchPhaseKey] integerValue];
	TouchLayer * shapeLayer = nil;//[touchIDLayerMapping objectForKey:aTouchID];
	switch (ttype) {
		case UITouchPhaseBegan:
			// create new touch
			shapeLayer = [unassignedDotLayerBuffer lastObject];
			if ( shapeLayer ) {
				[unassignedDotLayerBuffer removeObject:shapeLayer];
//				shapeLayer.privateMode = NO;
			} else {
				// create the layer
				shapeLayer = [TouchLayer layer];
				[pLayer addSublayer:shapeLayer];
			}
			[onscreenDotLayerBuffer addObject:shapeLayer];
			break;
			
		case UITouchPhaseEnded:
		case UITouchPhaseCancelled:
			// get layer from previous location
			shapeLayer = [self layerWithPreviousLocation:NSPointFromString([aTouchDict objectForKey:DLTouchPreviousLocationKey]) forSequence:[[aTouchDict objectForKey:DLTouchSequenceNumKey] integerValue]];
			if ( shapeLayer ) {
				// this is the last touch of the touch sequence
				[unassignedDotLayerBuffer addObject:shapeLayer];
				[onscreenDotLayerBuffer removeObject:shapeLayer];
			}
			break;
			
		default:
			// get layer from previous location
			shapeLayer = [self layerWithPreviousLocation:NSPointFromString([aTouchDict objectForKey:DLTouchPreviousLocationKey]) forSequence:[[aTouchDict objectForKey:DLTouchSequenceNumKey] integerValue]];
			if ( shapeLayer == nil ) {
				// grab whatever layer available
				// create new touch
				shapeLayer = [unassignedDotLayerBuffer lastObject];
				if ( shapeLayer ) {
					[unassignedDotLayerBuffer removeObject:shapeLayer];
					//				shapeLayer.privateMode = NO;
				} else {
					// create the layer
					shapeLayer = [TouchLayer layer];
					[pLayer addSublayer:shapeLayer];
				}
				[onscreenDotLayerBuffer addObject:shapeLayer];
			}
			break;
	}
	return shapeLayer;
}

- (void)setupGestureAnimationsForLayer:(CALayer *)prnLayer {
}

@end
