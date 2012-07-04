//
//  RenderingUnitV03.h
//  gesturedrawer
//
//  Created by Bill So on 5/29/12.
//  Copyright (c) 2012 Headnix. All rights reserved.
//

#import "RenderingUnit.h"
#import "RenderingUnitV02.h"

@interface RenderingUnitV03 : RenderingUnit {
	__strong NSMutableArray * rectLayerBuffer;
	__strong NSMutableArray * dotLayerBuffer;
	__strong NSMutableArray * dotMagnificationLayerBuffer;
	__strong NSMutableArray * pathLayerBuffer;
	UIInterfaceOrientation majorOrientation;
	BOOL exportFinished;
}

- (void)checkMajorOrientationForTrack:(NSArray *)track;
- (void)setOrientationTransformForLayer:(CALayer *)aLayer;

@end
