//
//  AppDelegate.m
//  GestureCompositor
//
//  Created by Bill So on 5/11/12.
//  Copyright (c) 2012 Headnix. All rights reserved.
//

#import "AppDelegate.h"
#import "TouchLayer.h"
#import "RenderingUnit.h"
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

@synthesize videoPath = _videoPath;
@synthesize touchesPath = _touchesPath;
@synthesize exportPath = _exportPath;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	touchIDLayerMapping = [[NSMutableDictionary alloc] initWithCapacity:4];
	unassignedLayerBuffer = [[NSMutableSet alloc] initWithCapacity:4];
	// get file from command
	int argc = *_NSGetArgc();
	char ** argv = *_NSGetArgv();
	int c = 0;
	
	while ( (c = getopt(argc, argv, "NSDocumentRevisionsDebugMod:ep:f:")) != -1 ) {
		switch (c) {
			case 'f':
				if ( optarg ) {
					self.videoPath = [NSString stringWithCString:optarg encoding:NSUTF8StringEncoding];
				}
				break;
			case 'p':
				if ( optarg ) {
					self.touchesPath = [NSString stringWithCString:optarg encoding:NSUTF8StringEncoding];
				}
				break;
				
			case 'd':
				if ( optarg ) {
					self.exportPath = [NSString stringWithCString:optarg encoding:NSUTF8StringEncoding];
				}
				break;
				
			default:
				break;
		}
	}
	self.sourceVideoAsset = [AVAsset assetWithURL:[NSURL fileURLWithPath:_videoPath]];

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
	// setup rendering unit
	RenderingUnit * rndUnit = [[RenderingUnit alloc] initWithVideoAtPath:_videoPath touchesPListPath:_touchesPath destinationPath:_exportPath];
	NSRect theRect = rndUnit.touchBounds;
	rndUnit.videoDuration = CMTimeGetSeconds(_sourceVideoAsset.duration);
	
	syncLayer.sublayerTransform = CATransform3DScale(CATransform3DIdentity, vdoSize.width / theRect.size.width, vdoSize.height / theRect.size.height, 1.0);
	[syncLayer setGeometryFlipped:YES];
	
//	CGColorRef redColor = CGColorCreateGenericRGB(1.0, 0.0, 0.0, 0.25);
//	syncLayer.backgroundColor = redColor;
//	CGColorRelease(redColor);
	
	[_playbackView.layer addSublayer:syncLayer];
	
	[rndUnit setupGestureAnimationsForLayer:syncLayer];
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
	RenderingUnit * rndUnit = [[RenderingUnit alloc] initWithVideoAtPath:_videoPath touchesPListPath:_touchesPath destinationPath:_exportPath];
	[rndUnit exportVideoWithCompletionHandler:^{
		NSLog(@"export done");
	}];
}

@end
