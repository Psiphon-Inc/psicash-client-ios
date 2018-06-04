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
//  TestHelpers.m
//  PsiCashLibTests
//

#import <Foundation/Foundation.h>
#import "TestHelpers.h"
#import "UserInfo.h"
#import "HTTPStatusCodes.h"



NSString * const TEST_SERVER_SCHEME = @"https";
NSString * const TEST_SERVER_HOSTNAME = @"dev-api.psi.cash";
int const TEST_SERVER_PORT = 443;

/*
// For local testing
NSString * const TEST_SERVER_SCHEME = @"http";
NSString * const TEST_SERVER_HOSTNAME = @"localhost";
int const TEST_SERVER_PORT = 51337;
*/


// Expose some private methods to help with testing
@interface PsiCash (Testing)
- (NSMutableURLRequest*_Nonnull)createRequestFor:(NSString*_Nonnull)path
                                      withMethod:(NSString*_Nonnull)method
                                  withQueryItems:(NSArray*_Nullable)queryItems
                               includeAuthTokens:(BOOL)includeAuthTokens;

- (void)doRequestWithRetry:(NSURLRequest*_Nonnull)request
                  useCache:(BOOL)useCache
         completionHandler:(void (^_Nonnull)(NSData*_Nullable data,
                                             NSHTTPURLResponse*_Nullable response,
                                             NSError*_Nullable error))completionHandler;

- (void)setRequestMutators:(NSArray*)mutators;
- (void)clearRequestMutators;
- (void)requestMutator:(NSMutableURLRequest*)request;
@end

@implementation PsiCash (Testing)

// Global vars, not ivars, which is what they should be. I can't figure out how to make an ivar in an extension. Let's hope these tests aren't concurrent!
NSArray *requestMutators;
int requestMutatorsIndex;

- (void)setRequestMutators:(NSArray*)mutators
{
    requestMutators = mutators;
    requestMutatorsIndex = 0;
}

- (void)clearRequestMutators
{
    requestMutators = nil;
    requestMutatorsIndex = 0;
}

+ (void)requestMutator:(NSMutableURLRequest*)request
{
    if (requestMutators != nil) {
        if (requestMutatorsIndex >= requestMutators.count) {
            // We're beyond our mutators, so don't change anything.
            return;
        }

        // Any given mutator item can be nil
        if (requestMutators[requestMutatorsIndex] &&
            requestMutators[requestMutatorsIndex] != [NSNull null]) {
            [request setValue:requestMutators[requestMutatorsIndex]
           forHTTPHeaderField:@TEST_HEADER];
        }
        requestMutatorsIndex += 1;
    }
}
@end

@implementation TestHelpers

+ (PsiCash*_Nonnull)newPsiCash
{
    PsiCash *psiCash = [[PsiCash alloc] init];

    // Make sure we're running against the test (dev) server.
    [psiCash setValue:TEST_SERVER_SCHEME forKey:@"serverScheme"];
    [psiCash setValue:TEST_SERVER_HOSTNAME forKey:@"serverHostname"];
    [psiCash setValue:[[NSNumber alloc] initWithInt:TEST_SERVER_PORT] forKey:@"serverPort"];
    return psiCash;
}

+ (UserInfo*_Nonnull)userInfo:(PsiCash*_Nonnull)psiCash
{
    return [psiCash valueForKey:@"userInfo"];
}

+ (void)clearUserInfo:(PsiCash*_Nonnull)psiCash
{
    [[TestHelpers userInfo:psiCash] clear];
}

+ (void)setIsAccount:(PsiCash*_Nonnull)psiCash
{
    [[psiCash valueForKey:@"userInfo"] setIsAccount:YES];
}

+ (NSDictionary*)getAuthTokens:(PsiCash*_Nonnull)psiCash
{
    return [[psiCash valueForKey:@"userInfo"] authTokens];
}

+ (void)setRequestMutators:(PsiCash*_Nonnull)psiCash
                  mutators:(NSArray*_Nonnull)mutators
{
    [psiCash setRequestMutators:mutators];
}

+ (void)checkMutatorSupport:(PsiCash*_Nonnull)psiCash
                 completion:(void (^_Nonnull)(BOOL supported))completionHandler
{
    [TestHelpers setRequestMutators:psiCash
                           mutators:@[@"CheckEnabled"]];  // sleep for 11 secs

    NSMutableURLRequest *request = [psiCash createRequestFor:@"/refresh-state"
                                                  withMethod:@"GET"
                                              withQueryItems:nil
                                           includeAuthTokens:NO];

    NSURLSession *session = [NSURLSession sharedSession];

    NSURLSessionDataTask *task = [session dataTaskWithRequest:request
                                            completionHandler:
                                  ^(NSData *data, NSURLResponse *response, NSError *error)
                                  {
                                      if (error) {
                                          NSLog(@"checkMutatorSupport error: %@", error);
                                          completionHandler(NO);
                                          return;
                                      }

                                      NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse*)response;

                                      completionHandler(httpResponse.statusCode == kHTTPStatusAccepted);
                                  }];
    [task resume];
}

+ (void)make1TRewardRequest:(PsiCash*_Nonnull)psiCash
                 completion:(void (^_Nonnull)(BOOL success))completionHandler
{
    NSMutableArray *queryItems = [NSMutableArray new];
    [queryItems addObject:[NSURLQueryItem queryItemWithName:@"class"
                                                      value:@TEST_CREDIT_TRANSACTION_CLASS]];
    [queryItems addObject:[NSURLQueryItem queryItemWithName:@"distinguisher"
                                                      value:@TEST_ONE_TRILLION_ONE_MICROSECOND_DISTINGUISHER]];

    NSMutableURLRequest *request = [psiCash createRequestFor:@"/transaction"
                                                  withMethod:@"POST"
                                              withQueryItems:queryItems
                                           includeAuthTokens:YES];

    NSURLSession *session = [NSURLSession sharedSession];

    NSURLSessionDataTask *task = [session dataTaskWithRequest:request
                                            completionHandler:
                                  ^(NSData *data, NSURLResponse *response, NSError *error)
                                  {
                                      if (error) {
                                          NSLog(@"make1TRewardRequest error: %@", error);
                                          completionHandler(NO);
                                          return;
                                      }

                                      NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse*)response;

                                      completionHandler(httpResponse.statusCode == kHTTPStatusOK);
                                  }];
    [task resume];
}

+ (BOOL)is:(id)a equalTo:(id)b
{
    if (!a && !b) {
        return YES;
    }
    else if (!a || !b) {
        return NO;
    }
    return [a isEqual:b];
}

@end

