//
//  TouchLayer.h
//  gesturedrawer
//
//  Created by Bill So on 5/17/12.
//  Copyright (c) 2012 Headnix. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>

@interface TouchLayer : CAShapeLayer

@property (nonatomic, strong) NSMutableArray * pathKeyTimes;
@property (nonatomic, strong) NSMutableArray * opacityKeyTimes;
@property (nonatomic, strong) NSMutableArray * pathValues;
@property (nonatomic, strong) NSMutableArray * opacityValues;
@property (nonatomic, assign) NSTimeInterval startTime;

@end
