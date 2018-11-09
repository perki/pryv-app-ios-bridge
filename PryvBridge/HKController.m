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
#import "HKController.h"


@interface HKController ()
- (void)requestAuthorization;
- (void)observeHealthKit;
- (void)updateDataForSampleType:(HKSampleType *)sampleType;
- (void)saveAnchors;

- (void)initPryvHealthKit;
- (void)pryvConnectionChange:(NSNotification*)notification;

@property (nonatomic, readonly) NSArray<HKSampleType *> *sampleTypes;
@property (nonatomic, strong) NSMutableDictionary<NSString *, HKQueryAnchor *> *anchorDictionary;

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


- (instancetype)init {
    self = [super init];
    if (self) {
        self.anchorDictionary = [self _anchorDictFromStorage];
    }
    return self;
}

- (void)initObject
{
    [self requestAuthorization];
    [self initPryvHealthKit];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(pryvConnectionChange:)
                                                 name:kAppPryvConnectionChange
                                               object:nil];
}

BOOL PryvHealthKitInitialized = NO;
- (void)initPryvHealthKit
{
    if ([PryvController sharedInstance].api == nil) {
        PryvHealthKitInitialized = NO;
        return;
    }
    if (PryvHealthKitInitialized) {
        return;
    }
    PryvHealthKitInitialized = YES;
    [[PryvHealthKit sharedInstance] ensureStreamsExists:[PryvController sharedInstance].api completionHandler:^(NSError *e) {
        NSLog(@"#### Error ensuring Stream exists in HKCOntroller %@", e);
    }];
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
    
    [self observeHealthKit];
    
}


#pragma mark - Public Instance Methods

- (void)observeHealthKit {
    for (HKSampleType *sample in self.sampleTypes) {
        if ([self.healthStore authorizationStatusForType:sample] != HKAuthorizationStatusNotDetermined) {
            HKObserverQuery *observationQuery = [[HKObserverQuery alloc] initWithSampleType:sample predicate:nil
              updateHandler:^(HKObserverQuery *query, HKObserverQueryCompletionHandler completionHandler, NSError *error) {
                  if (error)
                  NSLog(@"Error observing changes to HKSampleType with identifier %@: %@", query.sampleType.identifier, error.localizedDescription);
                  else {
                      [[HKController sharedInstance] updateDataForSampleType:query.sampleType];
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
        limit = 500;
        
    }
    
    HKAnchoredObjectQuery *anchoredQuery = [[HKAnchoredObjectQuery alloc] initWithType:sampleType
                 predicate:nil
                    anchor:anchor
                     limit:limit
            resultsHandler:^(HKAnchoredObjectQuery *query, NSArray<HKSample *> *sampleObjects, NSArray<HKDeletedObject *> *deletedObjects, HKQueryAnchor *newAnchor, NSError *error) {
                if (!error) {
                    for (HKSample *sample in sampleObjects) {
                        // Process Sample
                        // [NSDateFormatter localizedStringFromDate:[NSDate date] dateStyle:NSDateFormatterShortStyle timeStyle:NSDateFormatterFullStyle]
                        PYEvent* e = [[PryvHealthKit sharedInstance] sampleToEvent:sample];
                        NSLog(@"Created Event: %@ %@", e.type, e.eventContent);
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


- (NSArray<HKSampleType *> *)sampleTypes {
    
    return [[PryvHealthKit sharedInstance] sampleTypes];
    
    HKQuantityType *steps = [HKQuantityType quantityTypeForIdentifier:HKQuantityTypeIdentifierStepCount];
    HKQuantityType *distance = [HKQuantityType quantityTypeForIdentifier:HKQuantityTypeIdentifierDistanceWalkingRunning];
    HKQuantityType *energyBurnedActive = [HKQuantityType quantityTypeForIdentifier:HKQuantityTypeIdentifierActiveEnergyBurned];
    HKQuantityType *energyBurnedResting = [HKQuantityType quantityTypeForIdentifier:HKQuantityTypeIdentifierBasalEnergyBurned];
    HKQuantityType *heartRate = [HKQuantityType quantityTypeForIdentifier:HKQuantityTypeIdentifierHeartRate];
    HKQuantityType *bloodPressureSystolic = [HKQuantityType quantityTypeForIdentifier:HKQuantityTypeIdentifierBloodPressureSystolic];
    HKQuantityType *bloodPressureDiastolic = [HKQuantityType quantityTypeForIdentifier:HKQuantityTypeIdentifierBloodPressureDiastolic];
    HKQuantityType *bloodSugar = [HKQuantityType quantityTypeForIdentifier:HKQuantityTypeIdentifierBloodGlucose];
    
    return @[steps, distance, energyBurnedActive, energyBurnedResting, energyBurnedActive, heartRate, bloodPressureSystolic, bloodPressureDiastolic, bloodSugar];
    
}

#pragma mark - Private Instance Methods

- (NSMutableDictionary<NSString *, HKQueryAnchor *> *)_anchorDictFromStorage {
    NSData *data = (NSData *)[[NSUserDefaults standardUserDefaults] valueForKey:@"_anchorDict"];
    if (data)
        return (NSMutableDictionary<NSString *, HKQueryAnchor *> *)[NSKeyedUnarchiver unarchiveObjectWithData:data];

    return [[NSMutableDictionary<NSString *, HKQueryAnchor *> alloc] init];
}

#pragma mark - Pryv connection chnage

/**
 * Connection changed (can be nil to remove)
 */
- (void)pryvConnectionChange:(NSNotification*)notification
{
    [self initPryvHealthKit];
}

@end
