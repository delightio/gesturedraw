//
//  AppDelegate.m
//  GestureCompositor
//
//  Created by Bill So on 5/11/12.
//  Copyright (c) 2012 Headnix. All rights reserved.
//

#import "AppDelegate.h"
#import <crt_externs.h>

@implementation AppDelegate

@synthesize player = _player;
@synthesize sourceVideoAsset = _sourceVideoAsset;
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
	self.player = [[AVPlayer alloc] initWithPlayerItem:[AVPlayerItem playerItemWithAsset:_sourceVideoAsset]];
	
	AVPlayerLayer * theLayer = [AVPlayerLayer playerLayerWithPlayer:_player];
	theLayer.frame = _playbackView.bounds;
	[_playbackView setLayer:theLayer];
}

- (IBAction)playPlainVideo:(id)sender {
	[_player play];
}

@end
