//
//  RenderingUnitV02.m
//  gesturedrawer
//
//  Created by Bill So on 5/29/12.
//  Copyright (c) 2012 Headnix. All rights reserved.
//

#import "TouchLayer.h"
#import "RectLayer.h"
#import "RenderingUnitV02.h"

#define DL_MINIMUM_DURATION 0.15
#define DL_NORMAL_OPACITY_ANIMATION_DURATION 0.1
#define DL_TOUCH_POINT_TYPE		1000
#define DL_TOUCH_RECT_TYPE		1001

@implementation RenderingUnitV02

- (id)initWithVideoAtPath:(NSString *)vdoPath destinationPath:(NSString *)dstPath touchesPropertyList:(NSDictionary *)tchPlist {
	self = [super initWithVideoAtPath:vdoPath destinationPath:dstPath touchesPropertyList:tchPlist];
	rectLayerBuffer = [[NSMutableArray alloc] initWithCapacity:2];
	return self;
}

- (void)exportVideoWithCompletionHandler:(void (^)(void))handler {
	AVAsset * srcVdoAsset = [AVAsset assetWithURL:[NSURL fileURLWithPath:sourceFilePath]];
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
	
	AVAssetTrack *videoTrack = [[srcComposition tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0];
	
	AVMutableVideoCompositionLayerInstruction *passThroughLayer = [AVMutableVideoCompositionLayerInstruction videoCompositionLayerInstructionWithAssetTrack:videoTrack];
    if (CGAffineTransformEqualToTransform(originalTrack.preferredTransform, CGAffineTransformMakeScale(1, -1))) {
        // Original video was flipped vertically. Flip the new video vertically as well.
        // Can't just pass the original transform along since the instruction requires translation to be set.
        [passThroughLayer setTransform:CGAffineTransformMake(1, 0, 0, -1, 0, vdoSize.height) atTime:kCMTimeZero];
    }
	passThroughInstruction.layerInstructions = [NSArray arrayWithObject:passThroughLayer];
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
	//	videoComposition.animationTool = [AVVideoCompositionCoreAnimationTool videoCompositionCoreAnimationToolWithAdditionalLayer:parentLayer asTrackID:23];
	videoComposition.frameDuration = CMTimeMake(1, 30);
	videoComposition.renderSize = vdoSize;
	
	NSError * error = nil;
	AVAssetWriter * assetWriter = [AVAssetWriter assetWriterWithURL:[NSURL fileURLWithPath:destinationFilePath] fileType:AVFileTypeMPEG4 error:&error];
	AVAssetWriterInput * videoInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:[NSDictionary dictionaryWithObjectsAndKeys:AVVideoCodecH264, AVVideoCodecKey, [NSNumber numberWithFloat:vdoSize.width], AVVideoWidthKey, [NSNumber numberWithFloat:vdoSize.height], AVVideoHeightKey, nil]];
	AVAssetReader * assetReader = [AVAssetReader assetReaderWithAsset:srcComposition error:&error];
	AVAssetReaderVideoCompositionOutput * videoCompositionOutput = [AVAssetReaderVideoCompositionOutput assetReaderVideoCompositionOutputWithVideoTracks:[NSArray arrayWithObject:videoTrack] videoSettings:nil];
	videoCompositionOutput.videoComposition = videoComposition;
	NSLog(@"can add output: %d", [assetReader canAddOutput:videoCompositionOutput]);
	[assetReader addOutput:videoCompositionOutput];
	
	[assetWriter addInput:videoInput];
	assetWriter.shouldOptimizeForNetworkUse = YES;
	BOOL success = NO;
	success = [assetReader startReading];
	if ( !success ) {
		NSLog(@"error reading asset: %@", assetReader.error);
	}
	success = [assetWriter startWriting];
	[assetWriter startSessionAtSourceTime:kCMTimeZero];
	[videoInput requestMediaDataWhenReadyOnQueue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0) usingBlock:^{
		while (videoInput.readyForMoreMediaData) {
			if ( assetReader.status == AVAssetReaderStatusUnknown ) continue;
			CMSampleBufferRef sampleBuffer = [videoCompositionOutput copyNextSampleBuffer];
			if ( sampleBuffer ) {
				[videoInput appendSampleBuffer:sampleBuffer];
				CFRelease(sampleBuffer);
			} else {
				[videoInput markAsFinished];
				BOOL writeSuccess = [assetWriter finishWriting];
				NSLog(@"video exported - %@ - %@", destinationFilePath, writeSuccess ? @"no error" : assetWriter.error);
				handler();
				break;
			}
		}
	}];
}

