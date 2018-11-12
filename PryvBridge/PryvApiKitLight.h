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

@interface PYLEvent : NSObject
@property NSString* streamId;
@property NSString* type;
@property NSDate* startDate;
@property NSDate* stopDate;
@property id content;
@property NSDictionary* clientData;
- (NSDictionary*) toDictionary;
@end;

@interface PYLStream : NSObject
@property NSString* streamId;
@property NSString* name;
@property NSString* parentId;
@property NSDictionary* clientData;
- (NSDictionary*) toDictionary;
@end;


@interface PryvApiKitLight : NSObject

- (PryvApiKitLight*)init:(NSString*) apiBaseURL withAccess:(NSString*) accessToken;

- (void)postToAPI:(NSString*)path dictionary:(NSDictionary*)content completionHandler:(pryvApiCompletion)completed;
- (void)postToAPI:(NSString*)path array:(NSArray*)content completionHandler:(pryvApiCompletion)completed;
- (void)postToAPI:(NSString*)path string:(NSString*)content completionHandler:(pryvApiCompletion)completed;
- (void)postToAPI:(NSString*)path content:(NSData*)content completionHandler:(pryvApiCompletion)completed;

/**
 * Add streams in the form of
 * { $streamsId$:
 *   { name: $name$,
 *     children: {
 *       $streamsId$: ....,
 *       $streamsId$: ....
 *      }
 *   },
 *   $streamsId$: ....
 * }
 */
- (void)addStreamsHierarchy:(NSDictionary*)dictionary;
- (void)ensureStreamCreated:(void (^)(NSError* e))completed;
- (PYLStream*)streamById:(NSString*)streamId;




@end



#endif /* PryvApiKitLight_h */
