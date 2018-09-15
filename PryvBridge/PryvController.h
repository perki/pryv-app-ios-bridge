//
//  PryvController.h
//  PryvBridge
//
//  Created by Perki on 11.11.15.
//  Copyright © 2015 Pryv. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <CoreLocation/CoreLocation.h>

@class PYConnection;


// the two following strings are used to retrieve infos from NSUserDefaults
#define kServiceName @"com.pryv.app-ios-bridge"
#define kLastUsedUsernameKey @"lastUsedUsernameKey"

// the streamID we will use for tests
#define kStreamId @"location"
#define kStreamDefaultName @"Location"

// define minimal horizontal accuracy
#define kMinimalHorizontalAccuracy 500.00

// Event driven notification
#define kAppPryvConnectionChange  @"kAppPryvConnectionChange"
#define kAppNewLocationSaved  @"kAppNewLocationSaved"

@interface PryvController : NSObject

+ (PryvController*)sharedInstance;

@property (nonatomic, retain) PYConnection *connection;

- (void) saveLocation:(CLLocation *)currentLocation;
- (NSInteger) savedLocationEvents;

- (void) registerToLocationEvents;

@end
