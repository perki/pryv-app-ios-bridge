//
//  PryvApiKitLight.h
//  This 
//
//  Created by Perki on 07.11.18.
//  Copyright © 2018 Pryv. All rights reserved.
//

#ifndef PryvApiKitLight_h
#define PryvApiKitLight_h

typedef void (^pryvApiCompletion)(NSDictionary * _Nullable response, NSError * _Nullable error);

@interface PryvApiKitLight : NSObject

- (PryvApiKitLight*)init:(NSString*) apiBaseURL withAccess:(NSString*) accessToken;

- (void)postToAPI:(NSString*)path dictionary:(NSDictionary*)content completionHandler:(pryvApiCompletion)completed;
- (void)postToAPI:(NSString*)path array:(NSArray*)content completionHandler:(pryvApiCompletion)completed;
- (void)postToAPI:(NSString*)path string:(NSString*)content completionHandler:(pryvApiCompletion)completed;
- (void)postToAPI:(NSString*)path content:(NSData*)content completionHandler:(pryvApiCompletion)completed;

@end

@interface PYLEvent : NSObject
@property NSString* streamId;
@property NSString* type;
@property NSDate* startDate;
@property NSDate* stopDate;
@property id content;
@property NSDictionary* clientData;
- (NSDictionary*) toDictionary;
@end;


#endif /* PryvApiKitLight_h */
