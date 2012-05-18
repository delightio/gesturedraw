//
//  ViewController.m
//  GestureCompositorMobile
//
//  Created by Bill So on 5/19/12.
//  Copyright (c) 2012 Headnix. All rights reserved.
//

#import "ViewController.h"
#import "TouchLayer.h"
#import <AssetsLibrary/AssetsLibrary.h>

static NSString * DLLocationXKey = @"x";
static NSString * DLLocationYKey = @"y";
static NSString * DLTouchIDKey = @"touchID";
static NSString * DLTouchSequenceNumKey = @"seq";
static NSString * DLTouchPhaseKey = @"phase";
static NSString * DLTouchTimeKey = @"time";
static NSString * DLTouchTapCountKey = @"tapCount";

#define DL_MINIMUM_DURATION 0.15

@interface ViewController ()

@end

@implementation ViewController
@synthesize player = _player;
@synthesize playerItem = _playerItem;
@synthesize sourceVideoAsset = _sourceVideoAsset;
@synthesize touches = _touches;
@synthesize playbackView = _playbackView;

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
	touchIDLayerMapping = [[NSMutableDictionary alloc] initWithCapacity:4];
	unassignedLayerBuffer = [[NSMutableSet alloc] initWithCapacity:4];

	NSURL * vdoFileURL = [[NSBundle mainBundle] URLForResource:@"158" withExtension:@"mp4"];
	self.sourceVideoAsset = [AVAsset assetWithURL:vdoFileURL];
	
	// Insert code here to initialize your application
	self.playerItem = [AVPlayerItem playerItemWithAsset:_sourceVideoAsset];
	self.player = [[AVPlayer alloc] initWithPlayerItem:_playerItem];
	_player.actionAtItemEnd = AVPlayerActionAtItemEndPause;
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleDidPlayNotification:) name:AVPlayerItemDidPlayToEndTimeNotification object:_playerItem];
	
	AVPlayerLayer * theLayer = [AVPlayerLayer playerLayerWithPlayer:_player];
	theLayer.frame = CGRectMake(0.0, 0.0, 320.0, 480.0);
	[_playbackView.layer addSublayer:theLayer];
	// create synchronized layer for video playback
	syncLayer = [AVSynchronizedLayer synchronizedLayerWithPlayerItem:_playerItem];
	//	syncLayer.bounds = CGRectMake(0.0, 0.0, vdoSize.width, vdoSize.height);
	syncLayer.frame = CGRectMake(0.0, 0.0, 320.0, 480.0);
	
	[_playbackView.layer addSublayer:syncLayer];

	NSData * propData = [NSData dataWithContentsOfURL:[[NSBundle mainBundle] URLForResource:@"touches-158" withExtension:@"plist"]];
	NSPropertyListFormat listFmt = 0;
	NSError * err = nil;
	self.touches = [NSPropertyListSerialization propertyListWithData:propData options:0 format:&listFmt error:&err];
//	[self setupGestureAnimationsForLayer:syncLayer];
}

- (void)viewDidUnload
{
    [self setPlaybackView:nil];
    [super viewDidUnload];
    // Release any retained subviews of the main view.
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
	return YES;
}

#pragma mark Composition

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
			[shapeLayer.pathValues addObject:[NSValue valueWithCGPoint:CGPointMake([[touchDict valueForKey:DLLocationXKey] floatValue], [[touchDict valueForKey:DLLocationYKey] floatValue])]];
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
			[shapeLayer.pathValues addObject:[NSValue valueWithCGPoint:CGPointMake([[touchDict valueForKey:DLLocationXKey] floatValue], [[touchDict valueForKey:DLLocationYKey] floatValue])]];
		}
		// set paths
		[shapeLayer.pathKeyTimes addObject:touchTime];
		// position of layer at time
		[shapeLayer.pathValues addObject:[NSValue valueWithCGPoint:CGPointMake([[touchDict valueForKey:DLLocationXKey] floatValue], [[touchDict valueForKey:DLLocationYKey] floatValue])]];
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

#pragma mark Target action
- (IBAction)playVideo:(id)sender {
	[_player play];
}

- (IBAction)exportVideo:(id)sender {
	// create composition from source
	AVMutableComposition * srcComposition = [AVMutableComposition composition];
	srcComposition.naturalSize = CGSizeMake(320.0, 480.0);
	AVMutableCompositionTrack * theTrack = [srcComposition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:10];
	[theTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, _sourceVideoAsset.duration) ofTrack:[[_sourceVideoAsset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0] atTime:kCMTimeZero error:nil];
	
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
	videoLayer.frame = CGRectMake(0.0, 0.0, 320.0, 480.0);
	parentLayer.frame = CGRectMake(0.0, 0.0, 320.0, 480.0);
	[parentLayer addSublayer:videoLayer];
	
	CALayer * testlayer = [CALayer layer];
	testlayer.frame = CGRectMake(0.0, 0.0, 100.0, 100.0);
	testlayer.backgroundColor = [UIColor greenColor].CGColor;
	
	[parentLayer addSublayer:testlayer];
	// create animation
	[self setupGestureAnimationsForLayer:parentLayer];
//	[_playbackView.layer addSublayer:parentLayer];
	videoComposition.animationTool = [AVVideoCompositionCoreAnimationTool videoCompositionCoreAnimationToolWithPostProcessingAsVideoLayer:videoLayer inLayer:parentLayer];
	//	videoComposition.animationTool = [AVVideoCompositionCoreAnimationTool videoCompositionCoreAnimationToolWithAdditionalLayer:parentLayer asTrackID:23];
	videoComposition.frameDuration = CMTimeMake(1, 30);
	videoComposition.renderSize = CGSizeMake(320.0, 480.0);
	
	NSString *filePath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"ExportedProject.mov"];
	[[NSFileManager defaultManager] removeItemAtPath:filePath error:NULL];
	session = [[AVAssetExportSession alloc] initWithAsset:srcComposition presetName:AVAssetExportPresetHighestQuality];
	session.videoComposition = videoComposition;
	session.outputURL = [NSURL fileURLWithPath:filePath];
	session.outputFileType = AVFileTypeQuickTimeMovie;
	
//	[session addObserver:self forKeyPath:@"status" options:0 context:NULL];
	
	[session exportAsynchronouslyWithCompletionHandler:^{
		NSLog(@"export completed");
		dispatch_async(dispatch_get_main_queue(), ^{
			NSURL *outputURL = session.outputURL;
			
			if ( session.status != AVAssetExportSessionStatusCompleted ) {
				NSLog(@"exportSession error:%@", session.error);
			}
			
			if ( session.status != AVAssetExportSessionStatusCompleted ) {
				return;
			}
						
			ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
			[library writeVideoAtPathToSavedPhotosAlbum:outputURL
										completionBlock:^(NSURL *assetURL, NSError *error) {
											[[NSFileManager defaultManager] removeItemAtURL:outputURL error:NULL];
											dispatch_async(dispatch_get_main_queue(), ^{
												NSLog(@"done");
											});
										}];
		});
	}];
}

- (void)handleDidPlayNotification:(NSNotification *)aNotification {
    [_player seekToTime:kCMTimeZero];
}

@end
