//
//  RenderingUnit.m
//  gesturedrawer
//
//  Created by Bill So on 5/22/12.
//  Copyright (c) 2012 Headnix. All rights reserved.
//

#import "TouchLayer.h"
#import "RenderingUnit.h"

static NSString * DLTouchCurrentLocationKey = @"curLoc";
static NSString * DLTouchPreviousLocationKey = @"prevLoc";
static NSString * DLTouchSequenceNumKey = @"seq";
static NSString * DLTouchPhaseKey = @"phase";
static NSString * DLTouchTimeKey = @"time";
static NSString * DLTouchTapCountKey = @"tapCount";

#define DL_MINIMUM_DURATION 0.15
#define DL_STATUS_CONTEXT	1001

@implementation RenderingUnit
@synthesize sourceFilePath = _sourceFilePath;
@synthesize touchesFilePath = _touchesFilePath;
@synthesize destinationFilePath = _destinationFilePath;
@synthesize touches = _touches;
@synthesize touchBounds = _touchBounds;
@synthesize videoDuration = _videoDuration;

- (id)initWithVideoAtPath:(NSString *)vdoPath touchesPListPath:(NSString *)tchPath destinationPath:(NSString *)dstPath {
	self = [super init];
	onscreenLayerBuffer = [[NSMutableArray alloc] initWithCapacity:2];
	unassignedLayerBuffer = [[NSMutableArray alloc] initWithCapacity:2];
	_sourceFilePath = vdoPath;
	_touchesFilePath = tchPath;
	_destinationFilePath = dstPath;
	// read the touches
	NSData * propData = [NSData dataWithContentsOfFile:_touchesFilePath];
	NSPropertyListFormat listFmt = 0;
	NSError * err = nil;
	NSDictionary * touchInfo = [NSPropertyListSerialization propertyListWithData:propData options:0 format:&listFmt error:&err];
	NSString * fmtVersion = [touchInfo objectForKey:@"formatVersion"];
	if ( fmtVersion == nil || ![fmtVersion isEqualToString:@"0.1"]) {
		NSLog(@"wrong plist file version, expect version 0.1");
		[NSApp terminate:nil];
	}
	self.touches = [touchInfo objectForKey:@"touches"];
	_touchBounds = NSRectFromString([touchInfo objectForKey:@"touchBounds"]);
	
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

- (void)exportVideoWithCompletionHandler:(void (^)(void))handler {
	AVAsset * srcVdoAsset = [AVAsset assetWithURL:[NSURL fileURLWithPath:_sourceFilePath]];
	_videoDuration = CMTimeGetSeconds(srcVdoAsset.duration);
	// create composition from source
	AVMutableComposition * srcComposition = [AVMutableComposition composition];
	AVMutableCompositionTrack * theTrack = [srcComposition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:10];
	[theTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, srcVdoAsset.duration) ofTrack:[[srcVdoAsset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0] atTime:kCMTimeZero error:nil];
	CGSize vdoSize = srcComposition.naturalSize;
	
	// build "pass through video track"
	AVMutableVideoComposition * videoComposition = [AVMutableVideoComposition videoComposition];
	AVMutableVideoCompositionInstruction *passThroughInstruction = [AVMutableVideoCompositionInstruction videoCompositionInstruction];
	passThroughInstruction.timeRange = CMTimeRangeMake(kCMTimeZero, [srcComposition duration]);
	
	AVAssetTrack *videoTrack = [[srcComposition tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0];
	AVMutableVideoCompositionLayerInstruction *passThroughLayer = [AVMutableVideoCompositionLayerInstruction videoCompositionLayerInstructionWithAssetTrack:videoTrack];
	
	passThroughInstruction.layerInstructions = [NSArray arrayWithObject:passThroughLayer];
	videoComposition.instructions = [NSArray arrayWithObject:passThroughInstruction];
	
	// prepare animation
	CALayer * videoLayer = [CALayer layer];
	CALayer * parentLayer = [CALayer layer];
	CALayer * gestureLayer = [CALayer layer];
	[parentLayer addSublayer:videoLayer];
	[parentLayer addSublayer:gestureLayer];
	
	[gestureLayer setGeometryFlipped:YES];
	gestureLayer.sublayerTransform = CATransform3DScale(CATransform3DIdentity, vdoSize.width / _touchBounds.size.width, vdoSize.height / _touchBounds.size.height, 1.0);
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
	
	session = [[AVAssetExportSession alloc] initWithAsset:srcComposition presetName:AVAssetExportPreset640x480];
	session.shouldOptimizeForNetworkUse = YES;
	session.videoComposition = videoComposition;
	session.outputURL = [NSURL fileURLWithPath:_destinationFilePath];
	session.outputFileType = AVFileTypeQuickTimeMovie;
	
//	[session addObserver:self forKeyPath:@"status" options:0 context:(void *)DL_STATUS_CONTEXT];
	
	[session exportAsynchronouslyWithCompletionHandler:^{
		NSLog(@"video exported - %@ %@", _destinationFilePath, session.status == AVAssetExportSessionStatusFailed ? session.error : @"no error");
		handler();
	}];
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
	for (NSDictionary * touchDict in _touches) {
		shapeLayer = [self layerForTouch:touchDict parentLayer:parentLayer];
		if ( shapeLayer == nil ) break;
		// setup the layer's position at time
		// time
		curTimeItval = [[touchDict objectForKey:DLTouchTimeKey] doubleValue];
		touchTime = [NSNumber numberWithDouble:curTimeItval / _videoDuration];
		// fade in/out of dot
		ttype = [[touchDict objectForKey:DLTouchPhaseKey] integerValue];
		curPoint = NSPointFromString([touchDict objectForKey:DLTouchCurrentLocationKey]);
		curPointVal = [NSValue valueWithPoint:curPoint];
		if ( ttype == UITouchPhaseBegan ) {
			shapeLayer.startTime = curTimeItval;
			// fade in effect
			// effect start time
			fadeTimeNum = [NSNumber numberWithDouble:(curTimeItval - 0.15) / _videoDuration];
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
				touchTime = [NSNumber numberWithDouble:curTimeItval / _videoDuration];
			}
			// fade out effect
			// effect start time
			[shapeLayer.opacityKeyTimes addObject:touchTime];
			// effect end time
			fadeTimeNum = [NSNumber numberWithDouble:(curTimeItval + 0.15) / _videoDuration];
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
	for (TouchLayer * theLayer in unassignedLayerBuffer) {
		CAKeyframeAnimation * dotFrameAnimation = [CAKeyframeAnimation animationWithKeyPath:@"position"];
		CAKeyframeAnimation * fadeFrameAnimation = [CAKeyframeAnimation animationWithKeyPath:@"opacity"];
		dotFrameAnimation.values = theLayer.pathValues;
		dotFrameAnimation.keyTimes = theLayer.pathKeyTimes;
		dotFrameAnimation.beginTime = AVCoreAnimationBeginTimeAtZero;
		dotFrameAnimation.duration = _videoDuration;
		dotFrameAnimation.removedOnCompletion = NO;
		
		fadeFrameAnimation.values = theLayer.opacityValues;
		fadeFrameAnimation.keyTimes = theLayer.opacityKeyTimes;
		fadeFrameAnimation.beginTime = AVCoreAnimationBeginTimeAtZero;
		fadeFrameAnimation.duration = _videoDuration;
		fadeFrameAnimation.removedOnCompletion = NO;
		
		[theLayer addAnimation:fadeFrameAnimation forKey:@"fadeAnimation"];
		[theLayer addAnimation:dotFrameAnimation forKey:@"positionAnimation"];
	}
}

@end
