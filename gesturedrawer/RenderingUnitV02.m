//
//  RenderingUnitV02.m
//  gesturedrawer
//
//  Created by Bill So on 5/29/12.
//  Copyright (c) 2012 Headnix. All rights reserved.
//

#import "TouchLayer.h"
#import "RenderingUnitV02.h"

#define DL_MINIMUM_DURATION 0.15

@implementation RenderingUnitV02

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

- (void)setupGestureAnimationsForLayer:(CALayer *)parentLayer {
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
	for (NSDictionary * touchDict in touches) {
		shapeLayer = [self layerForTouch:touchDict parentLayer:parentLayer];
		if ( shapeLayer == nil ) continue;
		// setup the layer's position at time
		// time
		curTimeItval = [[touchDict objectForKey:DLTouchTimeKey] doubleValue];
		touchTime = [NSNumber numberWithDouble:curTimeItval / videoDuration];
		// fade in/out of dot
		ttype = [[touchDict objectForKey:DLTouchPhaseKey] integerValue];
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
	if ( [onscreenLayerBuffer count] ) {
		[unassignedLayerBuffer addObjectsFromArray:onscreenLayerBuffer];
		[onscreenLayerBuffer removeAllObjects];
	}
	for (TouchLayer * theLayer in unassignedLayerBuffer) {
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
