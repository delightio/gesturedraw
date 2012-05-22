//
//  AppDelegate.m
//  GestureCompositor
//
//  Created by Bill So on 5/11/12.
//  Copyright (c) 2012 Headnix. All rights reserved.
//

#import "AppDelegate.h"
#import "TouchLayer.h"
#import <crt_externs.h>

static NSString * DLLocationXKey = @"x";
static NSString * DLLocationYKey = @"y";
static NSString * DLTouchIDKey = @"touchID";
static NSString * DLTouchSequenceNumKey = @"seq";
static NSString * DLTouchPhaseKey = @"phase";
static NSString * DLTouchTimeKey = @"time";
static NSString * DLTouchTapCountKey = @"tapCount";

#define DL_MINIMUM_DURATION 0.15

@interface AppDelegate (PrivateMethods)

- (void)setupGestureAnimationsForLayer:(CALayer *)parentLayer;

@end

@implementation AppDelegate

@synthesize player = _player;
@synthesize playerItem = _playerItem;
@synthesize sourceVideoAsset = _sourceVideoAsset;
@synthesize touches = _touches;
@synthesize window = _window;
@synthesize playbackView = _playbackView;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	touchIDLayerMapping = [[NSMutableDictionary alloc] initWithCapacity:4];
	unassignedLayerBuffer = [[NSMutableSet alloc] initWithCapacity:4];
	// get file from command
	int argc = *_NSGetArgc();
	char ** argv = *_NSGetArgv();
	int c = 0;
	NSString * vdoFilePath = nil;
	NSString * plistFilePath = nil;
	
	while ( (c = getopt(argc, argv, "NSDocumentRevisionsDebugModep:f:")) != -1 ) {
		switch (c) {
			case 'f':
				if ( optarg ) {
					vdoFilePath = [NSString stringWithCString:optarg encoding:NSUTF8StringEncoding];
				}
				break;
			case 'p':
				if ( optarg ) {
					plistFilePath = [NSString stringWithCString:optarg encoding:NSUTF8StringEncoding];
				}
				break;
				
			default:
				break;
		}
	}
	self.sourceVideoAsset = [AVAsset assetWithURL:[NSURL fileURLWithPath:vdoFilePath]];

	// Insert code here to initialize your application
	self.playerItem = [AVPlayerItem playerItemWithAsset:_sourceVideoAsset];
	self.player = [[AVPlayer alloc] initWithPlayerItem:_playerItem];
	_player.actionAtItemEnd = AVPlayerActionAtItemEndPause;
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleDidPlayNotification:) name:AVPlayerItemDidPlayToEndTimeNotification object:_playerItem];
	
	CGSize vdoSize = _sourceVideoAsset.naturalSize;
	AVPlayerLayer * theLayer = [AVPlayerLayer playerLayerWithPlayer:_player];
	theLayer.frame = CGRectMake(0.0, 0.0, vdoSize.width, vdoSize.height);
	[_playbackView setLayer:theLayer];
	// create synchronized layer for video playback
	syncLayer = [AVSynchronizedLayer synchronizedLayerWithPlayerItem:_playerItem];
	syncLayer.anchorPoint = CGPointZero;
	syncLayer.frame = CGRectMake(0.0, 0.0, vdoSize.width, vdoSize.height);
	syncLayer.sublayerTransform = CATransform3DScale(CATransform3DIdentity, vdoSize.width / 320.0, vdoSize.height / 480.0, 1.0);
	[syncLayer setGeometryFlipped:YES];
	
	[_playbackView.layer addSublayer:syncLayer];
	
	// open the plist file
	if ( plistFilePath ) {
		NSData * propData = [NSData dataWithContentsOfFile:plistFilePath];
//		NSInputStream * inStream = [NSInputStream inputStreamWithFileAtPath:plistFilePath];
		NSPropertyListFormat listFmt = 0;
		NSError * err = nil;
		NSDictionary * touchInfo = [NSPropertyListSerialization propertyListWithData:propData options:0 format:&listFmt error:&err];
		self.touches = [touchInfo objectForKey:@"touches"];
		touchBounds = NSRectFromString([touchInfo objectForKey:@"touchBounds"]);
//		self.touches = [NSPropertyListSerialization propertyListWithStream:inStream options:0 format:&listFmt error:&err];
		[self setupGestureAnimationsForLayer:syncLayer];
	}
}

