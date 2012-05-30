//
//  RenderingUnit.h
//  gesturedrawer
//
//  Created by Bill So on 5/22/12.
//  Copyright (c) 2012 Headnix. All rights reserved.
//

#import <Foundation/Foundation.h>

@class TouchLayer;

typedef enum {
    UITouchPhaseBegan,             // whenever a finger touches the surface.
    UITouchPhaseMoved,             // whenever a finger moves on the surface.
    UITouchPhaseStationary,        // whenever a finger is touching the surface but hasn't moved since the previous event.
    UITouchPhaseEnded,             // whenever a finger leaves the surface.
    UITouchPhaseCancelled,         // whenever a touch doesn't end but we need to stop tracking (e.g. putting device to face)
} UITouchPhase;

extern NSString * DLTouchCurrentLocationKey;
extern NSString * DLTouchPreviousLocationKey;
extern NSString * DLTouchSequenceNumKey;
extern NSString * DLTouchPhaseKey;
extern NSString * DLTouchTimeKey;
extern NSString * DLTouchTapCountKey;
extern NSString * DLTouchPrivateKey;

@interface RenderingUnit : NSObject {
	__strong NSMutableArray * onscreenLayerBuffer;
	__strong NSMutableArray * unassignedLayerBuffer;
	__strong AVAssetExportSession * session;
	__strong NSString * sourceFilePath;
	__strong NSString * destinationFilePath;
	__strong NSArray * touches;
	NSRect touchBounds;
	NSTimeInterval videoDuration;
}

@property (nonatomic) NSRect touchBounds;
@property (nonatomic) NSTimeInterval videoDuration;

- (id)initWithVideoAtPath:(NSString *)vdoPath destinationPath:(NSString *)dstPath touchesPropertyList:(NSDictionary *)tchPlist;
- (void)exportVideoWithCompletionHandler:(void (^)(void))handler;
- (TouchLayer *)layerForTouch:(NSDictionary *)aTouchDict parentLayer:(CALayer *)pLayer;

- (void)setupGestureAnimationsForLayer:(CALayer *)parentLayer;

@end
