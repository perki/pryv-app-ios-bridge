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
    [PryvHealthKit sharedInstance];
  
    NSString* sampleType = [[sample sampleType] identifier];
    NSArray* specs = [typeMap objectForKey:sampleType];
    if (specs == nil) {
        NSLog(@"Unkown sample %@ ## %@", [sample sampleType], sample);
        return nil;
    }
    id (^ getContent)(HKSample*) = specs[1];
    
    PYEvent *event = [[PYEvent alloc] init];
    [event setEventDate:[sample startDate]];
    [event setEventEndDate:[sample endDate]];
    event.type = specs[0];
    event.eventContent = getContent(sample);

    return event;
}


static id (^quantityCount)(HKSample*) = ^(HKSample* sample) {
    return [NSNumber numberWithDouble:[((HKQuantitySample*) sample).quantity doubleValueForUnit:HKUnit.countUnit]];
};

static NSDictionary* typeMap;

+ (PryvHealthKit*)sharedInstance
{
    static PryvHealthKit *_sharedInstance;
    static dispatch_once_t onceToken;
    __block BOOL init_done = NO;
    dispatch_once(&onceToken, ^{
        typeMap = @{
                    HKQuantityTypeIdentifierHeartRate: @[@"frequency/bpm", quantityCount],
                    HKQuantityTypeIdentifierStepCount: @[@"count/step", quantityCount],
        };
        _sharedInstance = [[PryvHealthKit alloc] init];
        init_done = YES;
    });
    return _sharedInstance;
}


@end