- (void)handleDidPlayNotification:(NSNotification *)aNotification {
    [_player seekToTime:kCMTimeZero];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
	if ( [keyPath isEqualToString:@"status"] ) {
		NSLog(@"%@", session.error);
	} else {
		[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
	}
}
- (IBAction)playPlainVideo:(id)sender {
	[_player play];
}

- (IBAction)exportVideo:(id)sender {
	// create composition from source
	AVMutableComposition * srcComposition = [AVMutableComposition composition];
	AVMutableCompositionTrack * theTrack = [srcComposition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:10];
	[theTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, _sourceVideoAsset.duration) ofTrack:[[_sourceVideoAsset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0] atTime:kCMTimeZero error:nil];
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
	gestureLayer.sublayerTransform = CATransform3DScale(CATransform3DIdentity, vdoSize.width / 320.0, vdoSize.height / 480.0, 1.0);
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
	
	NSString * path = [NSHomeDirectory() stringByAppendingPathComponent:@"Desktop/test.mov"];
	session = [[AVAssetExportSession alloc] initWithAsset:srcComposition presetName:AVAssetExportPreset640x480];
	session.shouldOptimizeForNetworkUse = YES;
	session.videoComposition = videoComposition;
	session.outputURL = [NSURL fileURLWithPath:path];
	session.outputFileType = AVFileTypeQuickTimeMovie;
	
	
	[session addObserver:self forKeyPath:@"status" options:0 context:NULL];
	
	[session exportAsynchronouslyWithCompletionHandler:^{
		NSLog(@"export completed");
	}];
}

- (TouchLayer *)layerForTouch:(NSDictionary *)aTouchDict parentLayer:(CALayer *)pLayer {
	NSNumber * aTouchID = [aTouchDict objectForKey:DLTouchIDKey];
	UITouchPhase ttype = [[aTouchDict objectForKey:DLTouchPhaseKey] integerValue];
	TouchLayer * shapeLayer = [touchIDLayerMapping objectForKey:aTouchID];
	if ( shapeLayer == nil ) {
		shapeLayer = [unassignedLayerBuffer anyObject];
		if ( shapeLayer ) {
			[unassignedLayerBuffer removeObject:shapeLayer];
		} else {
			// create the layer
			shapeLayer = [TouchLayer layer];
			[pLayer addSublayer:shapeLayer];
		}
		[touchIDLayerMapping setObject:shapeLayer forKey:aTouchID];
	} else {
		// check if the touch is the last touch
		if ( ttype == UITouchPhaseEnded || ttype == UITouchPhaseCancelled ) {
			// reclaim the layer back to buffer
			[unassignedLayerBuffer addObject:shapeLayer];
			[touchIDLayerMapping removeObjectForKey:aTouchID];
		}
	}
	return shapeLayer;
}

- (void)setupGestureAnimationsForLayer:(CALayer *)parentLayer {
	// draw the path from plist
	double vdoDuration = CMTimeGetSeconds(_playerItem.duration);
	UITouchPhase ttype;
	// opacity values array
	NSNumber * zeroNum = (NSNumber *)kCFBooleanFalse;
	NSNumber * oneNum = (NSNumber *)kCFBooleanTrue;
	NSNumber * touchTime = nil;
	NSNumber * fadeTimeNum = nil;
	double curTimeItval;
	TouchLayer * shapeLayer = nil;
	if ( parentLayer == nil ) parentLayer = syncLayer;
	for (NSDictionary * touchDict in _touches) {
		shapeLayer = [self layerForTouch:touchDict parentLayer:parentLayer];
		// setup the layer's position at time
		// time
		curTimeItval = [[touchDict objectForKey:DLTouchTimeKey] doubleValue];
		touchTime = [NSNumber numberWithDouble:curTimeItval / vdoDuration];
//		[shapeLayer.pathKeyTimes addObject:touchTime];
//		// position of layer at time
//		[shapeLayer.pathValues addObject:[NSValue valueWithPoint:NSMakePoint([[touchDict valueForKey:DLLocationXKey] floatValue], [[touchDict valueForKey:DLLocationYKey] floatValue])]];
		// fade in/out of dot
		ttype = [[touchDict objectForKey:DLTouchPhaseKey] integerValue];
		if ( ttype == UITouchPhaseBegan ) {
			shapeLayer.startTime = curTimeItval;
			// fade in effect
			// effect start time
			fadeTimeNum = [NSNumber numberWithDouble:(curTimeItval - 0.15) / vdoDuration];
			[shapeLayer.opacityKeyTimes addObject:fadeTimeNum];
			// effect end time
			[shapeLayer.opacityKeyTimes addObject:touchTime];
			[shapeLayer.opacityValues addObject:zeroNum];		// start value
			[shapeLayer.opacityValues addObject:oneNum];		// end value
			// make sure the dot is "in" the location when animation starts
			[shapeLayer.pathKeyTimes addObject:fadeTimeNum];
			[shapeLayer.pathValues addObject:[NSValue valueWithPoint:NSMakePoint([[touchDict valueForKey:DLLocationXKey] floatValue], [[touchDict valueForKey:DLLocationYKey] floatValue])]];
		} else if ( ttype == UITouchPhaseCancelled || ttype == UITouchPhaseEnded ) {
			if ( curTimeItval - shapeLayer.startTime < DL_MINIMUM_DURATION ) {
				// we need to show the dot for longer time so that it's visually visible
				curTimeItval = shapeLayer.startTime + DL_MINIMUM_DURATION;
				touchTime = [NSNumber numberWithDouble:curTimeItval / vdoDuration];
			}
			// fade out effect
			// effect start time
			[shapeLayer.opacityKeyTimes addObject:touchTime];
			// effect end time
			fadeTimeNum = [NSNumber numberWithDouble:(curTimeItval + 0.15) / vdoDuration];
			[shapeLayer.opacityKeyTimes addObject:fadeTimeNum];
			[shapeLayer.opacityValues addObject:oneNum];		// start value
			[shapeLayer.opacityValues addObject:zeroNum];		// end value
			// make sure the dot is not moving till animation is done
			[shapeLayer.pathKeyTimes addObject:fadeTimeNum];
			[shapeLayer.pathValues addObject:[NSValue valueWithPoint:NSMakePoint([[touchDict valueForKey:DLLocationXKey] floatValue], [[touchDict valueForKey:DLLocationYKey] floatValue])]];
		}
		// set paths
		[shapeLayer.pathKeyTimes addObject:touchTime];
		// position of layer at time
		[shapeLayer.pathValues addObject:[NSValue valueWithPoint:NSMakePoint([[touchDict valueForKey:DLLocationXKey] floatValue], [[touchDict valueForKey:DLLocationYKey] floatValue])]];
	}
	for (TouchLayer * theLayer in unassignedLayerBuffer) {
		CAKeyframeAnimation * dotFrameAnimation = [CAKeyframeAnimation animationWithKeyPath:@"position"];
		CAKeyframeAnimation * fadeFrameAnimation = [CAKeyframeAnimation animationWithKeyPath:@"opacity"];
		dotFrameAnimation.values = theLayer.pathValues;
		dotFrameAnimation.keyTimes = theLayer.pathKeyTimes;
		dotFrameAnimation.beginTime = AVCoreAnimationBeginTimeAtZero;
		dotFrameAnimation.duration = vdoDuration;
		dotFrameAnimation.removedOnCompletion = NO;
		
		fadeFrameAnimation.values = theLayer.opacityValues;
		fadeFrameAnimation.keyTimes = theLayer.opacityKeyTimes;
		fadeFrameAnimation.beginTime = AVCoreAnimationBeginTimeAtZero;
		fadeFrameAnimation.duration = vdoDuration;
		fadeFrameAnimation.removedOnCompletion = NO;
		
		[theLayer addAnimation:fadeFrameAnimation forKey:@"fadeAnimation"];
		[theLayer addAnimation:dotFrameAnimation forKey:@"positionAnimation"];
	}
}

@end
