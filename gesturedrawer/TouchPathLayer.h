//
//  TouchPathLayer.h
//  gesturedrawer
//
//  Created by Bill So on 7/4/12.
//  Copyright (c) 2012 Headnix. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>

@interface TouchPathLayer : CAShapeLayer

@property (nonatomic, strong) NSMutableArray * pathKeyTimes;
@property (nonatomic, strong) NSMutableArray * opacityKeyTimes;
@property (nonatomic, strong) NSMutableArray * pathValues;
@property (nonatomic, strong) NSMutableArray * opacityValues;
@property (nonatomic, assign) NSTimeInterval startTime;
@property (nonatomic, assign) NSPoint previousLocation;
@property (nonatomic, assign) NSTimeInterval previousTime;
@property (nonatomic, assign) NSInteger currentSequence;
//@property (nonatomic, assign) BOOL needFadeIn;

- (void)addPathPoint:(CGPoint)aPoint atKeyFrame:(NSNumber *)fmKey;
- (double)discrepancyWithPreviousLocation:(NSPoint)prevLoc;

@end
