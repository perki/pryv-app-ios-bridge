//
//  PryvHealthKit.h
//  PryvBridge
//
//  Created by Perki on 15.09.18.
//  Copyright © 2018 Pryv. All rights reserved.
//

#ifndef PryvHealthKit_h
#define PryvHealthKit_h


#import <HealthKit/HealthKit.h>

#import "PryvApiKitLight.h"

@interface PryvHealthKit : NSObject
+ (PryvHealthKit*)sharedInstance;
- (BOOL)initalizedAPI; // return YES if ready
- (NSDictionary*) sampleToEventData:(HKSample*)sample;
- (NSArray<HKSampleType *> *)sampleTypes;
- (NSArray*)getStreamsPermissions;
/**
 * Set Api (null to erase)
 */
- (void)initWithAPI:(PryvApiKitLight*)api completionHandler:(void (^)(NSError* e))completed;
@end


#endif /* PryvHealthKit_h */
