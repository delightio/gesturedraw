//
//  TouchLayer.h
//  gesturedrawer
//
//  Created by Bill So on 5/17/12.
//  Copyright (c) 2012 Headnix. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>

@interface TouchLayer : CAShapeLayer

@property (nonatomic, readonly) NSMutableArray * pathKeyTimes;
@property (nonatomic, readonly) NSMutableArray * opacityKeyTimes;
@property (nonatomic, readonly) NSMutableArray * pathValues;
@property (nonatomic, readonly) NSMutableArray * opacityValues;

@end
