/*
 * Copyright (c) 2018, Psiphon Inc.
 * All rights reserved.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 */

//
//  RequestBuilder.m
//  PsiCashLib
//

#import <Foundation/Foundation.h>
#import "RequestBuilder.h"

@implementation RequestBuilder {
    NSString *path;
    NSString *method;
    NSString *scheme;
    NSString *hostname;
    NSNumber *port;
    NSArray<NSURLQueryItem*> *queryItems;
    NSDictionary<NSString*,NSString*> *headers;
    NSDictionary *metadata;
    NSUInteger attempt;
    NSTimeInterval timeout;
}

- (id)initWithPath:(NSString*_Nonnull)path
            method:(NSString*_Nonnull)method
            scheme:(NSString*_Nonnull)scheme
          hostname:(NSString*_Nonnull)hostname
              port:(NSNumber*_Nonnull)port
        queryItems:(NSArray<NSURLQueryItem*>*_Nullable)queryItems
           headers:(NSDictionary<NSString*,NSString*>*_Nullable)headers
          metadata:(NSDictionary*_Nonnull)metadata
           timeout:(NSTimeInterval)timeout
{
    self->path = path;
    self->method = method;
    self->scheme = scheme;
    self->hostname = hostname;
    self->port = port;
    self->queryItems = queryItems;
    self->headers = headers;
    self->metadata = metadata;
    self->attempt = 0;
    return self;
}

- (void)setAttempt:(NSUInteger)attempt
{
    self->attempt = attempt;
}

- (void)addHeaders:(NSDictionary<NSString*,NSString*>*_Nullable)headers
{
    NSMutableDictionary<NSString*,NSString*>* mutableHeaders = [NSMutableDictionary dictionaryWithDictionary:self->headers];
    [mutableHeaders addEntriesFromDictionary:headers];
    self->headers = mutableHeaders;
}

- (NSMutableURLRequest*_Nonnull)request
{
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    [request setCachePolicy:NSURLRequestUseProtocolCachePolicy];
    [request setTimeoutInterval:self->timeout];

    [request setHTTPMethod:method];

    NSURLComponents *urlComponents = [[NSURLComponents alloc] init];
    urlComponents.scheme = self->scheme;
    urlComponents.host = self->hostname;
    urlComponents.port = self->port;
    urlComponents.path = self->path;
    urlComponents.queryItems = self->queryItems;

    [request setURL:urlComponents.URL];

    for (NSString *headerKey in self->headers) {
        [request setValue:self->headers[headerKey] forHTTPHeaderField:headerKey];
    }

    NSMutableDictionary *mutableMetdata = [NSMutableDictionary dictionaryWithDictionary:self->metadata];
    mutableMetdata[@"attempt"] = (self->attempt > 0) ? [NSNumber numberWithUnsignedInteger:attempt] : NSNull.null;

    NSJSONWritingOptions jsonOpts = 0;
    if (@available(iOS 11.0, *)) {
        // We're going to sort the keys if possible to make testing easier
        // (expected results can be sane).
        jsonOpts = NSJSONWritingSortedKeys;
    }

    NSError *error;
    NSData *metadataJSON = [NSJSONSerialization dataWithJSONObject:mutableMetdata
                                                           options:jsonOpts
                                                             error:&error];
    if (!error && metadataJSON) {
        NSString *stringJSON = [[NSString alloc] initWithData:metadataJSON
                                                     encoding:NSUTF8StringEncoding];
        [request setValue:stringJSON
       forHTTPHeaderField:@"X-PsiCash-Metadata"];
    }

    return request;
}

@end
