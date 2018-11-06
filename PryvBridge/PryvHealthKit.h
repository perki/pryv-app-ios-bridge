//
//  PryvHealthKit.h
//  PryvBridge
//
//  Created by Perki on 15.09.18.
//  Copyright © 2018 Pryv. All rights reserved.
//

#ifndef PryvHealthKit_h
#define PryvHealthKit_h


#import <PryvApiKit/PryvApiKit.h>
#import <HealthKit/HealthKit.h>

@interface PryvHealthKit : NSObject

+ (PryvHealthKit*)sharedInstance;

- (PYEvent*) sampleToEvent:(HKSample*)sample;
- (NSArray<HKSampleType *> *)sampleTypes;

@end

#endif /* PryvHealthKit_h */
