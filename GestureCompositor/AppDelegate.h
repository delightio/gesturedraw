//
//  AppDelegate.h
//  GestureCompositor
//
//  Created by Bill So on 5/11/12.
//  Copyright (c) 2012 Headnix. All rights reserved.
//

#import <Cocoa/Cocoa.h>

typedef enum {
    UITouchPhaseBegan,             // whenever a finger touches the surface.
    UITouchPhaseMoved,             // whenever a finger moves on the surface.
    UITouchPhaseStationary,        // whenever a finger is touching the surface but hasn't moved since the previous event.
    UITouchPhaseEnded,             // whenever a finger leaves the surface.
    UITouchPhaseCancelled,         // whenever a touch doesn't end but we need to stop tracking (e.g. putting device to face)
} UITouchPhase;

@interface AppDelegate : NSObject <NSApplicationDelegate> {
	__strong NSMutableDictionary * touchIDLayerMapping;
	__strong NSMutableSet * unassignedLayerBuffer;
	__strong AVSynchronizedLayer * syncLayer;
}

@property (nonatomic, strong) AVPlayer * player;
@property (nonatomic, strong) AVPlayerItem * playerItem;
@property (nonatomic, strong) AVAsset * sourceVideoAsset;
@property (nonatomic, strong) NSArray * touches;
@property (nonatomic, assign) IBOutlet NSWindow *window;
@property (nonatomic, weak) IBOutlet NSView *playbackView;

- (IBAction)playPlainVideo:(id)sender;

@end
