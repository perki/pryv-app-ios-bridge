//
//  ViewController.m
//  PryvBridge
//
//  Created by Perki on 11.03.15.
//  Copyright (c) 2015 Pryv. All rights reserved.
//

#import "ViewController.h"

#import "PYWebLoginViewController.h"
#import "PryvController.h"

#import <PryvApiKit/PryvApiKit.h>
#import "INTULocationManager.h"
#import <CoreLocation/CoreLocation.h>

#import <HealthKit/HealthKit.h>

//
// Implements PYWebLoginDelegate to be able to use PYWebLoginViewController
//
@interface ViewController () <PYWebLoginDelegate, UIAlertViewDelegate>
- (void)pryvConnectionChange:(NSNotification*)notification;
- (void)pryvLocationSaved:(NSNotification*)notification;
- (PYConnection*)pyConn;
- (void)checkLocationStatus;
@end

@implementation ViewController

@synthesize locationButton;
@synthesize locationLabel;
@synthesize locationCount;


@synthesize healthButton;
@synthesize healthLabel;
@synthesize healthCount;

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self checkLocationStatus ];
    
    INTULocationManager *locMgr = [INTULocationManager sharedInstance];
    [locMgr subscribeToSignificantLocationChangesWithBlock:^(CLLocation *currentLocation, INTULocationAccuracy achievedAccuracy, INTULocationStatus status) {
        [self checkLocationStatus ];
        if (status == INTULocationStatusSuccess) {
            [[PryvController sharedInstance] saveLocation:currentLocation];
        }
    }];
    
  
    
    /**
     * Listen to connection changes
     */
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(pryvConnectionChange:)
                                                 name:kAppPryvConnectionChange
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(pryvLocationSaved:)
                                                 name:kAppNewLocationSaved
                                               object:nil];
    
    
    [self pyConn]; // will trigger loading of existing connection
    
    
    // --- Health Kit
    
    if ([HKHealthStore isHealthDataAvailable] == NO) {
        // If our device doesn't support HealthKit -> return.
        return;
    }
    
    NSArray *readTypes = @[[HKObjectType quantityTypeForIdentifier:HKQuantityTypeIdentifierBodyMass]];
    
    
    HKHealthStore* healthStore = [[HKHealthStore alloc] init];
    [healthStore requestAuthorizationToShareTypes:nil
                                             readTypes:[NSSet setWithArray:readTypes] completion:nil];
}

- (NSDate *)readMass {
    NSError *error;
    NSDate *dateOfBirth = [self.healthStore dateOfBirthWithError:&error];   // Convenience method of HKHealthStore to get date of birth directly.
    
    if (!dateOfBirth) {
        NSLog(@"Either an error occured fetching the user's age information or none has been stored yet. In your app, try to handle this gracefully.");
    }
    
    return dateOfBirth;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/** sugar to get the active Pryv connection **/
- (PYConnection*)pyConn {
    return [[PryvController sharedInstance] connection];
}

- (void)checkLocationStatus {
    BOOL showAlertSetting = false;
    BOOL showInitLocation = false;
    
    NSString* locationMessage = @"Location Disabled";
    if ([CLLocationManager locationServicesEnabled]) {
        
        switch ([CLLocationManager authorizationStatus]) {
                case kCLAuthorizationStatusDenied:
                showAlertSetting = true;
                locationMessage =@"Location Denied";
                break;
                case kCLAuthorizationStatusRestricted:
                showAlertSetting = true;
                locationMessage =@"Location Restricted";
                break;
                case kCLAuthorizationStatusAuthorizedAlways:
                showInitLocation = true;
                locationMessage =@"Location Authorized Always";
                break;
                case kCLAuthorizationStatusAuthorizedWhenInUse:
                showInitLocation = true;
                locationMessage =@"Location Authorized When In Use";
                break;
                case kCLAuthorizationStatusNotDetermined:
                showInitLocation = false;
                locationMessage =@"Location Not Determined";
                break;
            default:
                break;
        }
    }
    [locationLabel setText:locationMessage];
    
}

- (void) pryvLocationSaved:(NSNotification *)notification {
    [locationCount setText:[NSString stringWithFormat:@"%d",[[PryvController sharedInstance] savedLocationEvents]]];
}

- (IBAction)locationButtonPressed:(id)sender {
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:UIApplicationOpenSettingsURLString]];
}

