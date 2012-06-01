//
//  RectLayer.h
//  gesturedrawer
//
//  Created by Bill So on 5/31/12.
//  Copyright (c) 2012 Headnix. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>

@interface RectLayer : CALayer

@property (nonatomic, strong) NSMutableArray * opacityKeyTimes;
@property (nonatomic, strong) NSMutableArray * opacityValues;
@property (nonatomic, assign) NSTimeInterval startTime;
@property (nonatomic, assign) NSTimeInterval previousTime;
@property (nonatomic, assign) BOOL needFadeIn;
@property (nonatomic, assign) NSInteger currentSequence;
@property (nonatomic, assign) NSInteger touchCount;

@end
