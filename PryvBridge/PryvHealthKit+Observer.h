//
//  PryvBridge
//
//  Created by Perki on 20.07.18.
//  Copyright © 2018 Pryv. All rights reserved.
//

#ifndef PryvHealthkitObserver_h
#define PryvHealthkitObserver_h


#import <HealthKit/HealthKit.h>
#import "PryvHealthKit.h"


@interface PryvHealthKit (Observer)

- (void)initObserver;

- (void)observeHealthKit;

- (void)requestAuthorization;
- (void)updateDataForSampleType:(HKSampleType *)sampleType;
- (void)saveAnchors;

/** private method **/
- (NSMutableDictionary<NSString *, HKQueryAnchor *> *)_anchorDictFromStorage;



@end




#endif
