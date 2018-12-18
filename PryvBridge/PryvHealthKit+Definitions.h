//
//  PryvHealthKit+Definitions.h
//  PryvBridge
//
//  Created by Perki on 18.12.18.
//  Copyright © 2018 Pryv. All rights reserved.
//

#import "PryvHealthKit.h"

NS_ASSUME_NONNULL_BEGIN



@interface PryvHealthKit (Definitions)

- (void) loadDefinitions;
+ (NSDictionary *)JSONFromFile:(NSString*)fileName;
- (NSArray<HKSampleType *> *)sampleTypes;

- (DefinitionItem*) definitionItemForHKSampleType:(HKSample*)sample;


@end




NS_ASSUME_NONNULL_END
