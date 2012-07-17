//
//  RenderingUnitV03.m
//  gesturedrawer
//
//  Created by Bill So on 5/29/12.
//  Copyright (c) 2012 Headnix. All rights reserved.
//

#import "TouchPathProxy.h"
#import "RectLayer.h"
#import "RenderingUnitV03.h"
#import "LineRectLayer.h"
#import "TouchLayer.h"

#define DL_MINIMUM_DURATION 0.15
#define DL_NORMAL_OPACITY_ANIMATION_DURATION 0.1
#define DL_TOUCH_POINT_TYPE		1000
#define DL_TOUCH_RECT_TYPE		1001

NS_INLINE CGPoint MidPointForCGRect(CGRect cgrect) {
	return CGPointMake((cgrect.origin.x + cgrect.size.width) / 2.0, (cgrect.origin.y + cgrect.size.height) / 2.0);
}

NS_INLINE double DistanceBetween(CGPoint pointA, CGPoint pointB) {
	double xDist = pointA.x - pointB.x;
	double yDist = pointA.y - pointB.y;
	return sqrt((xDist * xDist) + (yDist * yDist));
}

@implementation RenderingUnitV03

- (id)initWithVideoAtPath:(NSString *)vdoPath destinationPath:(NSString *)dstPath touchesPropertyList:(NSDictionary *)tchPlist {
	self = [super initWithVideoAtPath:vdoPath destinationPath:dstPath touchesPropertyList:tchPlist];
	rectLayerBuffer = [[NSMutableArray alloc] initWithCapacity:2];
	dotPositionBuffer = [[NSMutableArray alloc] initWithCapacity:2];
	return self;
}

