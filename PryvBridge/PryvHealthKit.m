//
//  PryvHealthKit.m
//  PryvBridge
//
//  Created by Perki on 15.09.18.
//  Copyright © 2018 Pryv. All rights reserved.
//

#import "PryvHealthKit.h"
#import "PryvController.h"
#import "PryvHealthKit+Observer.h"
#import "PryvHealthKit+Definitions.h"


#pragma mark Definitions

@implementation DefinitionItem
@synthesize type, eventType, streamId;
@end

@implementation DefinitionItemQuantity
@synthesize HKUnit;
@end

#pragma end Definitions


@interface PryvHealthKit ()

- (void)pryvConnectionChange:(NSNotification*)notification;

@end


@implementation PryvHealthKit
@synthesize definitions, api;

/** for Observer **/
@synthesize healthStore, anchorDictionary;

/** for Definitions **/
@synthesize definitionsMap;

- (PryvHealthKit*) init {
    if (self = [super init]) {
        [self loadDefinitions];
        [self initObserver];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                selector:@selector(pryvConnectionChange:)
                                                     name:kAppPryvConnectionChange
                                                   object:nil]; // only start querying and observation if API is on
        
        [self pryvConnectionChange:nil];
    }
    return self;
}

+ (PryvHealthKit*)sharedInstance
{
    static PryvHealthKit *_sharedInstance;
    static dispatch_once_t onceToken;
    __block BOOL init_done = NO;
    dispatch_once(&onceToken, ^{
        _sharedInstance = [[PryvHealthKit alloc] init];
        init_done = YES;
    });
    return _sharedInstance;
}

#pragma mark convertion

- (NSDictionary*) sampleToEventData:(HKSample*)sample {
    if (self.api == nil) {
        [NSException raise:@"API not initialized" format:@""];
    }
    // 1st check Type

    DefinitionItem* di = [self definitionItemForHKSampleType:sample];
    if (di == nil) {
        NSLog(@"Unkown sample %@ ## %@", [sample sampleType], [[sample sampleType] identifier]);
        return nil;
    }
    
    if (di.type == kQuantity) {
        HKQuantity* quantity = ((HKQuantitySample*) sample).quantity;
        HKUnit* unit = ((DefinitionItemQuantity*)di).HKUnit;
        if (! [quantity isCompatibleWithUnit:unit]) {
            NSLog(@"Cannot get value of %@  type: %@ to: %@",sample, quantity, unit);
            return nil;
        }
        
    
        PYLEvent *event = [[PYLEvent alloc] init];
        event.startDate = [sample startDate];
        event.stopDate = [sample endDate];
        event.content = [NSNumber numberWithDouble:[quantity doubleValueForUnit:unit]];
        NSMutableDictionary* clientData = [[NSMutableDictionary alloc] init];
        /**
        if (sample.device) {
            [clientData setObject:[NSString stringWithFormat:@"%@",sample.device] forKey:@"healthkit:device"];
        }**/
        if (sample.sourceRevision) {
            [clientData setObject:[NSString stringWithFormat:@"%@",sample.sourceRevision.source.name] forKey:@"healthkit:source"];
        }
        if ([sample metadata]) {
             [clientData setObject:sample.metadata forKey:@"healthkit:metadata"];
        }
        event.clientData = clientData;
        event.type = di.eventType;
        event.streamId = di.streamId;
        return [event toDictionary];
    }

    return nil;
}


static id (^quantityCountUnit)(HKSample*) = ^(HKSample* sample) {
    return [NSNumber numberWithDouble:[((HKQuantitySample*) sample).quantity doubleValueForUnit:HKUnit.countUnit]];
};

static id (^quantityMeterUnit)(HKSample*) = ^(HKSample* sample) {
    return [NSNumber numberWithDouble:[((HKQuantitySample*) sample).quantity doubleValueForUnit:HKUnit.meterUnit]];
};

static id (^quantityHeartBeatsPerMinuteUnit)(HKSample*) = ^(HKSample* sample) {
    return [NSNumber numberWithDouble:[((HKQuantitySample*) sample).quantity
                                       doubleValueForUnit:[HKUnit unitFromString:@"count/min"]]];
};

+( NSNumber*  (^)(HKSample*)) quantityFromUnitString:(NSString*)unitString {
    __block HKUnit* unit = [HKUnit unitFromString:unitString];
    return ^(HKSample* sample) {
        HKQuantity* quantity = ((HKQuantitySample*) sample).quantity;
        if ([quantity isCompatibleWithUnit:unit]) {
            return [NSNumber numberWithDouble:[quantity doubleValueForUnit:unit]];
        } else {
            NSLog(@"Cannot get value of %@  type: %@ to: %@",sample, quantity, unit);
            return [NSNumber numberWithInt:0];
        }
    };
};


- (NSArray*)getStreamsPermissions {
    NSLog(@"TODO XXXXXXX");
    return nil;
}


#pragma init

- (BOOL)initalizedAPI {
    return (self.api == nil);
}

- (void)initWithAPI:(PryvApiKitLight*)api completionHandler:(void (^)(NSError* e))completed {
    self.api = api;
    if (api == nil) { return completed(nil); }
    //----- streams ----------//
    NSDictionary *streamsHierarchy = (NSDictionary*)[definitions objectForKey:@"streams"];
    if (streamsHierarchy == nil) {
        return  [NSException raise:@"Error streamsHierarchy must be initalized" format:@""];
    }
    
    [self.api addStreamsHierarchy:streamsHierarchy];
    // check all streams exists
    /**
    if ([self.api streamById:di.streamId] == nil) { // test if stream is known
        [NSException raise:@"Invalid streamId in definitions"
                    format:@"For [%@] HKUnit [%@] streamId has not been defined in streams", key, di.streamId];
    }**/
    
    [self.api ensureStreamCreated:completed];
}

#pragma mark - Pryv connection chnage

/**
 * Connection changed (can be nil to remove)
 */
- (void)pryvConnectionChange:(NSNotification*)notification
{
    if ([PryvController sharedInstance].api == nil) {
        self.api = nil;
        return;
    }
    self.api = [PryvController sharedInstance].api;
    [self initWithAPI:[PryvController sharedInstance].api completionHandler:^(NSError *e) {
        [self observeHealthKit]; // start Health Observation
    }];
}


@end
