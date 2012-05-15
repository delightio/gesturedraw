//
//  AppDelegate.m
//  GestureCompositor
//
//  Created by Bill So on 5/11/12.
//  Copyright (c) 2012 Headnix. All rights reserved.
//

#import "AppDelegate.h"
#import <crt_externs.h>

static NSString * DLLocationXKeyPath = @"location.x";
static NSString * DLLocationYKeyPath = @"location.y";
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

- (IBAction)playPlainVideo:(id)sender {
	[_player play];
}

- (IBAction)playWithGesture:(id)sender {
	// create the layer
	CAShapeLayer * shapeLayer = [CAShapeLayer layer];
	CGPathRef cirPath = CGPathCreateWithEllipseInRect(CGRectMake(0.0, 0.0, 22.0, 22.0), NULL);
	shapeLayer.lineWidth = 0.0;
//	shapeLayer.opacity = 0.0;
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
	NSTimeInterval startTime, endTime;
	CAKeyframeAnimation * frameAnimation = [CAKeyframeAnimation animationWithKeyPath:@"position"];
	NSUInteger c = [_touches count];
	// initialize - time
	NSMutableArray * theTimes = [NSMutableArray arrayWithCapacity:c];
	// initialize - position
	NSMutableArray * thePositions = [NSMutableArray arrayWithCapacity:c];
	for (NSDictionary * touchDict in _touches) {
		// time
		[theTimes addObject:[NSNumber numberWithDouble:[[touchDict objectForKey:DLTouchTimeKey] doubleValue] / vdoDuration]];
		// position of layer at time
		[thePositions addObject:[NSValue valueWithPoint:NSMakePoint([[touchDict valueForKeyPath:DLLocationXKeyPath] floatValue], [[touchDict valueForKeyPath:DLLocationYKeyPath] floatValue])]];
//		ttype = [[touchDict objectForKey:DLTouchPhaseKey] integerValue];
//		if ( ttype == UITouchPhaseBegan ) {
//			startTime = [[touchDict objectForKey:DLTouchTimeKey] doubleValue];
//		} else if ( ttype == UITouchPhaseCancelled || ttype == UITouchPhaseEnded ) {
//			endTime = [[touchDict objectForKey:DLTouchTimeKey] doubleValue];
//		}
	}
	
	frameAnimation.values = thePositions;
	frameAnimation.keyTimes = theTimes;
	frameAnimation.beginTime = AVCoreAnimationBeginTimeAtZero;
	frameAnimation.duration = vdoDuration;
	frameAnimation.removedOnCompletion = NO;
	[shapeLayer addAnimation:frameAnimation forKey:nil];
}

@end
