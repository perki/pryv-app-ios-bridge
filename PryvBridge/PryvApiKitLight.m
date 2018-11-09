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
@end

@implementation PryvApiKitLight
@synthesize apiBaseURL, accessToken;

- (PryvApiKitLight*)init:(NSString*) apiBaseURL withAccess:(NSString*) accessToken {
    if (self = [super init]) {
        self.apiBaseURL = apiBaseURL;
        self.accessToken = accessToken;
    }
    return self;
};


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
@end;
