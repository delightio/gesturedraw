//
//  AppDelegate.h
//  GestureCompositor
//
//  Created by Bill So on 5/11/12.
//  Copyright (c) 2012 Headnix. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface AppDelegate : NSObject <NSApplicationDelegate>

@property (strong) AVPlayer * player;
@property (strong) AVAsset * sourceVideoAsset;
@property (assign) IBOutlet NSWindow *window;
@property (weak) IBOutlet NSView *playbackView;

- (IBAction)playPlainVideo:(id)sender;

@end
