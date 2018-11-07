//
//  PryvHealthKit.m
//  PryvBridge
//
//  Created by Perki on 15.09.18.
//  Copyright © 2018 Pryv. All rights reserved.
//

#import "PryvHealthKit.h"


@interface PryvHealthKit ()
- (void) loadDefinitions;
+ (NSDictionary *)JSONFromFile:(NSString*)fileName;
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

/**
 * Map StreamId - InfoNeeded for creation
 */
NSMutableDictionary<NSString *, NSDictionary*> *streamsMap;

/**
 * Map HKSample{id} - Definition
 */
NSDictionary<NSString *, DefinitionItem*> *definitionsMap;

- (PYEvent*) sampleToEvent:(HKSample*)sample {
    
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
        
        
        PYEvent *event = [[PYEvent alloc] init];
        NSDate* startDate = [sample startDate];
        NSDate* stopDate = [sample endDate];
        [event setEventDate:startDate];
        if ([startDate compare:stopDate] != NSOrderedSame) {
            [event setEventEndDate:stopDate];
        }
        event.eventContent = [NSNumber numberWithDouble:[quantity doubleValueForUnit:unit]];;
        event.type = di.eventType;
        event.streamId = di.streamId;
        return event;
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


- (PryvHealthKit*) init {
    if (self = [super init]) {
        [self loadDefinitions];
    }
    return self;
}

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

/**
 * Private Method,
 * Recursively follow the "streams" definitions and create a flat map with
 * streamID: { name, parentId }
 */
- (void) fillStreamMaprecursive:(NSDictionary*) streams withParentId:(NSString*) parentId {
    for (NSString* key in streams) {
        NSMutableDictionary* stream = [[NSMutableDictionary alloc]
                                       initWithDictionary:@{@"name": streams[key][@"name"]}];
        if (parentId != nil) {[stream setObject:parentId forKey:@"parentId"];};
        [streamsMap setObject:stream  forKey:key];
        NSDictionary* childs = streams[key][@"childs"];
        if (childs != nil) {
            [self fillStreamMaprecursive:childs withParentId:key];
        }
    }
}

/**
 * During initialization
 * a JSON file containig definitions of types is loaded
 */
- (void) loadDefinitions {
    NSDictionary* definitions = [PryvHealthKit JSONFromFile:@"HealthKitPryvDefinitions"];
    
    //----- streams ----------//
    streamsMap = [[NSMutableDictionary alloc] init];
    [self fillStreamMaprecursive:[definitions objectForKey:@"streams"] withParentId:nil];
    
    
    //----- HKSampletypes ----//
    NSMutableDictionary<NSString*, DefinitionItem*> *defs = [[NSMutableDictionary alloc] init];
    //----- quantities ------//
    NSDictionary* quantities = [definitions objectForKey:@"quantities"];
    for (NSString* key in quantities) {
        NSDictionary* quantity = (NSDictionary*) [quantities objectForKey:key];
        DefinitionItemQuantity* di = [[DefinitionItemQuantity alloc] init];
        di.type = kQuantity;
        di.streamId = [quantity objectForKey:@"streamId"];
        if (streamsMap[di.streamId] == nil) {
             [NSException raise:@"Invalid streamId in definitions"
                         format:@"For [%@] HKUnit [%@] streamId has not been defined in streams", key, di.streamId];
        }
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


@end
