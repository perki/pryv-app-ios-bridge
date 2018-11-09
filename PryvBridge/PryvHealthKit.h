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

#import "PryvApiKitLight.h"

@interface PryvHealthKit : NSObject

+ (PryvHealthKit*)sharedInstance;

- (PYEvent*) sampleToEvent:(HKSample*)sample;
- (NSArray<HKSampleType *> *)sampleTypes;


- (NSArray*)getStreamsPermissions;
- (void)ensureStreamsExists:(PryvApiKitLight*)api completionHandler:(void (^)(NSError* e))completed;

@end

#endif /* PryvHealthKit_h */