- (void)exportVideoWithCompletionHandler:(void (^)(void))handler errorHandler:(void (^)(void))errHdlr {
	AVAsset * srcVdoAsset = [AVAsset assetWithURL:[NSURL fileURLWithPath:sourceFilePath]];
	if ( !srcVdoAsset.readable ) {
		// throw an exception? quit the app?
		self.encountersExportError = YES;
		NSLog(@"Error: file not readable: %@", sourceFilePath);
		errHdlr();
		return;
	}
	videoDuration = CMTimeGetSeconds(srcVdoAsset.duration);
    AVAssetTrack * originalTrack = [[srcVdoAsset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0];
	videoDuration = CMTimeGetSeconds(srcVdoAsset.duration);
	// create composition from source
	AVMutableComposition * srcComposition = [AVMutableComposition composition];
	AVMutableCompositionTrack * theTrack = [srcComposition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:10];
	[theTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, srcVdoAsset.duration) ofTrack:originalTrack atTime:kCMTimeZero error:nil];
	CGSize vdoSize = srcComposition.naturalSize;
	
	// build "pass through video track"
	AVMutableVideoComposition * videoComposition = [AVMutableVideoComposition videoComposition];
	AVMutableVideoCompositionInstruction *passThroughInstruction = [AVMutableVideoCompositionInstruction videoCompositionInstruction];
	passThroughInstruction.timeRange = CMTimeRangeMake(kCMTimeZero, [srcComposition duration]);
	
	//	[self setOrientationTransformForLayer:parentLayer];
	// set transform instruction
	AVAssetTrack *videoTrack = [[srcComposition tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0];
	
	AVMutableVideoCompositionLayerInstruction *passThroughLayerInstruction = [AVMutableVideoCompositionLayerInstruction videoCompositionLayerInstructionWithAssetTrack:videoTrack];
    if (CGAffineTransformEqualToTransform(originalTrack.preferredTransform, CGAffineTransformMakeScale(1, -1))) {
        // Original video was flipped vertically. Flip the new video vertically as well.
        // Can't just pass the original transform along since the instruction requires translation to be set.
        [passThroughLayerInstruction setTransform:CGAffineTransformMake(1, 0, 0, -1, 0, vdoSize.height) atTime:kCMTimeZero];
    }
	passThroughInstruction.layerInstructions = [NSArray arrayWithObject:passThroughLayerInstruction];
	videoComposition.instructions = [NSArray arrayWithObject:passThroughInstruction];
	
	// prepare animation
	CALayer * videoLayer = [CALayer layer];
	CALayer * parentLayer = [CALayer layer];
	CALayer * gestureLayer = [CALayer layer];
	[parentLayer addSublayer:videoLayer];
	[parentLayer addSublayer:gestureLayer];
	
	[gestureLayer setGeometryFlipped:YES];
	gestureLayer.sublayerTransform = CATransform3DScale(CATransform3DIdentity, vdoSize.width / touchBounds.size.width, vdoSize.height / touchBounds.size.height, 1.0);
	gestureLayer.anchorPoint = CGPointZero;
	CGRect theRect = CGRectMake(0.0, 0.0, vdoSize.width, vdoSize.height);
	videoLayer.frame = theRect;
	parentLayer.frame = theRect;
	gestureLayer.frame = theRect;
	
	// create animation
	[self setupGestureAnimationsForLayer:gestureLayer];
	//	[_playbackView.layer addSublayer:parentLayer];
	videoComposition.animationTool = [AVVideoCompositionCoreAnimationTool videoCompositionCoreAnimationToolWithPostProcessingAsVideoLayer:videoLayer inLayer:parentLayer];
	videoComposition.frameDuration = CMTimeMake(1, 30);
	videoComposition.renderSize = vdoSize;
	
	session = [[AVAssetExportSession alloc] initWithAsset:srcComposition presetName:AVAssetExportPreset640x480];
	session.shouldOptimizeForNetworkUse = YES;
	session.videoComposition = videoComposition;
	session.outputURL = [NSURL fileURLWithPath:destinationFilePath];
	session.outputFileType = AVFileTypeQuickTimeMovie;
	
	NSLog(@"Begin export video to path: %@", destinationFilePath);
	
	[session exportAsynchronouslyWithCompletionHandler:^{
		NSLog(@"Video exported - %@ %@", destinationFilePath, session.status == AVAssetExportSessionStatusFailed ? session.error : @"no error");
		handler();
	}];
}

- (double)distanceOfPoint:(NSPoint)aPoint toRect:(NSRect)aRect {
	NSPoint rectMidPoint = NSMakePoint(aRect.origin.x + aRect.size.width / 2.0, aRect.origin.y + aRect.size.height / 2.0);
	double xDist = aPoint.x - rectMidPoint.x;
	double yDist = aPoint.y - rectMidPoint.y;
	return sqrt((xDist * xDist) + (yDist * yDist));
}

- (NSInteger)numberOfInFlightDotLayer {
	NSInteger c = 0;
	for (TouchPathProxy * theLayer in dotPositionBuffer) {
		if ( theLayer.needFadeIn == NO ) {
			// in-flight layer
			c++;
		}
	}
	return c;
}

- (void)showRectLayerForTouch:(NSDictionary *)touchDict {
	RectLayer * shapeLayer = nil;
	CGRect tFrame = NSRectToCGRect(NSRectFromString([touchDict objectForKey:DLTouchPrivateFrameKey]));
	// get the rect layer of the right size
	if ( [rectLayerBuffer count] ) {
		for (shapeLayer in rectLayerBuffer) {
			if ( CGRectEqualToRect(shapeLayer.frame, tFrame) ) {
				break;
			}
		}
	}
	if ( shapeLayer == nil ) {
		// we can't find any, create one
		shapeLayer = [RectLayer layer];
		[rectLayerBuffer addObject:shapeLayer];
		// set the frame
		shapeLayer.frame = tFrame;
		[self.parentLayer addSublayer:shapeLayer];
	}
	NSNumber * fadeTimeNum;
	NSNumber * zeroNum = (NSNumber *)kCFBooleanFalse;
	NSNumber * oneNum = (NSNumber *)kCFBooleanTrue;
	NSTimeInterval curTimeItval = [[touchDict objectForKey:DLTouchTimeKey] doubleValue];
	NSNumber * touchTime = [NSNumber numberWithDouble:curTimeItval / videoDuration];
	// set layer animation
	shapeLayer.touchCount = shapeLayer.touchCount + 1;
	shapeLayer.previousTime = curTimeItval;
	if ( shapeLayer.touchCount == 1 ) {
		// fade it in
		shapeLayer.startTime = curTimeItval;
		// fade in effect
		// effect start time
		fadeTimeNum = [NSNumber numberWithDouble:(curTimeItval - DL_NORMAL_OPACITY_ANIMATION_DURATION) / videoDuration];
		[shapeLayer.opacityKeyTimes addObject:fadeTimeNum];
		// effect end time
		[shapeLayer.opacityKeyTimes addObject:touchTime];
		[shapeLayer.opacityValues addObject:zeroNum];		// start value
		[shapeLayer.opacityValues addObject:oneNum];		// end value
		// make sure the dot is "in" the location when animation starts
	}
}

- (void)hideRectLayerForTouch:(NSDictionary *)touchDict {
	RectLayer * shapeLayer = nil;
	CGRect tFrame = NSRectToCGRect(NSRectFromString([touchDict objectForKey:DLTouchPrivateFrameKey]));
	// get the rect layer of the right size
	if ( [rectLayerBuffer count] ) {
		for (shapeLayer in rectLayerBuffer) {
			if ( CGRectEqualToRect(shapeLayer.frame, tFrame) ) {
				break;
			}
		}
	}
	if ( shapeLayer == nil ) {
		// we can't find any, create one
		shapeLayer = [RectLayer layer];
		[rectLayerBuffer addObject:shapeLayer];
		// set the frame
		shapeLayer.frame = tFrame;
		[self.parentLayer addSublayer:shapeLayer];
	}
	NSNumber * fadeTimeNum;
	NSNumber * zeroNum = (NSNumber *)kCFBooleanFalse;
	NSNumber * oneNum = (NSNumber *)kCFBooleanTrue;
	NSTimeInterval curTimeItval = [[touchDict objectForKey:DLTouchTimeKey] doubleValue];
	NSNumber * touchTime = [NSNumber numberWithDouble:curTimeItval / videoDuration];
	// set layer animation
	shapeLayer.touchCount = shapeLayer.touchCount - 1;
	shapeLayer.previousTime = curTimeItval;
	shapeLayer.currentSequence = [[touchDict objectForKey:DLTouchSequenceNumKey] integerValue];
	if ( shapeLayer.touchCount == 0 ) {
		// calculate minimum time
		if ( curTimeItval - shapeLayer.startTime < DL_NORMAL_OPACITY_ANIMATION_DURATION ) {
			// we need to show the dot for longer time so that it's visually visible
			curTimeItval = shapeLayer.startTime + DL_NORMAL_OPACITY_ANIMATION_DURATION;
			touchTime = [NSNumber numberWithDouble:curTimeItval / videoDuration];
		}
		// fade out effect
		// effect start time
		[shapeLayer.opacityKeyTimes addObject:touchTime];
		// effect end time
		fadeTimeNum = [NSNumber numberWithDouble:(curTimeItval + DL_NORMAL_OPACITY_ANIMATION_DURATION) / videoDuration];
		[shapeLayer.opacityKeyTimes addObject:fadeTimeNum];
		[shapeLayer.opacityValues addObject:oneNum];		// start value
		[shapeLayer.opacityValues addObject:zeroNum];		// end value
		shapeLayer.needFadeIn = YES;
	}
}

- (void)hideRectLayer:(RectLayer *)shapeLayer {
	NSNumber * fadeTimeNum;
	NSNumber * zeroNum = (NSNumber *)kCFBooleanFalse;
	NSNumber * oneNum = (NSNumber *)kCFBooleanTrue;
	NSTimeInterval curTimeItval = shapeLayer.previousTime;
	NSNumber * touchTime = [NSNumber numberWithDouble:curTimeItval / videoDuration];
	// set layer animation
	shapeLayer.touchCount = 0;
	if ( curTimeItval - shapeLayer.startTime < DL_NORMAL_OPACITY_ANIMATION_DURATION ) {
		// we need to show the dot for longer time so that it's visually visible
		curTimeItval = shapeLayer.startTime + DL_NORMAL_OPACITY_ANIMATION_DURATION;
		touchTime = [NSNumber numberWithDouble:curTimeItval / videoDuration];
	}
	// fade out effect
	// effect start time
	[shapeLayer.opacityKeyTimes addObject:touchTime];
	// effect end time
	fadeTimeNum = [NSNumber numberWithDouble:(curTimeItval + DL_NORMAL_OPACITY_ANIMATION_DURATION) / videoDuration];
	[shapeLayer.opacityKeyTimes addObject:fadeTimeNum];
	[shapeLayer.opacityValues addObject:oneNum];		// start value
	[shapeLayer.opacityValues addObject:zeroNum];		// end value
	[shapeLayer.pathKeyTimes addObject:fadeTimeNum];
	[shapeLayer.pathValues addObject:[NSValue valueWithPoint:NSPointFromCGPoint(shapeLayer.previousFrame.origin)]];
	shapeLayer.previousTime = curTimeItval + DL_NORMAL_OPACITY_ANIMATION_DURATION;
	shapeLayer.needFadeIn = YES;
}

- (void)hideTouchPathProxy:(TouchPathProxy *)shapeLayer {
	NSTimeInterval curTimeItval = shapeLayer.previousTime;
	// fade out effect
	NSNumber * touchTime = [NSNumber numberWithDouble:curTimeItval];
	// make sure the dot is not moving till animation is done
	[shapeLayer.pathTimes addObject:touchTime];
	[shapeLayer.pathValues addObject:[NSValue valueWithPoint:shapeLayer.previousLocation]];
	shapeLayer.needFadeIn = YES;
	[shapeLayer.pathEndSegmentIndexSet addIndex:[shapeLayer.pathTimes count] - 1];
}

- (void)configureRectLayerTouch:(NSDictionary *)touchDict {
	RectLayer * shapeLayer = nil;
	CGRect tFrame = NSRectToCGRect(NSRectFromString([touchDict objectForKey:DLTouchPrivateFrameKey]));
	CGPoint tMidPoint = MidPointForCGRect(tFrame);
	CGPoint layerMidPoint;
	double minDist = 999999.9;
	double d;
	
	// get the rect layer of the right size
	if ( [rectLayerBuffer count] ) {
		for (RectLayer * theLayer in rectLayerBuffer) {
			if ( CGSizeEqualToSize(tFrame.size, theLayer.previousFrame.size) ) {
				layerMidPoint = MidPointForCGRect(shapeLayer.previousFrame);
				d = DistanceBetween(tMidPoint, layerMidPoint);
				if ( d < minDist ) {
					minDist = d;
					shapeLayer = theLayer;
				}
			}
		}
	}
	if ( shapeLayer == nil ) {
		// we can't find any, create one
		shapeLayer = [RectLayer layer];
		[rectLayerBuffer addObject:shapeLayer];
		// set the frame
		shapeLayer.frame = tFrame;
		[self.parentLayer addSublayer:shapeLayer];
	}
	UITouchPhase ttype = (UITouchPhase)[[touchDict objectForKey:DLTouchPhaseKey] integerValue];
	NSNumber * fadeTimeNum;
	NSNumber * zeroNum = (NSNumber *)kCFBooleanFalse;
	NSNumber * oneNum = (NSNumber *)kCFBooleanTrue;
	NSTimeInterval curTimeItval = [[touchDict objectForKey:DLTouchTimeKey] doubleValue];
	NSValue * curFrameVal = [NSValue valueWithPoint:NSPointFromCGPoint(tFrame.origin)];
	NSNumber * touchTime = [NSNumber numberWithDouble:curTimeItval / videoDuration];
	// set layer animation
	if ( ttype == UITouchPhaseBegan || shapeLayer.needFadeIn ) {
		shapeLayer.touchCount = shapeLayer.touchCount + 1;
		if ( shapeLayer.touchCount == 1 ) {
			// fade it in
			shapeLayer.startTime = curTimeItval;
			// fade in effect
			// effect start time
			fadeTimeNum = [NSNumber numberWithDouble:(curTimeItval - DL_NORMAL_OPACITY_ANIMATION_DURATION) / videoDuration];
			[shapeLayer.opacityKeyTimes addObject:fadeTimeNum];
			// effect end time
			[shapeLayer.opacityKeyTimes addObject:touchTime];
			[shapeLayer.opacityValues addObject:zeroNum];		// start value
			[shapeLayer.opacityValues addObject:oneNum];		// end value
			// make sure the rect is shown when it starts to fade in
			[shapeLayer.pathKeyTimes addObject:fadeTimeNum];
			[shapeLayer.pathValues addObject:curFrameVal];
			// make sure the dot is "in" the location when animation starts
			shapeLayer.needFadeIn = NO;
		}
	} else if ( ttype == UITouchPhaseCancelled || ttype == UITouchPhaseEnded ) {
		shapeLayer.touchCount = shapeLayer.touchCount - 1;
		if ( shapeLayer.touchCount == 0 ) {
			// calculate minimum time
			if ( curTimeItval - shapeLayer.startTime < DL_NORMAL_OPACITY_ANIMATION_DURATION ) {
				// we need to show the dot for longer time so that it's visually visible
				curTimeItval = shapeLayer.startTime + DL_NORMAL_OPACITY_ANIMATION_DURATION;
				touchTime = [NSNumber numberWithDouble:curTimeItval / videoDuration];
			}
			// fade out effect
			// effect start time
			[shapeLayer.opacityKeyTimes addObject:touchTime];
			// effect end time
			fadeTimeNum = [NSNumber numberWithDouble:(curTimeItval + DL_NORMAL_OPACITY_ANIMATION_DURATION) / videoDuration];
			[shapeLayer.opacityKeyTimes addObject:fadeTimeNum];
			[shapeLayer.opacityValues addObject:oneNum];		// start value
			[shapeLayer.opacityValues addObject:zeroNum];		// end value
			// keep rect stationary for fade out effect
			[shapeLayer.pathKeyTimes addObject:fadeTimeNum];
			[shapeLayer.pathValues addObject:curFrameVal];
			shapeLayer.needFadeIn = YES;
		}
	} else {
		// move the rect
		[shapeLayer.pathKeyTimes addObject:touchTime];
		[shapeLayer.pathValues addObject:curFrameVal];
	}
	shapeLayer.previousFrame = tFrame;
	shapeLayer.previousTime = curTimeItval;
	shapeLayer.currentSequence = [[touchDict objectForKey:DLTouchSequenceNumKey] integerValue];
}

- (TouchPathProxy *)configureDistinctTouchPoint:(NSDictionary *)touchDict forLayer:(TouchPathProxy *)pathProxy {
	if ( pathProxy == nil ) return nil;
	//		privateTouch = [[touchDict objectForKey:DLTouchPrivateKey] boolValue];
	// setup the layer's position at time
	// time
	NSTimeInterval curTimeItval = [[touchDict objectForKey:DLTouchTimeKey] doubleValue];
	NSNumber * touchTime = [NSNumber numberWithDouble:curTimeItval];
	// fade in/out of dot
	UITouchPhase ttype = (UITouchPhase)[[touchDict objectForKey:DLTouchPhaseKey] integerValue];
	NSPoint curPoint = NSPointFromString([touchDict objectForKey:DLTouchCurrentLocationKey]);
	NSValue * curPointVal = [NSValue valueWithPoint:curPoint];
	// do things normal
	if ( ttype == UITouchPhaseBegan || pathProxy.needFadeIn ) {
		pathProxy.needFadeIn = NO;
		pathProxy.startTime = curTimeItval;
		// fade in effect
		// make sure the dot is "in" the location when animation starts
		[pathProxy.pathTimes addObject:touchTime];
		[pathProxy.pathValues addObject:curPointVal];
		// save the index value
		[pathProxy.pathStartSegmentIndexSet addIndex:[pathProxy.pathTimes count] - 1];
	} else if ( ttype == UITouchPhaseCancelled || ttype == UITouchPhaseEnded ) {
//		if ( curTimeItval - pathProxy.startTime < DL_MINIMUM_DURATION ) {
//			// we need to show the dot for longer time so that it's visually visible
//			curTimeItval = pathProxy.startTime + DL_MINIMUM_DURATION;
//			touchTime = [NSNumber numberWithDouble:curTimeItval];
//		}
		// fade out effect
		// set paths
		[pathProxy.pathTimes addObject:touchTime];
		// position of layer at time
		[pathProxy.pathValues addObject:curPointVal];
		[pathProxy.pathEndSegmentIndexSet addIndex:[pathProxy.pathTimes count] - 1];
	} else {
		// set paths
		[pathProxy.pathTimes addObject:touchTime];
		// position of layer at time
		[pathProxy.pathValues addObject:curPointVal];
	}
	pathProxy.previousLocation = curPoint;
	pathProxy.previousTime = curTimeItval;
	pathProxy.currentSequence = [[touchDict objectForKey:DLTouchSequenceNumKey] integerValue];
	return pathProxy;
}

- (BOOL)currentTouch:(id)curItem hasDifferentCompositionWithPreviousTouch:(id)prevItem {
	// we want to check whether the previous set of touches belongs to the same event as the current set of touches.
	NSDictionary * prevDict;
	if ( [curItem count] == [prevItem count] ) {
		// we need to do some checking
		NSInteger thePhase;
		BOOL needMoreChecking = YES;
		for (NSDictionary * curDict in curItem) {
			thePhase = [[curDict objectForKey:DLTouchPhaseKey] integerValue];
			if ( thePhase != UITouchPhaseMoved && thePhase != UITouchPhaseStationary ) {
				needMoreChecking = NO;
				break;
			}
		}
		if ( needMoreChecking ) {
			for (prevDict in prevItem) {
				thePhase = [[prevDict objectForKey:DLTouchPhaseKey] integerValue];
				if ( thePhase != UITouchPhaseBegan && thePhase != UITouchPhaseStationary && thePhase != UITouchPhaseMoved ) {
					needMoreChecking = NO;
					break;
				}
			}
		}
		return needMoreChecking;
	}
	return NO;
}

- (TouchPathProxy *)layerWithPreviousLocation:(NSPoint)prevLoc forSequence:(NSInteger)seqNum {
	TouchPathProxy * shapeLayer = nil;
	double d = 0.0;
	double minDist = 9999.0;
	for (TouchPathProxy * theLayer in dotPositionBuffer) {
		if ( theLayer.currentSequence != seqNum ) {
			// try to do the comparison only when the sequence number of the layer is not the same as the requested one. If they are the same, the layer has been compared and matached another points already.
			d = [theLayer discrepancyWithPreviousLocation:prevLoc];
			if ( d < minDist ) {
				shapeLayer = theLayer;
				minDist = d;
			}
		}
	}
	shapeLayer.currentSequence = seqNum;
	return shapeLayer;
}

- (TouchPathProxy *)touchProxyForTouch:(NSDictionary *)aTouchDict {
	TouchPathProxy * shapeLayer = [self layerWithPreviousLocation:NSPointFromString([aTouchDict objectForKey:DLTouchPreviousLocationKey]) forSequence:[[aTouchDict objectForKey:DLTouchSequenceNumKey] integerValue]];
	if ( shapeLayer == nil ) {
		// create a new layer
		shapeLayer = [[TouchPathProxy alloc] init];
		[dotPositionBuffer addObject:shapeLayer];
	}
	return shapeLayer;
}

- (void)setupGestureAnimationsForLayer:(CALayer *)prnLayer {
	self.parentLayer = prnLayer;
	// group touches from the same event in an array
	NSInteger prevSeqNum = -1, numTouchesInSeq = 0, curSeqNum;
	NSInteger idx = 0;
	NSMutableArray * groupArray = [NSMutableArray arrayWithCapacity:10];
	for (NSDictionary * touchDict in touches) {
		curSeqNum = [[touchDict objectForKey:DLTouchSequenceNumKey] integerValue];
		if ( prevSeqNum != curSeqNum ) {
			if ( numTouchesInSeq ) {
				// copy the previous item(s) into groupArray
				if ( numTouchesInSeq > 1 ) {
					[groupArray addObject:[touches subarrayWithRange:NSMakeRange(idx - numTouchesInSeq, numTouchesInSeq)]];
				} else {
					[groupArray addObject:[NSArray arrayWithObject:[touches objectAtIndex:idx - 1]]];
				}
			}
			numTouchesInSeq = 1;
		} else {
			numTouchesInSeq++;
		}
		prevSeqNum = curSeqNum;
		idx++;
	}
	// perform the last check
	if ( numTouchesInSeq ) {
		if ( numTouchesInSeq > 1 ) {
			[groupArray addObject:[touches subarrayWithRange:NSMakeRange(idx - numTouchesInSeq, numTouchesInSeq)]];
		} else {
			[groupArray addObject:[NSArray arrayWithObject:[touches objectAtIndex:idx - 1]]];
		}
	}
	NSDictionary * touchDict = nil;
	NSString * locStr = nil;
	idx = 0;
	NSInteger prevIdx = 0;
	TouchPathProxy * proxyLayer = nil;
	for (id item in groupArray) {
		NSArray * theTouches = item;
		curSeqNum = 0;
		if ( [self currentTouch:item hasDifferentCompositionWithPreviousTouch:[groupArray objectAtIndex:prevIdx]] ) {
			// draw touch point first				
			for (touchDict  in theTouches) {
				if ( curSeqNum == 0 ) {
					curSeqNum = [[touchDict objectForKey:DLTouchSequenceNumKey] integerValue];
				}
				// perform checking with point first
				locStr = [touchDict objectForKey:DLTouchCurrentLocationKey];
				if ( locStr ) {
					// this is a touch point, perform the normal logic
					proxyLayer = [self touchProxyForTouch:touchDict];
					[self configureDistinctTouchPoint:touchDict forLayer:proxyLayer];
				} else {
					// this is a rect
					[self configureRectLayerTouch:touchDict];
				}
			}
			for (TouchPathProxy * theLayer in dotPositionBuffer) {
				if ( theLayer.currentSequence != curSeqNum ) {
					// dump this layer
					if ( !theLayer.needFadeIn ) [self hideTouchPathProxy:theLayer];
					theLayer.currentSequence = curSeqNum;
				}
			}
			for (RectLayer * theLayer in rectLayerBuffer) {
				if ( theLayer.currentSequence != curSeqNum ) {
					if ( !theLayer.needFadeIn ) [self hideRectLayer:theLayer];
					theLayer.currentSequence = curSeqNum;
				}
			}
		} else {
			// match layer with touches first
			double d = 0.0;
			NSUInteger idx = 0;
			if ( [self numberOfInFlightDotLayer] > [theTouches count] ) {
				NSMutableArray * remainingLayers = [NSMutableArray arrayWithArray:dotPositionBuffer];
				NSMutableIndexSet * tchHandledIdxSet = [NSMutableIndexSet indexSet];
				// we need to remove extra layers. Iterate on touch point first
				for (touchDict in theTouches) {
					double minDist = 9999.0;
					NSDictionary * targetTouch = nil;
					TouchPathProxy * targetLayer = nil;
					for (TouchPathProxy * theLayer in dotPositionBuffer) {
						locStr = [touchDict objectForKey:DLTouchCurrentLocationKey];
						if ( locStr ) {
							NSPoint prevLoc = NSPointFromString(locStr);
							d = [theLayer discrepancyWithPreviousLocation:prevLoc];
							if ( d < minDist ) {
								minDist = d;
								targetTouch = touchDict;
								targetLayer = theLayer;
							}
						}
					}
					// we have the touch with shortest distance from the layer
					if ( targetTouch ) {
						[tchHandledIdxSet addIndex:idx];
						[remainingLayers removeObject:targetLayer];
						[self configureDistinctTouchPoint:targetTouch forLayer:targetLayer];
					}
					idx++;
				}
				// hide extra layers
				for (proxyLayer in remainingLayers) {
					[self hideTouchPathProxy:proxyLayer];
				}
				// draw touches
				if ( [tchHandledIdxSet count] < [theTouches count] ) {
					// draw the remaining touches
					idx =  0;
					for (touchDict in theTouches) {
						if ( [tchHandledIdxSet containsIndex:idx++] ) continue;
						locStr = [touchDict objectForKey:DLTouchCurrentLocationKey];
						if ( locStr ) {
							TouchPathProxy * shapeLayer = [self touchProxyForTouch:touchDict];
							[self configureDistinctTouchPoint:touchDict forLayer:shapeLayer];
						} else {
							[self configureRectLayerTouch:touchDict];
						}
					}
				}
			} else {
				NSMutableArray * remainingTouches = [NSMutableArray arrayWithArray:theTouches];
				NSMutableIndexSet * layerHandledIdxSet = [NSMutableIndexSet indexSet];
				// match points with layer (perform thorough check)
				for (TouchPathProxy * theLayer in dotPositionBuffer) {
					double minDist = 9999.0;
					NSDictionary * targetTouch = nil;
					TouchPathProxy * targetLayer = nil;
					for (touchDict in remainingTouches) {
						locStr = [touchDict objectForKey:DLTouchCurrentLocationKey];
						if ( locStr ) {
							NSPoint prevLoc = NSPointFromString(locStr);
							d = [theLayer discrepancyWithPreviousLocation:prevLoc];
							if ( d < minDist ) {
								minDist = d;
								targetTouch = touchDict;
								targetLayer = theLayer;
							}
						}
					}
					// we have the touch with shortest distance from the layer
					if ( targetTouch ) {
						[layerHandledIdxSet addIndex:idx];
						[remainingTouches removeObject:targetTouch];
						[self configureDistinctTouchPoint:targetTouch forLayer:targetLayer];
					}
					idx++;
				}
				// hide extra layers
				if ( [layerHandledIdxSet count] < [dotPositionBuffer count] ) {
					idx = 0;
					for (proxyLayer in dotPositionBuffer) {
						if ( [layerHandledIdxSet containsIndex:idx++] ) continue;
						if ( !proxyLayer.needFadeIn ) [self hideTouchPathProxy:proxyLayer];
					}
				}
				// normal drawing
				for (touchDict in remainingTouches) {
					locStr = [touchDict objectForKey:DLTouchCurrentLocationKey];
					if ( locStr ) {
						proxyLayer = [self touchProxyForTouch:touchDict];
						[self configureDistinctTouchPoint:touchDict forLayer:proxyLayer];
					} else {
						[self configureRectLayerTouch:touchDict];
					}
				}
			}
		}
		prevIdx = idx++;
	}
	NSNumber * zeroNum = (__bridge NSNumber *)kCFBooleanFalse;
	NSNumber * oneNum = [NSNumber numberWithDouble:0.65];//(__bridge NSNumber *)kCFBooleanTrue;
	// just in case if there's any bug or reason that the onscreenLayerBuffer still contains some layers
	@autoreleasepool {
		for (TouchPathProxy * proxyObj in dotPositionBuffer) {
			// transverse all paths
			NSArray * pathAy = proxyObj.pathValues;
			BOOL needCreateContainerLayer = NO;
			CALayer * gestureLayer = nil;
			NSNumber * startKeyTimeNum;
			idx = 0;
			for (NSValue * pointVal in pathAy) {
				CGPoint curPoint = NSPointToCGPoint([pointVal pointValue]);
				NSNumber * keyTimeNum = [proxyObj.pathTimes objectAtIndex:idx];
				NSTimeInterval curTime = [keyTimeNum doubleValue];
				if ( [proxyObj.pathStartSegmentIndexSet containsIndex:idx] ) {
					// this is the starting path. create the ripple
					TouchLayer * magLayer = [TouchLayer layer];
					magLayer.position = curPoint;
					// show the dot should start magnifying when the dot has appeared
					CAAnimationGroup * animGroup = [CAAnimationGroup animation];
					CABasicAnimation * opacAnim = [CABasicAnimation animationWithKeyPath:@"opacity"];
					opacAnim.fromValue = (NSNumber *)kCFBooleanTrue;
					opacAnim.toValue = (NSNumber *)kCFBooleanFalse;
					CABasicAnimation * sizeAnim = [CABasicAnimation animationWithKeyPath:@"transform"];
					sizeAnim.fromValue = [NSValue valueWithCATransform3D:CATransform3DIdentity];
					sizeAnim.toValue = [NSValue valueWithCATransform3D:CATransform3DMakeScale(4.0, 4.0, 1.0)];
					[animGroup setAnimations:[NSArray arrayWithObjects:opacAnim, sizeAnim, nil]];
					animGroup.duration = 0.75;
					animGroup.beginTime = curTime;
					animGroup.removedOnCompletion = NO;
					[magLayer addAnimation:animGroup forKey:nil];
					[prnLayer addSublayer:magLayer];
					
					startKeyTimeNum = keyTimeNum;
					needCreateContainerLayer = YES;
				} else if ( [proxyObj.pathEndSegmentIndexSet containsIndex:idx] ) {
					// this is the end-point, creates path, do not create new line segment
					// check if the previous point is the beginning point. If so, no need to do anything.
					if ( ![proxyObj.pathStartSegmentIndexSet containsIndex:idx - 1] ) {
						// we need to create new segment
						CGPoint lastPosition = NSPointToCGPoint([[pathAy objectAtIndex:idx - 1] pointValue]);
						LineRectLayer * lineLayer = [LineRectLayer layerAtPosition:lastPosition];
						CGRect theBounds = [lineLayer getBoundsAndSetTransformationToPoint:curPoint];
						theBounds.size.width += 14.0;
//						lastPosition.x -= 7.0;
						lineLayer.position = lastPosition;
						CABasicAnimation * animation = [CABasicAnimation animationWithKeyPath:@"bounds"];
						animation.toValue = [NSValue valueWithRect:NSRectFromCGRect(theBounds)];
						animation.fromValue = [NSValue valueWithRect:NSRectFromCGRect(lineLayer.bounds)];
						NSTimeInterval prevTime = [[proxyObj.pathTimes objectAtIndex:idx - 1] doubleValue];
						animation.beginTime = prevTime;
						animation.duration = curTime - prevTime;
						animation.removedOnCompletion = NO;
						animation.fillMode = kCAFillModeForwards;
						animation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear];
						[lineLayer addAnimation:animation forKey:nil];
						[gestureLayer addSublayer:lineLayer];
						// path has been added, we need to fade out the layer
						CAKeyframeAnimation * opacAnimation = [CAKeyframeAnimation animationWithKeyPath:@"opacity"];
						opacAnimation.keyTimes = [NSArray arrayWithObjects:[NSNumber numberWithDouble:([startKeyTimeNum doubleValue] - DL_MINIMUM_DURATION) / videoDuration], [NSNumber numberWithDouble:[startKeyTimeNum doubleValue] / videoDuration], [NSNumber numberWithDouble:[keyTimeNum doubleValue] / videoDuration], [NSNumber numberWithDouble:([keyTimeNum doubleValue] + DL_MINIMUM_DURATION) / videoDuration], nil];
						opacAnimation.values = [NSArray arrayWithObjects:zeroNum, oneNum, oneNum, zeroNum, nil];
						opacAnimation.beginTime = AVCoreAnimationBeginTimeAtZero;
						opacAnimation.duration = videoDuration;
						opacAnimation.removedOnCompletion = NO;
						
						[gestureLayer addAnimation:opacAnimation forKey:nil];
						gestureLayer = nil;
//						[prnLayer addSublayer:lineLayer];
					}
				} else {
					// points in the middle, create new segment
					// we need to create new segment
					CGPoint lastPosition = NSPointToCGPoint([[pathAy objectAtIndex:idx - 1] pointValue]);
					LineRectLayer * lineLayer = [LineRectLayer layerAtPosition:lastPosition];
					CGRect theBounds = [lineLayer getBoundsAndSetTransformationToPoint:curPoint];
					theBounds.size.width += 14.0;
//					lastPosition.x -= 7.0;
					lineLayer.position = lastPosition;
					CABasicAnimation * animation = [CABasicAnimation animationWithKeyPath:@"bounds"];
					animation.toValue = [NSValue valueWithRect:NSRectFromCGRect(theBounds)];
					animation.fromValue = [NSValue valueWithRect:NSRectFromCGRect(lineLayer.bounds)];
					NSTimeInterval prevTime = [[proxyObj.pathTimes objectAtIndex:idx - 1] doubleValue];
					animation.beginTime = prevTime;
					animation.duration = curTime - prevTime;
					animation.removedOnCompletion = NO;
					animation.fillMode = kCAFillModeForwards;
					animation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear];
					[lineLayer addAnimation:animation forKey:nil];
					
					if ( needCreateContainerLayer ) {
						gestureLayer = [CALayer layer];
						gestureLayer.opacity = 0.0;
						
						[prnLayer addSublayer:gestureLayer];
						needCreateContainerLayer = NO;
					}
					[gestureLayer addSublayer:lineLayer];
//					[prnLayer addSublayer:lineLayer];
				}
				idx++;
			}
		}
	}
	for (RectLayer * theLayer in rectLayerBuffer) {
		CAKeyframeAnimation * fadeFrameAnimation = [CAKeyframeAnimation animationWithKeyPath:@"opacity"];
		fadeFrameAnimation.values = theLayer.opacityValues;
		fadeFrameAnimation.keyTimes = theLayer.opacityKeyTimes;
		fadeFrameAnimation.beginTime = AVCoreAnimationBeginTimeAtZero;
		fadeFrameAnimation.duration = videoDuration;
		fadeFrameAnimation.removedOnCompletion = NO;
		
		CAKeyframeAnimation * moveFrameAnimation = [CAKeyframeAnimation animationWithKeyPath:@"position"];
		moveFrameAnimation.values = theLayer.pathValues;
		moveFrameAnimation.keyTimes = theLayer.pathKeyTimes;
		moveFrameAnimation.beginTime = AVCoreAnimationBeginTimeAtZero;
		moveFrameAnimation.duration = videoDuration;
		moveFrameAnimation.removedOnCompletion = NO;
		
		[theLayer addAnimation:fadeFrameAnimation forKey:@"rectOpacityAnimation"];
		[theLayer addAnimation:moveFrameAnimation forKey:@"rectPositionAnimation"];
	}
}

