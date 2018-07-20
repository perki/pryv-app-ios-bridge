//
//  HKController.m
//  PryvBridge
//
//  Created by Perki on 20.07.18.
//  Copyright © 2018 Pryv. All rights reserved.
//

#import <Foundation/Foundation.h>


#import "HKController.h"


@interface HKController ()
- (void)requestAuthorization;
- (void)updateHealthKit:(HKObjectType*) objectType withCompletionHandler:(HKObserverQueryCompletionHandler _Nonnull) completionHandler;
@end


@implementation HKController

@synthesize healthStore = _healthStore;


+ (HKController*)sharedInstance
{
    static HKController *_sharedInstance;
    static dispatch_once_t onceToken;
    __block BOOL init_done = NO;
    dispatch_once(&onceToken, ^{
        _sharedInstance = [[HKController alloc] init];
        init_done = YES;
    });
    if (init_done) [_sharedInstance initObject];
    return _sharedInstance;
}

- (void)initObject
{
    [self requestAuthorization];
}

- (void) requestAuthorization {
    if ([HKHealthStore isHealthDataAvailable] == NO) {
        // If our device doesn't support HealthKit -> return.
        return;
    }
    self.healthStore = [[HKHealthStore alloc] init];
    
    NSArray* readTypes = @[[HKObjectType quantityTypeForIdentifier:HKQuantityTypeIdentifierStepCount]];
    

    
    [self. healthStore requestAuthorizationToShareTypes:nil readTypes:[NSSet setWithArray:readTypes] completion:^(BOOL success, NSError * _Nullable error) {
        // no code
    }];
    
  
    
    HKObserverQuery* ob = [[HKObserverQuery alloc] initWithSampleType:readTypes[0] predicate:nil updateHandler:^(HKObserverQuery * _Nonnull query, HKObserverQueryCompletionHandler  _Nonnull completionHandler, NSError * _Nullable error) {
        if (error == nil) {
            [self updateHealthKit:readTypes[0] withCompletionHandler:completionHandler];
        } else {
            completionHandler();
        }
    }];
    
    [self.healthStore executeQuery:ob];
    
    [self.healthStore enableBackgroundDeliveryForType:readTypes[0] frequency:HKUpdateFrequencyImmediate withCompletion:^(BOOL success, NSError * _Nullable error) {
        
        if (success) {
            NSLog(@"Enabled background delivery of steps changes");
        } else {
            NSLog(@"Failed to enable background delivery of steps changes. %@", error);
        }
    }];
    
}


- (void)updateHealthKit:(HKObjectType*) objectType  withCompletionHandler:(HKObserverQueryCompletionHandler _Nonnull) completionHandler; {
    if (objectType.identifier == HKQuantityTypeIdentifierStepCount) {
        NSLog(@"************* Got Steps");
        completionHandler();
    }
}

@end
