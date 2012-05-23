//
//  RenderingUnit.h
//  gesturedrawer
//
//  Created by Bill So on 5/22/12.
//  Copyright (c) 2012 Headnix. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef enum {
    UITouchPhaseBegan,             // whenever a finger touches the surface.
    UITouchPhaseMoved,             // whenever a finger moves on the surface.
    UITouchPhaseStationary,        // whenever a finger is touching the surface but hasn't moved since the previous event.
    UITouchPhaseEnded,             // whenever a finger leaves the surface.
    UITouchPhaseCancelled,         // whenever a touch doesn't end but we need to stop tracking (e.g. putting device to face)
} UITouchPhase;

@interface RenderingUnit : NSObject {
	__strong NSMutableArray * onscreenLayerBuffer;
	__strong NSMutableArray * unassignedLayerBuffer;
	__strong AVAssetExportSession * session;
}

@property (nonatomic, strong) NSString * sourceFilePath;
@property (nonatomic, strong) NSString * touchesFilePath;
@property (nonatomic, strong) NSString * destinationFilePath;
@property (nonatomic, strong) NSArray * touches;
@property (nonatomic) NSRect touchBounds;
@property (nonatomic) NSTimeInterval videoDuration;

- (id)initWithVideoAtPath:(NSString *)vdoPath touchesPListPath:(NSString *)tchPath destinationPath:(NSString *)dstPath;
- (void)exportVideoWithCompletionHandler:(void (^)(void))handler;

- (void)setupGestureAnimationsForLayer:(CALayer *)parentLayer;

@end
