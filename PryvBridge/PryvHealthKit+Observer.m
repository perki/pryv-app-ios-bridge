//
//  HKController.m
//  PryvBridge
//
//  Created by Perki on 20.07.18.
//  Copyright © 2018 Pryv. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PryvController.h"

#import "PryvHealthKit.h"
#import "PryvHealthKit+Observer.h"
#import "PryvHealthKit+Definitions.h"



@implementation PryvHealthKit (Observer)



- (void)initObserver
{
    self.anchorDictionary = [self _anchorDictFromStorage];
    [self requestAuthorization]; // request authorization
}


- (void) requestAuthorization {
    if ([HKHealthStore isHealthDataAvailable] == NO) {
        // If our device doesn't support HealthKit -> return.
        return;
    }
    self.healthStore = [[HKHealthStore alloc] init];
    
    [self.healthStore requestAuthorizationToShareTypes:nil readTypes:[NSSet setWithArray:[self sampleTypes]] completion:^(BOOL success, NSError * _Nullable error) {
        // no code
    }];
}


#pragma mark - Public Instance Methods

- (void)observeHealthKit {

    for (HKSampleType *sample in self.sampleTypes) { // for each sample
        if ([self.healthStore authorizationStatusForType:sample] != HKAuthorizationStatusNotDetermined) {
            HKObserverQuery *observationQuery = [[HKObserverQuery alloc] initWithSampleType:sample predicate:nil
              updateHandler:^(HKObserverQuery *query, HKObserverQueryCompletionHandler completionHandler, NSError *error) {
                  if (error)
                  NSLog(@"Error observing changes to HKSampleType with identifier %@: %@", query.sampleType.identifier, error.localizedDescription);
                  else {
                      [self updateDataForSampleType:query.sampleType];
                  }
                  completionHandler();
              }];
            
            [self.healthStore executeQuery:observationQuery];
            [self.healthStore enableBackgroundDeliveryForType:sample
                    frequency:HKUpdateFrequencyImmediate
               withCompletion:^(BOOL success, NSError *error) {
                   if (!success)
                   NSLog(@"Error enabling background delivery for HKSampleType with Identifier %@: %@", sample.identifier, error.localizedDescription);
               }];
            
            
            [self updateDataForSampleType:sample];
        }
        
    }
    
}
- (void)updateDataForSampleType:(HKSampleType *)sampleType {
    
    HKQueryAnchor *anchor = self.anchorDictionary[sampleType.identifier];
    NSUInteger limit = HKObjectQueryNoLimit;
    
    if (!anchor) {
        anchor = HKAnchoredObjectQueryNoAnchor;
        limit = HKObjectQueryNoLimit; // HKObjectQueryNoLimit;
    }
    
    HKAnchoredObjectQuery *anchoredQuery = [[HKAnchoredObjectQuery alloc] initWithType:sampleType
                 predicate:nil
                    anchor:anchor
                     limit:limit
            resultsHandler:^(HKAnchoredObjectQuery *query, NSArray<HKSample *> *sampleObjects, NSArray<HKDeletedObject *> *deletedObjects, HKQueryAnchor *newAnchor, NSError *error) {
                if (!error) {
                    for (HKSample *sample in sampleObjects) {
                        NSDictionary* e = [self sampleToEventData:sample];
                        // TODO save this event
                        NSLog(@"%@", e);
                    }
                    
                } else
                NSLog(@"Error fetching data for HKSampleType with identifier %@: %@", query.sampleType.identifier, error.localizedDescription);
                
            }];
    
    [self.healthStore executeQuery:anchoredQuery];
    
}

- (void)saveAnchors {
    
    NSData *anchorData = [NSKeyedArchiver archivedDataWithRootObject:self.anchorDictionary];
    [[NSUserDefaults standardUserDefaults] setObject:anchorData forKey:@"_anchorDict"];
    
}



#pragma mark - Private Instance Methods

- (NSMutableDictionary<NSString *, HKQueryAnchor *> *)_anchorDictFromStorage {
    NSData *data = (NSData *)[[NSUserDefaults standardUserDefaults] valueForKey:@"_anchorDict"];
    if (data)
        return (NSMutableDictionary<NSString *, HKQueryAnchor *> *)[NSKeyedUnarchiver unarchiveObjectWithData:data];

    return [[NSMutableDictionary<NSString *, HKQueryAnchor *> alloc] init];
}


@end
