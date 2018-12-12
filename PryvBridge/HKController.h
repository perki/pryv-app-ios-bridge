//
//  HKController.h
//  PryvBridge
//
//  Created by Perki on 20.07.18.
//  Copyright © 2018 Pryv. All rights reserved.
//

#ifndef HKController_h
#define HKController_h


#import <HealthKit/HealthKit.h>
#import "PryvHealthKit.h"
@class HKController;


@interface HKController : NSObject

+ (HKController*)sharedInstance;
- (void)observeHealthKitWith:(PryvHealthKit*)pyHK;

@property (nonatomic, retain) HKHealthStore* healthStore;


@end




#endif /* HKController_h */
