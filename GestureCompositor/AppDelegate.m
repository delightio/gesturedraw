//
//  AppDelegate.m
//  GestureCompositor
//
//  Created by Bill So on 5/11/12.
//  Copyright (c) 2012 Headnix. All rights reserved.
//

#import "AppDelegate.h"
#import "TouchLayer.h"
#import "RenderingUnitV01.h"
#import "RenderingUnitV02.h"
#import <crt_externs.h>


@interface AppDelegate (PrivateMethods)

- (void)setupGestureAnimationsForLayer:(CALayer *)parentLayer;

@end

@implementation AppDelegate

@synthesize player = _player;
@synthesize playerItem = _playerItem;
@synthesize sourceVideoAsset = _sourceVideoAsset;
@synthesize touchInfo = _touchInfo;
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
				if ( optarg && _exportPath == nil) {
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
	
	// read the touches
	NSData * propData = [NSData dataWithContentsOfFile:_touchesPath];
	NSPropertyListFormat listFmt = 0;
	NSError * err = nil;
	self.touchInfo = [NSPropertyListSerialization propertyListWithData:propData options:0 format:&listFmt error:&err];
	NSString * fmtVersion = [_touchInfo objectForKey:@"formatVersion"];
	if ( fmtVersion == nil ) {
		NSLog(@"no version number in plist file");
		[NSApp terminate:nil];
	}
	RenderingUnit * rndUnit = nil;
	if ( [fmtVersion isEqualToString:@"0.1"] ) {
		rndUnit = [[RenderingUnitV01 alloc] initWithVideoAtPath:_videoPath destinationPath:_exportPath touchesPropertyList:_touchInfo];
	} else if ( [fmtVersion isEqualToString:@"0.2"] ) {
		rndUnit = [[RenderingUnitV02 alloc] initWithVideoAtPath:_videoPath destinationPath:_exportPath touchesPropertyList:_touchInfo];
	} else {
		NSLog(@"wrong plist file version, expect version 0.1 or 0.2");
		[NSApp terminate:nil];
	}
	// setup rendering unit
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
	RenderingUnit * rndUnit = nil;
	NSString * fmtVersion = [_touchInfo objectForKey:@"formatVersion"];
	if ( [fmtVersion isEqualToString:@"0.1"] ) {
		rndUnit = [[RenderingUnitV01 alloc] initWithVideoAtPath:_videoPath destinationPath:_exportPath touchesPropertyList:_touchInfo];
	} else if ( [fmtVersion isEqualToString:@"0.2"] ) {
		rndUnit = [[RenderingUnitV02 alloc] initWithVideoAtPath:_videoPath destinationPath:_exportPath touchesPropertyList:_touchInfo];
	}
	[rndUnit exportVideoWithCompletionHandler:^{
		NSLog(@"export done");
	}];
}

@end
