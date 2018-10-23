//
//  PryvHealthKit.m
//  PryvBridge
//
//  Created by Perki on 15.09.18.
//  Copyright © 2018 Pryv. All rights reserved.
//

#import "PryvHealthKit.h"



@interface PryvHealthKit ()


@end


@implementation PryvHealthKit

+ (PYEvent*) sampleToEvent:(HKSample*)sample {
    
    NSString* type;
    id eventContent;
    
    id z = [[sample sampleType] identifier];
    id zz = HKQuantityTypeIdentifierStepCount;
    
    
    if ([[[sample sampleType] identifier] isEqualToString:HKQuantityTypeIdentifierStepCount]) {
        type = @"count/step";
        eventContent = [NSNumber numberWithDouble:[((HKQuantitySample*) sample).quantity doubleValueForUnit:HKUnit.countUnit]];
    }
    
    if (type == nil) {
        NSLog(@"Sample %@ ## %@", sample, [sample sampleType]);
        return nil;
    }
    
    PYEvent *event = [[PYEvent alloc] init];
    [event setEventDate:[sample startDate]];
    [event setEventEndDate:[sample endDate]];
    event.type = type;
    event.eventContent = eventContent;

    return event;
}

/**
static void (^quantityCount)(id) = ^(HKsample* sample) {
        
};**/

static NSDictionary* typeMap;

+ (PryvHealthKit*)sharedInstance
{
    static PryvHealthKit *_sharedInstance;
    static dispatch_once_t onceToken;
    __block BOOL init_done = NO;
    dispatch_once(&onceToken, ^{
        typeMap = @{
            HKQuantityTypeIdentifierStepCount: @[@"count/step", ],
        };
        _sharedInstance = [[PryvHealthKit alloc] init];
        init_done = YES;
    });
    return _sharedInstance;
}


@end
