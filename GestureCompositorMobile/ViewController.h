//
//  ViewController.h
//  GestureCompositorMobile
//
//  Created by Bill So on 5/19/12.
//  Copyright (c) 2012 Headnix. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

@interface ViewController : UIViewController {
	__strong NSMutableDictionary * touchIDLayerMapping;
	__strong NSMutableSet * unassignedLayerBuffer;
	__strong AVSynchronizedLayer * syncLayer;
	__strong AVAssetExportSession * session;
}
@property (nonatomic, strong) AVPlayer * player;
@property (nonatomic, strong) AVPlayerItem * playerItem;
@property (nonatomic, strong) AVAsset * sourceVideoAsset;
@property (nonatomic, strong) NSArray * touches;
@property (weak, nonatomic) IBOutlet UIView *playbackView;
- (IBAction)playVideo:(id)sender;
- (IBAction)exportVideo:(id)sender;

@end