- (IBAction)signinButtonPressed: (id) sender  {
    if (self.pyConn) { // already logged in -> Propose to log Off
        [[[UIAlertView alloc] initWithTitle:@"Sign off?"
                                                        message:@""
                                                       delegate:self
                                              cancelButtonTitle:@"Cancel"
                                              otherButtonTitles:@"OK",nil] show];
        return;
    }
    
    
    /** 
     * permissions sets is manage for all Streams
     * In JSON that would do:
     * [ { 'streamId' : 'com.pryv.exampleapp.stream', 
     *     'defaultName' : 'Pryv iOS PryvBridge',
     *      'level' : 'manage'} ]
     */
    NSArray *permissions = @[ @{ kPYAPIConnectionRequestStreamId : kStreamId ,
                                 kPYAPIConnectionRequestDefaultStreamName : kStreamDefaultName,
                                 kPYAPIConnectionRequestLevel: kPYAPIConnectionRequestManageLevel}];
                              
    
    
    __unused
    PYWebLoginViewController *webLoginController =
    [PYWebLoginViewController requestConnectionWithAppId:@"pryv-ios-bridge"
                                          andPermissions:permissions
                                                delegate:self];
    
}

/**
 * Connection changed (can be nil to remove)
 */
- (void)pryvConnectionChange:(NSNotification*)notification
{
    if (self.pyConn) { // Signed In
        [self.signinButton setTitle:self.pyConn.userID forState:UIControlStateNormal];
        
        [self.pyConn streamsEnsureFetched:^(NSError *error) {
            if (error) {
                NSLog(@"<FAIL> fetching stream at streamSetup");
                return;
            }
        }];

        
    } else { // Signed off
        [self.signinButton setTitle:@"Sign in" forState:UIControlStateNormal];
    }
}


#pragma mark --Alert Views

- (void)alertView:(UIAlertView *)theAlert clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (buttonIndex == 1) { // OK
        [[PryvController sharedInstance] setConnection:nil];
    }
}



#pragma maek -- Add Note

- (void)addNoteButtonPressed:(id)sender
{
    if (! self.pyConn) {
        [[[UIAlertView alloc] initWithTitle:@"Sign in before adding notes"
                                    message:@""
                                   delegate:self
                          cancelButtonTitle:@"OK"
                          otherButtonTitles:nil] show];
        return;
    }
    
    PYEvent *event = [[PYEvent alloc] init];
    event.streamId = kStreamId;
    event.eventContent = @"Hello World";
    event.type = @"note/txt";
    
    [self.pyConn eventCreate:event
      successHandler:^(NSString *newEventId, NSString *stoppedId, PYEvent *event) {
        NSLog(@"Event created succefully with ID: %@", newEventId);
    } errorHandler:^(NSError *error) {
        NSLog(@"Event creation Error: %@", error);
    }];
    
}

#pragma mark --PYWebLoginDelegate

- (UIViewController *)pyWebLoginGetController {
    return self;
}

- (BOOL)pyWebLoginShowUIViewController:(UIViewController*)loginViewController {
    return NO;
};

/**
 * Called after a successfull sign-in
 */
- (void)pyWebLoginSuccess:(PYConnection*)pyConn {
    NSLog(@"Signin With Success %@ %@", pyConn.userID, pyConn.accessToken);
    [[PryvController sharedInstance] setConnection:pyConn];
}

- (void)pyWebLoginAborted:(NSString*)reason {
    NSLog(@"Signin Aborted: %@",reason);
}

- (void) pyWebLoginError:(NSError*)error {
    NSLog(@"Signin Error: %@",error);
}


@end
