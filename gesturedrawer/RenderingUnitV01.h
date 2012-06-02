//
//  RenderingUnitV01.h
//  gesturedrawer
//
//  Created by Bill So on 5/29/12.
//  Copyright (c) 2012 Headnix. All rights reserved.
//

#import "RenderingUnit.h"

@interface RenderingUnitV01 : RenderingUnit {
	__strong NSMutableArray * onscreenDotLayerBuffer;
	__strong NSMutableArray * unassignedDotLayerBuffer;
}

@end
