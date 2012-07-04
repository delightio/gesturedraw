//
//  RenderingUnit.m
//  gesturedrawer
//
//  Created by Bill So on 5/22/12.
//  Copyright (c) 2012 Headnix. All rights reserved.
//

#import "TouchLayer.h"
#import "RenderingUnitV01.h"

#define DL_MINIMUM_DURATION 0.15
#define DL_STATUS_CONTEXT	1001

@implementation RenderingUnitV01

- (id)initWithVideoAtPath:(NSString *)vdoPath destinationPath:(NSString *)dstPath touchesPropertyList:(NSDictionary *)tchPlist {
	self = [super initWithVideoAtPath:vdoPath destinationPath:dstPath touchesPropertyList:tchPlist];
	onscreenDotLayerBuffer = [[NSMutableArray alloc] initWithCapacity:2];
	unassignedDotLayerBuffer = [[NSMutableArray alloc] initWithCapacity:2];
	
	return self;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
	NSInteger ctxInt = (NSInteger)context;
	if ( ctxInt == DL_STATUS_CONTEXT ) {
		NSLog(@"status: %ld error: %@", session.status, session.error);
	} else {
		[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
	}
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

- (TouchLayer *)layerForTouch:(NSDictionary *)aTouchDict {
	UITouchPhase ttype = (UITouchPhase)[[aTouchDict objectForKey:DLTouchPhaseKey] integerValue];
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
				[self.parentLayer addSublayer:shapeLayer];
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
					[self.parentLayer addSublayer:shapeLayer];
				}
				[onscreenDotLayerBuffer addObject:shapeLayer];
			}
			break;
	}
	return shapeLayer;
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
	[assetReader addOutput:videoCompositionOutput];
	
	[assetWriter addInput:videoInput];
	assetWriter.shouldOptimizeForNetworkUse = YES;
	BOOL success = NO;
	[assetReader startReading];
	success = [assetWriter startWriting];
	[assetWriter startSessionAtSourceTime:kCMTimeZero];
	[videoInput requestMediaDataWhenReadyOnQueue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0) usingBlock:^{
		while (videoInput.readyForMoreMediaData) {
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
	
	//	session = [[AVAssetExportSession alloc] initWithAsset:srcComposition presetName:AVAssetExportPreset640x480];
	//	session.shouldOptimizeForNetworkUse = YES;
	//	session.videoComposition = videoComposition;
	//	session.outputURL = [NSURL fileURLWithPath:_destinationFilePath];
	//	session.outputFileType = AVFileTypeQuickTimeMovie;
	//	
	////	[session addObserver:self forKeyPath:@"status" options:0 context:(void *)DL_STATUS_CONTEXT];
	//	
	//	[session exportAsynchronouslyWithCompletionHandler:^{
	//		NSLog(@"video exported - %@ %@", _destinationFilePath, session.status == AVAssetExportSessionStatusFailed ? session.error : @"no error");
	//		handler();
	//	}];
}

- (void)setupGestureAnimationsForLayer:(CALayer *)prnLayer {
	// draw the path from plist
	UITouchPhase ttype;
	// opacity values array
	NSNumber * zeroNum = (NSNumber *)kCFBooleanFalse;
	NSNumber * oneNum = (NSNumber *)kCFBooleanTrue;
	NSNumber * touchTime = nil;
	NSNumber * fadeTimeNum = nil;
	double curTimeItval;
	TouchLayer * shapeLayer = nil;
	NSValue * curPointVal = nil;
	NSPoint curPoint;
	self.parentLayer = prnLayer;
	for (NSDictionary * touchDict in touches) {
		shapeLayer = [self layerForTouch:touchDict];
		if ( shapeLayer == nil ) continue;
		// setup the layer's position at time
		// time
		curTimeItval = [[touchDict objectForKey:DLTouchTimeKey] doubleValue];
		touchTime = [NSNumber numberWithDouble:curTimeItval / videoDuration];
		// fade in/out of dot
		ttype = (UITouchPhase)[[touchDict objectForKey:DLTouchPhaseKey] integerValue];
		curPoint = NSPointFromString([touchDict objectForKey:DLTouchCurrentLocationKey]);
		curPointVal = [NSValue valueWithPoint:curPoint];
		if ( ttype == UITouchPhaseBegan ) {
			shapeLayer.startTime = curTimeItval;
			// fade in effect
			// effect start time
			fadeTimeNum = [NSNumber numberWithDouble:(curTimeItval - 0.15) / videoDuration];
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
			fadeTimeNum = [NSNumber numberWithDouble:(curTimeItval + 0.15) / videoDuration];
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
}

@end
