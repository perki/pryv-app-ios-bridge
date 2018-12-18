//
//  PryvHealthKit+Definitions.m
//  PryvBridge
//
//  Created by Perki on 18.12.18.
//  Copyright © 2018 Pryv. All rights reserved.
//

#import "PryvHealthKit+Definitions.h"



@implementation PryvHealthKit (Definitions)


NSArray<HKSampleType *> *cacheSampletypes = nil;
- (NSArray<HKSampleType *> *)sampleTypes {
    if (cacheSampletypes != nil) {
        return cacheSampletypes;
    }
    NSMutableArray* types = [[NSMutableArray alloc] init];
    for (NSString* key in self.definitionsMap) {
        DefinitionItem* di = [self.definitionsMap objectForKey:key];
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

- (DefinitionItem*) definitionItemForHKSampleType:(HKSample*)sample {
    return [self.definitionsMap objectForKey:[[sample sampleType] identifier]];
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
    self.definitionsMap = defs;
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




@end
