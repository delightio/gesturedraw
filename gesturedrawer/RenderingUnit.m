//
//  RenderingUnit.m
//  gesturedrawer
//
//  Created by Bill So on 5/22/12.
//  Copyright (c) 2012 Headnix. All rights reserved.
//

#import "TouchLayer.h"
#import "RenderingUnit.h"

NSString * DLTouchCurrentLocationKey = @"curLoc";
NSString * DLTouchPreviousLocationKey = @"prevLoc";
NSString * DLTouchSequenceNumKey = @"seq";
NSString * DLTouchPhaseKey = @"phase";
NSString * DLTouchTimeKey = @"time";
NSString * DLTouchTapCountKey = @"tapCount";
NSString * DLTouchPrivateFrameKey = @"privateFrame";

@implementation RenderingUnit
@synthesize parentLayer;
@synthesize touchBounds;
@synthesize videoDuration;

- (id)initWithVideoAtPath:(NSString *)vdoPath destinationPath:(NSString *)dstPath touchesPropertyList:(NSDictionary *)tchPlist {
	self = [super init];
	sourceFilePath = vdoPath;
	destinationFilePath = dstPath;
	touches = [tchPlist objectForKey:@"touches"];
	touchBounds = NSRectFromString([tchPlist objectForKey:@"touchBounds"]);
	
	return self;
}

- (void)exportVideoWithCompletionHandler:(void (^)(void))handler {
}

- (TouchLayer *)layerWithPreviousLocation:(NSPoint)prevLoc forSequence:(NSInteger)seqNum {
	return nil;
}

- (TouchLayer *)layerForTouch:(NSDictionary *)aTouchDict {
	return nil;
}

- (void)setupGestureAnimationsForLayer:(CALayer *)prnLayer {
}

@end
