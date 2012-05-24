//
//  AppDelegate.h
//  GestureCompositor
//
//  Created by Bill So on 5/11/12.
//  Copyright (c) 2012 Headnix. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface AppDelegate : NSObject <NSApplicationDelegate> {
	__strong NSMutableDictionary * touchIDLayerMapping;
	__strong NSMutableSet * unassignedLayerBuffer;
	__strong AVSynchronizedLayer * syncLayer;
	__strong AVAssetExportSession * session;
	NSRect touchBounds;
}

@property (nonatomic, strong) AVPlayer * player;
@property (nonatomic, strong) AVPlayerItem * playerItem;
@property (nonatomic, strong) AVAsset * sourceVideoAsset;
@property (nonatomic, strong) NSArray * touches;
@property (nonatomic, assign) IBOutlet NSWindow *window;
@property (nonatomic, weak) IBOutlet NSView *playbackView;

@property (nonatomic, strong) NSString * videoPath;
@property (nonatomic, strong) NSString * touchesPath;
@property (nonatomic, strong) NSString * exportPath;

- (IBAction)playPlainVideo:(id)sender;
- (IBAction)exportVideo:(id)sender;

@end