- (void)setLayer:(TouchLayer *)shapeLayer fadeIn:(BOOL)aflag atTime:(NSTimeInterval)curTimeItval location:(NSPoint)curLoc {
	shapeLayer.startTime = curTimeItval;
	// fade in effect
	// effect start time
	NSNumber * fadeTimeNum = [NSNumber numberWithDouble:(curTimeItval - 0.15) / videoDuration];
	[shapeLayer.opacityKeyTimes addObject:fadeTimeNum];
	// effect end time
	[shapeLayer.opacityKeyTimes addObject:[NSNumber numberWithDouble:curTimeItval/videoDuration]];
	[shapeLayer.opacityValues addObject:(NSNumber *)kCFBooleanFalse];		// start value
	[shapeLayer.opacityValues addObject:(NSNumber *)kCFBooleanTrue];		// end value
	// make sure the dot is "in" the location when animation starts
	[shapeLayer.pathKeyTimes addObject:fadeTimeNum];
	[shapeLayer.pathValues addObject:[NSValue valueWithPoint:curLoc]];
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
	}
}

- (void)configureRectLayerTouch:(NSDictionary *)touchDict {
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
	UITouchPhase ttype = [[touchDict objectForKey:DLTouchPhaseKey] integerValue];
	NSNumber * fadeTimeNum;
	NSNumber * zeroNum = (NSNumber *)kCFBooleanFalse;
	NSNumber * oneNum = (NSNumber *)kCFBooleanTrue;
	NSTimeInterval curTimeItval = [[touchDict objectForKey:DLTouchTimeKey] doubleValue];
	NSNumber * touchTime = [NSNumber numberWithDouble:curTimeItval / videoDuration];
	// set layer animation
	if ( ttype == UITouchPhaseBegan ) {
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
			// make sure the dot is "in" the location when animation starts
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
		}
	}
}

