//
//  LineRectLayer.h
//  gesturedrawer
//
//  Created by Bill So on 7/10/12.
//  Copyright (c) 2012 Headnix. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>

@interface LineRectLayer : CALayer

+ (id)layerAtPosition:(CGPoint)aPoint;

- (CGRect)getBoundsAndSetTransformationToPoint:(CGPoint)aPoint;

@end