- (void)checkMajorOrientationForTrack:(NSArray *)track {
	NSUInteger c = [track count];
	NSDictionary * oriDict = nil;
	if ( c == 0 ) {
		// just use default portrait
		majorOrientation = UIInterfaceOrientationPortrait;
	} else if ( c == 1 ) {
		oriDict = [track lastObject];
		majorOrientation = (UIInterfaceOrientation)[[oriDict objectForKey:DLInterfaceOrientationKey] integerValue];
	} else {
		NSDictionary * prevOriDict;
		prevOriDict = [track objectAtIndex:0];
		NSMutableDictionary * timeDurationDict = [NSMutableDictionary dictionaryWithCapacity:4];
		NSNumber * oriNum, * accuTimeNum;
		NSTimeInterval timeVal;
		for (NSInteger i = 1; i < c; i++) {
			oriDict = [track objectAtIndex:i];
			oriNum = [oriDict objectForKey:DLInterfaceOrientationKey];
			// time interval since last change
			timeVal = [[oriDict objectForKey:DLOrientationTimeKey] doubleValue] - [[prevOriDict objectForKey:DLOrientationTimeKey] doubleValue];
			// accumulate time duration inbetween change
			accuTimeNum = [timeDurationDict objectForKey:oriNum];
			if ( accuTimeNum ) {
				accuTimeNum = [NSNumber numberWithDouble:[accuTimeNum doubleValue] + timeVal];
			} else {
				accuTimeNum = [NSNumber numberWithDouble:timeVal];
			}
			[timeDurationDict setObject:accuTimeNum forKey:oriNum];
		}
		// look for the major orientation
		timeVal = -9999.0;
		NSTimeInterval curVal;
		NSNumber * curMajorOriNum;
		for (oriNum in timeDurationDict) {
			curVal = [[timeDurationDict objectForKey:oriNum] doubleValue];
			if ( curVal > timeVal ) {
				// this is the current max
				curMajorOriNum = oriNum;
			}
		}
		// this is the major orientation
		majorOrientation = (UIInterfaceOrientation)[oriNum integerValue];
	}
}

