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

#pragma mark Definitions

typedef enum {
    kQuantity,
} DefinitionType;

typedef id (^HKSampleToPryvEvent)(HKSample*);


@interface DefinitionItem : NSObject
@property DefinitionType type;
@property NSString *eventType;
@property NSString *streamId;
@end

@interface DefinitionItemQuantity : DefinitionItem
@property HKUnit *HKUnit;
@end

#pragma mark End Definitions

@interface PryvHealthKit : NSObject
+ (PryvHealthKit*)sharedInstance;
- (BOOL)initalizedAPI; // return YES if ready
- (NSDictionary*) sampleToEventData:(HKSample*)sample;


- (NSArray*)getStreamsPermissions;

/**
 * Set Api (null to erase)
 */
- (void)initWithAPI:(PryvApiKitLight*)api completionHandler:(void (^)(NSError* e))completed;

@property NSDictionary *definitions;
@property PryvApiKitLight *api;


/** For Observer */
@property (nonatomic, retain) HKHealthStore* healthStore;
@property (nonatomic, strong) NSMutableDictionary<NSString *, HKQueryAnchor *> *anchorDictionary;

/** For Definitions */
@property (nonatomic, strong) NSDictionary<NSString *, DefinitionItem*> *definitionsMap;

@end


#endif /* PryvHealthKit_h */
