//
//  PryvHealthKit.m
//  PryvBridge
//
//  Created by Perki on 15.09.18.
//  Copyright © 2018 Pryv. All rights reserved.
//

#import "PryvHealthKit.h"
#import "PryvController.h"
#import "HKController.h"


@interface PryvHealthKit ()
- (void) loadDefinitions;
+ (NSDictionary *)JSONFromFile:(NSString*)fileName;
- (void)pryvConnectionChange:(NSNotification*)notification;
@property NSDictionary *definitions;
@property PryvApiKitLight *api;
@end

typedef enum {
    kQuantity,
} DefinitionType;


typedef id (^HKSampleToPryvEvent)(HKSample*);


@interface DefinitionItem : NSObject
@property DefinitionType type;
@property NSString *eventType;
@property NSString *streamId;
@end


@implementation DefinitionItem
    @synthesize type, eventType, streamId;
@end

@interface DefinitionItemQuantity : DefinitionItem
    @property HKUnit *HKUnit;
@end

@implementation DefinitionItemQuantity
     @synthesize HKUnit;
@end



@implementation PryvHealthKit
@synthesize definitions, api;

/**
 * Map HKSample{id} - Definition
 */
NSDictionary<NSString *, DefinitionItem*> *definitionsMap;

- (PryvHealthKit*) init {
    if (self = [super init]) {
        [self loadDefinitions];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(pryvConnectionChange:)
                                                     name:kAppPryvConnectionChange
                                                   object:nil]; // only start querying and observation if API is on
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
    NSString* sampleType = [[sample sampleType] identifier];
    DefinitionItem* di = [definitionsMap objectForKey:sampleType];
    if (di == nil) {
        NSLog(@"Unkown sample %@ ## %@", [sample sampleType], sample);
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

#pragma mark definitions

NSArray<HKSampleType *> *cacheSampletypes = nil;
- (NSArray<HKSampleType *> *)sampleTypes {
    if (cacheSampletypes != nil) {
        return cacheSampletypes;
    }
    NSMutableArray* types = [[NSMutableArray alloc] init];
    for (NSString* key in definitionsMap) {
        DefinitionItem* di = [definitionsMap objectForKey:key];
        if (di.type == kQuantity) {
            HKQuantityType* qt = [HKQuantityType quantityTypeForIdentifier:key];
            if (qt == nil) {
                [NSException raise:@"Invalid quantityTypeForIdentifier" format:@"Identifier %@ is invalid", key];
            }
            [types addObject:qt];
        } else {
            [NSException raise:@"Unkown type in definitions" format:@"type for %@ is unkown", key];
        }
    }
    cacheSampletypes = types;
    return cacheSampletypes;
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

/**
 * During initialization
 * a JSON file containig definitions of types is loaded
 */
- (void) loadDefinitions {
    self.definitions = [PryvHealthKit JSONFromFile:@"HealthKitPryvDefinitions"];
    //----- HKSampletypes ----//
    NSMutableDictionary<NSString*, DefinitionItem*> *defs = [[NSMutableDictionary alloc] init];
    //----- quantities ------//
    NSDictionary* quantities = [self.definitions objectForKey:@"quantities"];
    for (NSString* key in quantities) {
        NSDictionary* quantity = (NSDictionary*) [quantities objectForKey:key];
        DefinitionItemQuantity* di = [[DefinitionItemQuantity alloc] init];
        di.type = kQuantity;
        di.streamId = [quantity objectForKey:@"streamId"];
        di.eventType = [quantity objectForKey:@"type"];
        @try {
            di.HKUnit = [HKUnit unitFromString: [quantity objectForKey:@"HKUnit"]];
        }
        @catch (NSException * e) {
            [NSException raise:@"Invalid HKUnit in definitions" format:@"For [%@] HKUnit [%@] invalid with %@", key,  [quantity objectForKey:@"HKUnit"], e];
        }
        if (di.HKUnit == nil) {
            [NSException raise:@"Invalid HKUnit in definitions" format:@"For [%@] HKUnit [%@] invalid", key,  [quantity objectForKey:@"HKUnit"]];
        }
        [defs setObject:di forKey:key];
    }
    definitionsMap = defs;
    cacheSampletypes = nil; // reset Sample Types Cache
};

+ (NSDictionary *)JSONFromFile:(NSString*)fileName {
    NSString *path = [[NSBundle mainBundle] pathForResource:fileName ofType:@"json"];
    NSData *data = [NSData dataWithContentsOfFile:path];
    NSError *e = nil;
    NSDictionary* result = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&e];
    
    if (!result) {
        [NSException raise:@"Error parsing JSON definition files" format:@"Error: %@ ", e];
    }
    return result;
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
        [[HKController sharedInstance] observeHealthKitWith:self]; // start Health Observation
    }];
}


@end
