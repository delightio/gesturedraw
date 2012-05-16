//
//  AppDelegate.m
//  GestureCompositor
//
//  Created by Bill So on 5/11/12.
//  Copyright (c) 2012 Headnix. All rights reserved.
//

#import "AppDelegate.h"
#import <crt_externs.h>

static NSString * DLLocationXKey = @"x";
static NSString * DLLocationYKey = @"y";
static NSString * DLTouchPhaseKey = @"phase";
static NSString * DLTouchTimeKey = @"timeInSession";

@implementation AppDelegate

@synthesize player = _player;
@synthesize playerItem = _playerItem;
@synthesize sourceVideoAsset = _sourceVideoAsset;
@synthesize touches = _touches;
@synthesize window = _window;
@synthesize playbackView = _playbackView;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
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
	
	// open the plist file
	if ( plistFilePath ) {
		NSData * propData = [NSData dataWithContentsOfFile:plistFilePath];
//		NSInputStream * inStream = [NSInputStream inputStreamWithFileAtPath:plistFilePath];
		NSPropertyListFormat listFmt = 0;
		NSError * err = nil;
		self.touches = [NSPropertyListSerialization propertyListWithData:propData options:0 format:&listFmt error:&err];
//		self.touches = [NSPropertyListSerialization propertyListWithStream:inStream options:0 format:&listFmt error:&err];
	}
}

- (void)handleDidPlayNotification:(NSNotification *)aNotification {
    [_player seekToTime:kCMTimeZero];
}

- (IBAction)playPlainVideo:(id)sender {
	[_player play];
}

- (IBAction)playWithGesture:(id)sender {
	// create the layer
	CAShapeLayer * shapeLayer = [CAShapeLayer layer];
	CGPathRef cirPath = CGPathCreateWithEllipseInRect(CGRectMake(0.0, 0.0, 22.0, 22.0), NULL);
	shapeLayer.lineWidth = 0.0;
	shapeLayer.opacity = 0.0;
	CGColorRef redColor = CGColorCreateGenericRGB(1.0, 0.0, 0.0, 1.0);
	shapeLayer.fillColor = redColor;
	CGColorRelease(redColor);
	
	shapeLayer.path = cirPath;
	CGPathRelease(cirPath);
	
	// create synchronized layer for video playback
	AVSynchronizedLayer * syncLayer = [AVSynchronizedLayer synchronizedLayerWithPlayerItem:_playerItem];
//	syncLayer.bounds = CGRectMake(0.0, 0.0, vdoSize.width, vdoSize.height);
	syncLayer.frame = CGRectMake(0.0, 0.0, 320.0, 480.0);
	[syncLayer addSublayer:shapeLayer];
	
	[_playbackView.layer addSublayer:syncLayer];
	
	// draw the path from plist
	double vdoDuration = CMTimeGetSeconds(_playerItem.duration);
	UITouchPhase ttype;
	CAKeyframeAnimation * dotFrameAnimation = [CAKeyframeAnimation animationWithKeyPath:@"position"];
	CAKeyframeAnimation * fadeFrameAnimation = [CAKeyframeAnimation animationWithKeyPath:@"opacity"];
	NSUInteger c = [_touches count];
	// initialization
	// key times array
	NSMutableArray * theTimes = [NSMutableArray arrayWithCapacity:c];
	// positions array
	NSMutableArray * thePositions = [NSMutableArray arrayWithCapacity:c];
	// opacity values array
	NSMutableArray * opacTimes = [NSMutableArray arrayWithCapacity:10];
	NSMutableArray * opacValues = [NSMutableArray arrayWithCapacity:10];
	NSNumber * zeroNum = (NSNumber *)kCFBooleanFalse;
	NSNumber * oneNum = (NSNumber *)kCFBooleanTrue;
	NSNumber * touchTime;
	double curTimeItval;
	for (NSDictionary * touchDict in _touches) {
		// time
		curTimeItval = [[touchDict objectForKey:DLTouchTimeKey] doubleValue];
		touchTime = [NSNumber numberWithDouble:curTimeItval / vdoDuration];
		[theTimes addObject:touchTime];
		// position of layer at time
		[thePositions addObject:[NSValue valueWithPoint:NSMakePoint([[touchDict valueForKey:DLLocationXKey] floatValue], [[touchDict valueForKey:DLLocationYKey] floatValue])]];
		// fade in/out of dot
		ttype = [[touchDict objectForKey:DLTouchPhaseKey] integerValue];
		if ( ttype == UITouchPhaseBegan ) {
			// fade in effect
			// effect start time
			[opacTimes addObject:[NSNumber numberWithDouble:([[touchDict objectForKey:DLTouchTimeKey] doubleValue] - 0.15) / vdoDuration]];
			// effect end time
			[opacTimes addObject:touchTime];
			[opacValues addObject:zeroNum];		// start value
			[opacValues addObject:oneNum];		// end value
		} else if ( ttype == UITouchPhaseCancelled || ttype == UITouchPhaseEnded ) {
			// fade out effect
			// effect start time
			[opacTimes addObject:touchTime];
			// effect end time
			[opacTimes addObject:[NSNumber numberWithDouble:(curTimeItval + 0.15) / vdoDuration]];
			[opacValues addObject:oneNum];		// start value
			[opacValues addObject:zeroNum];		// end value
		}
	}
	
	dotFrameAnimation.values = thePositions;
	dotFrameAnimation.keyTimes = theTimes;
	dotFrameAnimation.beginTime = AVCoreAnimationBeginTimeAtZero;
	dotFrameAnimation.duration = vdoDuration;
	dotFrameAnimation.removedOnCompletion = NO;
	
	fadeFrameAnimation.values = opacValues;
	fadeFrameAnimation.keyTimes = opacTimes;
	fadeFrameAnimation.beginTime = AVCoreAnimationBeginTimeAtZero;
	fadeFrameAnimation.duration = vdoDuration;
	fadeFrameAnimation.removedOnCompletion = NO;
	
	[shapeLayer addAnimation:fadeFrameAnimation forKey:@"fadeAnimation"];
	[shapeLayer addAnimation:dotFrameAnimation forKey:@"positionAnimation"];
}

@end
