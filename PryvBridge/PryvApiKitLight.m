//
//  PryvApiKitLight.m
//  PryvBridge
//
//  Created by Perki on 07.11.18.
//  Copyright © 2018 Pryv. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "PryvApiKitLight.h"

@interface PryvApiKitLight ()
@property NSString* apiBaseURL;
@property NSString* accessToken;
@property NSMutableDictionary<NSString*, PYLStream*> *streamsMap;
- (void) fillStreamMaprecursive:(NSDictionary*) streams withParentId:(NSString*) parentId ;
/** from the streamMap return root streams to be added to permission requests **/
- (NSArray*)getRootStreamsPermissions;
@end

@implementation PryvApiKitLight
@synthesize apiBaseURL, accessToken, streamsMap;

- (PryvApiKitLight*)init:(NSString*) apiBaseURL withAccess:(NSString*) accessToken {
    if (self = [super init]) {
        self.apiBaseURL = apiBaseURL;
        self.accessToken = accessToken;
        self.streamsMap = [[NSMutableDictionary alloc] init];
    }
    return self;
};


/**
 * Private Method,
 * Recursively follow the "streams" definitions and create a flat map with
 * streamID: { name, parentId }
 */
- (void) fillStreamMaprecursive:(NSDictionary*)streams withParentId:(NSString*) parentId {
    for (NSString* key in streams) {
        PYLStream* stream = [[PYLStream alloc] init];
        stream.name = streams[key][@"name"];
        stream.parentId = parentId;
        stream.streamId = key;
        [self.streamsMap setObject:stream  forKey:key];
        NSDictionary* children = streams[key][@"children"];
        if (children != nil) {
            [self fillStreamMaprecursive:children withParentId:key];
        }
    }
}

- (PYLStream*)streamById:(NSString*)streamId {
    return [self.streamsMap objectForKey:streamId];
}

- (void) addStreamsHierarchy:(NSDictionary *)dictionary
{
    [self fillStreamMaprecursive:dictionary withParentId:nil];
}

# pragma mark - Stream creation

- (void)ensureStreamCreated:(void (^)(NSError* e))completed {
    
    NSMutableArray *batchCMD = [[NSMutableArray alloc] init];
    
    for (NSString* streamId in streamsMap) {
        if (streamsMap[streamId].parentId != nil) { // only add non-root streams
            [batchCMD addObject:@{@"method": @"streams.create",
                                  @"params": [streamsMap[streamId] toDictionary] } ];
        }
    }
    
    [self postToAPI:@"" array:batchCMD completionHandler:^(NSDictionary * _Nullable response, NSError * _Nullable error) {
        NSLog(@"Streams created");
        // Here we may check that response codes are either "Stream Exists" or "Stream created"
        completed(error);
    }];
}

/** from the streamMap return root streams to be added to permission requests **/
- (NSArray*)getRootStreamsPermissions {
    if (self.streamsMap == nil) {
        [NSException raise:@"Error streamMap must be initalized" format:@""];
        return nil;
    }
    NSMutableArray *permissions = [[NSMutableArray alloc] init];
    
    for (NSString* streamId in self.streamsMap) {
        if (self.streamsMap[streamId].parentId == nil) { // only add non-root streams
            [permissions addObject:@{
                                     @"streamId": streamId,
                                     @"defaultName": self.streamsMap[streamId].name,
                                     @"level": @"manage"}];
        }
    }
    return permissions;
}

# pragma mark - POST to API

- (void)postToAPI:(NSString*)path dictionary:(NSDictionary*)content completionHandler:(pryvApiCompletion)completed
{
    [self postToAPI:path content:[NSJSONSerialization dataWithJSONObject:content
                                                                 options:0
                                                                   error:nil]
     completionHandler:completed];
}

- (void)postToAPI:(NSString*)path array:(NSArray*)content completionHandler:(pryvApiCompletion)completed
{
    
    [self postToAPI:path content:[NSJSONSerialization dataWithJSONObject:content
                                                                 options:0
                                                                   error:nil]
    completionHandler:completed];
}

- (void)postToAPI:(NSString*)path string:(NSString*)content completionHandler:(pryvApiCompletion)completed
{
    [self postToAPI:path content:[content dataUsingEncoding:NSUTF8StringEncoding] completionHandler:completed];
}

- (void)postToAPI:(NSString*)path content:(NSData*)content completionHandler:(pryvApiCompletion)completed
{
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@",self.apiBaseURL, path]];
    
    // Create a POST request with our JSON as a request body.
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = @"POST";
    request.HTTPBody = content;
    [request addValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request addValue:@"application/json" forHTTPHeaderField:@"Accept"];
    [request addValue:self.accessToken forHTTPHeaderField:@"Authorization"];
    
    //NSLog(@"%@", [[NSString alloc] initWithData:content encoding:NSUTF8StringEncoding]);
    
    // Create a task.
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request
                                                                 completionHandler:^(NSData *data,
                                                                                     NSURLResponse *response,
                                                                                     NSError *error)
      {
          if (!error)
          {
              
              NSError *e = nil;
              NSDictionary* jsonDictionnary = [NSJSONSerialization JSONObjectWithData: data options: NSJSONReadingMutableLeaves error: &e];
              
              if (!jsonDictionnary) {
                  NSLog(@"Error parsing JSON: %@", e);
                  if (completed != nil) { completed(nil, e);}
              } else {
                  NSLog(@"resp: %@ = %@",jsonDictionnary[@"meta"],jsonDictionnary[@"msg"]);
                  NSLog(@"Dictionary count: %lu", (unsigned long)jsonDictionnary.count);
                  if (completed != nil) { completed(jsonDictionnary, nil);}
              }
          }
          else
          {
              NSLog(@"Error: %@", error.localizedDescription);
              if (completed != nil) { completed(nil, error);}
          }
      }];
    
    // Start the task.
    [task resume];
}

@end

@implementation PYLEvent
@synthesize streamId, type, startDate, stopDate, content, clientData;
- (NSDictionary*) toDictionary {
    NSMutableDictionary* result = [NSMutableDictionary
                                   dictionaryWithDictionary:@{
                                                              @"type": self.type,
                                                              @"streamId": self.streamId,
                                                              }];
    if (startDate) {
        [result setObject:[NSNumber numberWithDouble:[self.startDate timeIntervalSince1970]] forKey:@"time"];
        if (stopDate && [startDate compare:stopDate] != NSOrderedSame) {
            [result setObject:[NSNumber numberWithDouble:[self.stopDate timeIntervalSinceDate:startDate]] forKey:@"duration"];
        }
    }
    
    if (content) {
        [result setObject:content forKey:@"content"];
    }
    
    if (clientData) {
       [result setObject:clientData forKey:@"clientData"];
    }
    
    return result;
};
@end


@implementation PYLStream
@synthesize streamId, name, parentId, clientData;
- (NSDictionary*) toDictionary {
    NSMutableDictionary* result = [NSMutableDictionary
                                   dictionaryWithDictionary:@{
                                                              @"name": self.name,
                                                              @"streamId": self.streamId,
                                                              }];
  
    if (parentId) {
        [result setObject:parentId forKey:@"parentId"];
    }
    
    if (clientData) {
        [result setObject:clientData forKey:@"clientData"];
    }
    
    return result;
};
@end
