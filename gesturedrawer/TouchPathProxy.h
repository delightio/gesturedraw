//
//  TouchPathProxy.h
//  gesturedrawer
//
//  Created by Bill So on 7/10/12.
//  Copyright (c) 2012 Headnix. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface TouchPathProxy : NSObject

@property (nonatomic, strong) NSMutableArray * pathTimes;
@property (nonatomic, strong) NSMutableArray * pathValues;
@property (nonatomic, strong) NSMutableIndexSet * pathStartSegmentIndexSet;
@property (nonatomic, strong) NSMutableIndexSet * pathEndSegmentIndexSet;
@property (nonatomic, assign) NSTimeInterval startTime;
@property (nonatomic, assign) NSPoint previousLocation;
@property (nonatomic, assign) NSTimeInterval previousTime;
@property (nonatomic, assign) NSInteger currentSequence;
@property (nonatomic, assign) BOOL needFadeIn;

- (double)discrepancyWithPreviousLocation:(NSPoint)prevLoc;

@end