- (void)setOrientationTransformForLayer:(CALayer *)aLayer {
	CATransform3D origTransform = aLayer.transform;
	CGFloat r = 0.0;
	switch (majorOrientation) {
		case UIInterfaceOrientationLandscapeLeft:
			r = -M_PI_2;
			break;
			
		case UIInterfaceOrientationLandscapeRight:
			r = M_PI_2;
			break;
			
		case UIInterfaceOrientationPortraitUpsideDown:
			r = M_PI;
			break;
			
		default:
			break;
	}
	aLayer.transform = CATransform3DRotate(origTransform, r, 0.0, 0.0, 1.0);
//	aLayer.transform = CATransform3DConcat(origTransform, CATransform3DMakeAffineTransform(CGAffineTransformRotate(CGAffineTransformIdentity, r)));
}

- (CGFloat)majorOrientationRotationAngle {
	CGFloat r = 0.0;
	switch (majorOrientation) {
		case UIInterfaceOrientationLandscapeLeft:
			r = -M_PI_2;
			break;
			
		case UIInterfaceOrientationLandscapeRight:
			r = M_PI_2;
			break;
			
		case UIInterfaceOrientationPortraitUpsideDown:
			r = M_PI;
			break;
			
		default:
			break;
	}
	return r;
}

@end
