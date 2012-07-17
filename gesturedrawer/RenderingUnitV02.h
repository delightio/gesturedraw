//
//  RenderingUnitV02.h
//  gesturedrawer
//
//  Created by Bill So on 5/29/12.
//  Copyright (c) 2012 Headnix. All rights reserved.
//

#import "RenderingUnit.h"

typedef enum {
    UIDeviceOrientationUnknown,
    UIDeviceOrientationPortrait,            // Device oriented vertically, home button on the bottom
    UIDeviceOrientationPortraitUpsideDown,  // Device oriented vertically, home button on the top
    UIDeviceOrientationLandscapeLeft,       // Device oriented horizontally, home button on the right
    UIDeviceOrientationLandscapeRight,      // Device oriented horizontally, home button on the left
    UIDeviceOrientationFaceUp,              // Device oriented flat, face up
    UIDeviceOrientationFaceDown             // Device oriented flat, face down
} UIDeviceOrientation;

typedef enum {
    UIInterfaceOrientationPortrait           = UIDeviceOrientationPortrait,
    UIInterfaceOrientationPortraitUpsideDown = UIDeviceOrientationPortraitUpsideDown,
    UIInterfaceOrientationLandscapeLeft      = UIDeviceOrientationLandscapeRight,
    UIInterfaceOrientationLandscapeRight     = UIDeviceOrientationLandscapeLeft
} UIInterfaceOrientation;

extern NSString * DLDeviceOrientationKey;
extern NSString * DLInterfaceOrientationKey;
extern NSString * DLOrientationTimeKey;

@interface RenderingUnitV02 : RenderingUnit {
	__strong NSMutableArray * rectLayerBuffer;
	__strong NSMutableArray * dotLayerBuffer;
	__strong NSMutableArray * dotMagnificationLayerBuffer;
	UIInterfaceOrientation majorOrientation;
	BOOL exportFinished;
}

- (void)checkMajorOrientationForTrack:(NSArray *)track;
- (void)setOrientationTransformForLayer:(CALayer *)aLayer;

@end