- (CALayer *)configureDistinctTouchPoint:(NSDictionary *)touchDict {
	TouchLayer * shapeLayer = [self layerForTouch:touchDict parentLayer:self.parentLayer];
	if ( shapeLayer == nil ) return nil;
	//		privateTouch = [[touchDict objectForKey:DLTouchPrivateKey] boolValue];
	// setup the layer's position at time
	// time
	NSTimeInterval curTimeItval = [[touchDict objectForKey:DLTouchTimeKey] doubleValue];
	NSNumber * touchTime = [NSNumber numberWithDouble:curTimeItval / videoDuration];
	// fade in/out of dot
	UITouchPhase ttype = [[touchDict objectForKey:DLTouchPhaseKey] integerValue];
	NSPoint curPoint = NSPointFromString([touchDict objectForKey:DLTouchCurrentLocationKey]);
	NSValue * curPointVal = [NSValue valueWithPoint:curPoint];
	NSNumber * fadeTimeNum;
	NSNumber * zeroNum = (NSNumber *)kCFBooleanFalse;
	NSNumber * oneNum = (NSNumber *)kCFBooleanTrue;
	// do things normal
	if ( ttype == UITouchPhaseBegan || shapeLayer.needFadeIn ) {
		shapeLayer.needFadeIn = NO;
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
		[shapeLayer.pathKeyTimes addObject:fadeTimeNum];
		[shapeLayer.pathValues addObject:curPointVal];
	} else if ( ttype == UITouchPhaseCancelled || ttype == UITouchPhaseEnded ) {
		if ( curTimeItval - shapeLayer.startTime < DL_MINIMUM_DURATION ) {
			// we need to show the dot for longer time so that it's visually visible
			curTimeItval = shapeLayer.startTime + DL_MINIMUM_DURATION;
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
		// make sure the dot is not moving till animation is done
		[shapeLayer.pathKeyTimes addObject:fadeTimeNum];
		[shapeLayer.pathValues addObject:curPointVal];
	}
	// set paths
	[shapeLayer.pathKeyTimes addObject:touchTime];
	// position of layer at time
	[shapeLayer.pathValues addObject:curPointVal];
	shapeLayer.previousLocation = curPoint;
	shapeLayer.previousTime = curTimeItval;
	return shapeLayer;
}

- (BOOL)currentTouch:(NSDictionary *)curItem hasDifferentCompositionWithPreviousTouch:(id)prevItem {
	if ( [curItem objectForKey:DLTouchPrivateFrameKey] ) {
		// curItem is a rect
		if ( [prevItem isKindOfClass:[NSDictionary class]] ) {
			// check if it's a point or a rect
			NSDictionary * prevDict = prevItem;
			if ( [prevDict objectForKey:DLTouchPrivateFrameKey] == nil ) {
				NSInteger curPhase = [[curItem objectForKey:DLTouchPhaseKey] integerValue];
				NSInteger prevPhase = [[prevDict objectForKey:DLTouchPhaseKey] integerValue];
				if ( curPhase == prevPhase || (( curPhase == UITouchPhaseMoved || curPhase == UITouchPhaseStationary ) && ( prevPhase == UITouchPhaseStationary || prevPhase == UITouchPhaseMoved )) ) {
					// the previous touch is a point. We are at the boundary case.
					return YES;
				}
			}
		} else {
			// previous event contain multiple touches
		}
	} else {
		if ( [prevItem isKindOfClass:[NSDictionary class]] ) {
			NSDictionary * prevDict = prevItem;
			if ( [prevDict objectForKey:DLTouchPrivateFrameKey] ) {
				NSInteger curPhase = [[curItem objectForKey:DLTouchPhaseKey] integerValue];
				NSInteger prevPhase = [[prevDict objectForKey:DLTouchPhaseKey] integerValue];
				if ( curPhase == prevPhase || (( curPhase == UITouchPhaseMoved || curPhase == UITouchPhaseStationary ) && ( prevPhase == UITouchPhaseStationary || prevPhase == UITouchPhaseMoved )) ) {
					return YES;
				}
			}
		} else {
			// previous event contains multiple touches
		}
	}
	return NO;
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
					[groupArray addObject:[touches objectAtIndex:idx - 1]];
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
			[groupArray addObject:[touches objectAtIndex:idx - 1]];
		}
	}
	NSMutableArray * tempRectAy = [NSMutableArray arrayWithCapacity:2];
	NSMutableArray * tempMatchedLayerAy = [NSMutableArray arrayWithCapacity:2];
	CALayer * matchedLayer;
	NSDictionary * touchDict = nil;
	NSString * locStr = nil;
	idx = 0;
	NSInteger prevIdx = 0;
	for (id item in groupArray) {
		if ( [item isKindOfClass:[NSDictionary class]] ) {
			// this group has only 1 single touch
			touchDict = item;
			locStr = [touchDict objectForKey:DLTouchCurrentLocationKey];
			if ( locStr ) {
				// this is a touch point
				// check if we are moving out from a private view
				if ( [self currentTouch:touchDict hasDifferentCompositionWithPreviousTouch:[groupArray objectAtIndex:prevIdx]] ) {
					
					// hide the rect
					[self hideRectLayerForTouch:[groupArray objectAtIndex:prevIdx]];
				}
				[self configureDistinctTouchPoint:item];
			} else {
				// this is a rect
				// check if this event has the same composition as previous event
				if ( [self currentTouch:touchDict hasDifferentCompositionWithPreviousTouch:[groupArray objectAtIndex:prevIdx]] ) {
					// different composition, we need to fade out the odd one
					// Dig up the previous dot layer and fade it out
					if ( [onscreenDotLayerBuffer count] == 1 ) {
						TouchLayer * shapeLayer = [onscreenDotLayerBuffer objectAtIndex:0];
						NSTimeInterval curTimeItval = shapeLayer.previousTime;
						NSNumber * fadeTimeNum;
						// fade the shape layer
						fadeTimeNum = [NSNumber numberWithDouble:(curTimeItval + DL_NORMAL_OPACITY_ANIMATION_DURATION) / videoDuration];
						// fade out effect
						// effect start time
						[shapeLayer.opacityKeyTimes addObject:[NSNumber numberWithDouble:curTimeItval / videoDuration]];
						// effect end time
						[shapeLayer.opacityKeyTimes addObject:fadeTimeNum];
						[shapeLayer.opacityValues addObject:(NSNumber *)kCFBooleanTrue];		// start value
						[shapeLayer.opacityValues addObject:(NSNumber *)kCFBooleanFalse];		// end value
						// make sure the dot is not moving till animation is done
						[shapeLayer.pathKeyTimes addObject:fadeTimeNum];
						[shapeLayer.pathValues addObject:[NSValue valueWithPoint:shapeLayer.previousLocation]];
						[unassignedDotLayerBuffer addObject:shapeLayer];
						[onscreenDotLayerBuffer removeObjectAtIndex:0];
						shapeLayer.needFadeIn = YES;
					}
					[self showRectLayerForTouch:touchDict];
				} else {
					[self configureRectLayerTouch:touchDict];
				}
			}
		} else {
			NSArray * theTouches = item;
			for (touchDict  in theTouches) {
				// perform checking with point first
				locStr = [touchDict objectForKey:DLTouchCurrentLocationKey];
				if ( locStr ) {
					// this is a touch point, perform the normal logic
					matchedLayer = [self configureDistinctTouchPoint:touchDict];
					if ( matchedLayer ) [tempMatchedLayerAy addObject:matchedLayer];
				} else {
					// this is a rect
					[tempRectAy addObject:touchDict];
				}
			}
			if ( [tempRectAy count] ) {
				// there's rect in this set of event. check with the previous event to see if we need to do anything
				for (touchDict in tempRectAy) {
					// these are all rect
					[self configureRectLayerTouch:touchDict];
				}
				[tempRectAy removeAllObjects];
			}
			[tempMatchedLayerAy removeAllObjects];
		}
		prevIdx = idx++;
	}
	// just in case if there's any bug or reason that the onscreenLayerBuffer still contains some layers
	if ( [onscreenDotLayerBuffer count] ) {
		[unassignedDotLayerBuffer addObjectsFromArray:onscreenDotLayerBuffer];
		[onscreenDotLayerBuffer removeAllObjects];
	}
	for (TouchLayer * theLayer in unassignedDotLayerBuffer) {
		CAKeyframeAnimation * dotFrameAnimation = [CAKeyframeAnimation animationWithKeyPath:@"position"];
		CAKeyframeAnimation * fadeFrameAnimation = [CAKeyframeAnimation animationWithKeyPath:@"opacity"];
		dotFrameAnimation.values = theLayer.pathValues;
		dotFrameAnimation.keyTimes = theLayer.pathKeyTimes;
		dotFrameAnimation.beginTime = AVCoreAnimationBeginTimeAtZero;
		dotFrameAnimation.duration = videoDuration;
		dotFrameAnimation.removedOnCompletion = NO;
		
		fadeFrameAnimation.values = theLayer.opacityValues;
		fadeFrameAnimation.keyTimes = theLayer.opacityKeyTimes;
		fadeFrameAnimation.beginTime = AVCoreAnimationBeginTimeAtZero;
		fadeFrameAnimation.duration = videoDuration;
		fadeFrameAnimation.removedOnCompletion = NO;
		
		[theLayer addAnimation:fadeFrameAnimation forKey:@"fadeAnimation"];
		[theLayer addAnimation:dotFrameAnimation forKey:@"positionAnimation"];
	}
	for (RectLayer * theLayer in rectLayerBuffer) {
		CAKeyframeAnimation * fadeFrameAnimation = [CAKeyframeAnimation animationWithKeyPath:@"opacity"];
		fadeFrameAnimation.values = theLayer.opacityValues;
		fadeFrameAnimation.keyTimes = theLayer.opacityKeyTimes;
		fadeFrameAnimation.beginTime = AVCoreAnimationBeginTimeAtZero;
		fadeFrameAnimation.duration = videoDuration;
		fadeFrameAnimation.removedOnCompletion = NO;
		[theLayer addAnimation:fadeFrameAnimation forKey:nil];
	}
}

@end
