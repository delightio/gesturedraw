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

- (void)setupGestuerAnimations;

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
	
	AVPlayerLayer * theLayer = [AVPlayerLayer playerLayerWithPlayer:_player];
	theLayer.frame = _playbackView.bounds;
	[_playbackView setLayer:theLayer];
	// create synchronized layer for video playback
	syncLayer = [AVSynchronizedLayer synchronizedLayerWithPlayerItem:_playerItem];
	//	syncLayer.bounds = CGRectMake(0.0, 0.0, vdoSize.width, vdoSize.height);
	syncLayer.frame = CGRectMake(0.0, 0.0, 320.0, 480.0);
	[syncLayer setGeometryFlipped:YES];
	
	[_playbackView.layer addSublayer:syncLayer];
	
	// open the plist file
	if ( plistFilePath ) {
		NSData * propData = [NSData dataWithContentsOfFile:plistFilePath];
//		NSInputStream * inStream = [NSInputStream inputStreamWithFileAtPath:plistFilePath];
		NSPropertyListFormat listFmt = 0;
		NSError * err = nil;
		self.touches = [NSPropertyListSerialization propertyListWithData:propData options:0 format:&listFmt error:&err];
//		self.touches = [NSPropertyListSerialization propertyListWithStream:inStream options:0 format:&listFmt error:&err];
		[self setupGestuerAnimations];
	}
}

- (void)handleDidPlayNotification:(NSNotification *)aNotification {
    [_player seekToTime:kCMTimeZero];
}

- (IBAction)playPlainVideo:(id)sender {
	[_player play];
}

- (TouchLayer *)layerForTouch:(NSDictionary *)aTouchDict {
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
			CGPathRef cirPath = CGPathCreateWithEllipseInRect(CGRectMake(0.0, 0.0, 22.0, 22.0), NULL);
			shapeLayer.lineWidth = 0.0;
			shapeLayer.opacity = 0.0;
			CGColorRef redColor = CGColorCreateGenericRGB(1.0, 0.0, 0.0, 1.0);
			shapeLayer.fillColor = redColor;
			CGColorRelease(redColor);
			
			shapeLayer.path = cirPath;
			CGPathRelease(cirPath);
			[syncLayer addSublayer:shapeLayer];
		}
		[touchIDLayerMapping setObject:shapeLayer forKey:aTouchID];
		if ( [touchIDLayerMapping count] > 1 ) {
			NSLog(@"more than one touches");
		}
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

- (void)setupGestuerAnimations {
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
	for (NSDictionary * touchDict in _touches) {
		shapeLayer = [self layerForTouch:touchDict];
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
