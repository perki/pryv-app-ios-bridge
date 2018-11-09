//
//  PryvController.m
//  PryvBridge
//
//  Created by Perki on 11.11.15.
//  Copyright © 2015 Pryv. All rights reserved.
//

#import "PryvController.h"
#import "SSKeychain.h"  // provided by cocoapod : SSKeychain

#import <PryvApiKit/PryvApiKit.h>
#import "INTULocationManager.h"
#import <CoreLocation/CoreLocation.h>

//
// Implements PYWebLoginDelegate to be able to use PYWebLoginViewController
//


@interface PryvController ()
- (void)initObject;
- (void)loadSavedConnection;
+ (void)saveConnection:(PYConnection *)connection;
+ (void)removeConnection:(PYConnection *)connection;

@end


@implementation PryvController

NSInteger registeredBlocks;
NSInteger savedEventsCount;
BOOL registeredToLocationEvents = FALSE;
CLLocation* lastStoredLocation;


@synthesize connection = _connection;
@synthesize api = _api;

- (NSInteger) savedLocationEvents
{
    return savedEventsCount;
}

- (void) registerToLocationEvents {
    if (registeredToLocationEvents) return;
    registeredToLocationEvents = TRUE;
    INTULocationManager *locMgr = [INTULocationManager sharedInstance];
    registeredBlocks++;
    __block NSInteger num = 0 + registeredBlocks;
    [locMgr subscribeToSignificantLocationChangesWithBlock:^(CLLocation *currentLocation, INTULocationAccuracy achievedAccuracy, INTULocationStatus status) {
        if (status == INTULocationStatusSuccess) {
            NSLog(@"Got location %ld / %ld",num, registeredBlocks);
            [[PryvController sharedInstance] saveLocation:currentLocation];
        }
    }];
}


- (void) saveLocation:(CLLocation *)currentLocation {
    if (! self.connection) return;
    
    // ignore if not preceise enough
    
    if ([NSNumber numberWithFloat:currentLocation.horizontalAccuracy].doubleValue > kMinimalHorizontalAccuracy) {
     
        if (lastStoredLocation != nil &&
            [lastStoredLocation distanceFromLocation:currentLocation] < (currentLocation.horizontalAccuracy * 2)) {
            // if distance between now and last one is smaller that 2x accurancy .. ignore
            
        NSLog(@"Ignoring because of accurancy %d", [NSNumber numberWithFloat:currentLocation.horizontalAccuracy]);
           return;
        }
        if (lastStoredLocation != nil) {
         NSLog(@"Saved bad accurancy of %d because distance is %d ", [NSNumber numberWithFloat:currentLocation.horizontalAccuracy], [lastStoredLocation distanceFromLocation:currentLocation]);
        }
        
    }
    
    lastStoredLocation = currentLocation;
            
    PYEvent *event = [[PYEvent alloc] init];
    event.streamId = kStreamId;
    event.type = @"position/wgs84";
    event.eventContent = @{ @"latitude": [NSNumber numberWithFloat:currentLocation.coordinate.latitude],
                            @"longitude": [NSNumber numberWithFloat:currentLocation.coordinate.longitude],
                            @"horizontalAccuracy": [NSNumber numberWithFloat:currentLocation.horizontalAccuracy],
                            @"altitude": [NSNumber numberWithFloat:currentLocation.altitude],
                            @"verticalAccuracy": [NSNumber numberWithFloat:currentLocation.verticalAccuracy],
                            @"speed": [NSNumber numberWithFloat:currentLocation.speed],
                            @"bearing": [NSNumber numberWithFloat:currentLocation.course]
                            };
    [event setEventDate:currentLocation.timestamp];

    [self.connection eventCreate:event andCacheFirst:YES
                     successHandler:^(NSString *newEventId, NSString *stoppedId, PYEvent *event) {
                         NSLog(@"Logged position");
                         savedEventsCount++;
                          [[NSNotificationCenter defaultCenter] postNotificationName:kAppNewLocationSaved object:nil];
                     } errorHandler:^(NSError *error) {
                         NSLog(@"Error Logging position %@", error);
                     }];
}

#pragma -mark specifc is before

+ (PryvController*)sharedInstance
{
    static PryvController *_sharedInstance;
    static dispatch_once_t onceToken;
    __block BOOL init_done = NO;
    dispatch_once(&onceToken, ^{
        _sharedInstance = [[PryvController alloc] init];
        init_done = YES;
    });
    if (init_done) [_sharedInstance initObject];
    return _sharedInstance;
}

- (void)initObject
{
    [self loadSavedConnection];
    savedEventsCount = 0;
    registeredBlocks = 0;
    lastStoredLocation = nil;
}



#pragma mark --Utilities to load and save Pryv connections: can be reused in other apps

- (void)setConnection:(PYConnection *)pyConn
{
    if (pyConn == _connection) return; // nothing to do
    
    if (_connection) {
        [[self class] removeConnection:_connection]; // remove from the settings
    }
    _connection = pyConn;
    [[self class] saveConnection:_connection];
    
    if (_connection == nil) {
        self.api = nil;
    } else {
        self.api = [[PryvApiKitLight alloc] init:_connection.apiBaseUrl withAccess:_connection.accessToken];
    }
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kAppPryvConnectionChange object:nil];

}


- (void)loadSavedConnection
{
    NSString *lastUsedUsername = [[NSUserDefaults standardUserDefaults] objectForKey:kLastUsedUsernameKey];
    if(lastUsedUsername)
    {
        NSString *accessToken = [SSKeychain passwordForService:kServiceName account:lastUsedUsername];
        
        [self setConnection:[[PYConnection alloc] initWithUsername:lastUsedUsername
                                                      andAccessToken:accessToken]];
        
    }
}

+ (void)saveConnection:(PYConnection *)connection
{
    [[NSUserDefaults standardUserDefaults] setObject:connection.userID forKey:kLastUsedUsernameKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [SSKeychain setPassword:connection.accessToken forService:kServiceName account:connection.userID];
}

+ (void)removeConnection:(PYConnection *)connection
{
    [SSKeychain deletePasswordForService:kServiceName account:connection.userID];
}

@end
