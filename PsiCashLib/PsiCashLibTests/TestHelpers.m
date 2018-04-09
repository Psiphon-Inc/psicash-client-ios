//
//  TestHelpers.m
//  PsiCashLibTests
//

#import <Foundation/Foundation.h>
#import "TestHelpers.h"
#import "UserInfo.h"
#import "HTTPStatusCodes.h"

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

- (void)clearUserInfo;

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

+ (void)clearUserInfo:(PsiCash*_Nonnull)psiCash
{
    [[psiCash valueForKey:@"userInfo"] clear];
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
                                                      value:@TEST_ONE_TRILLION_ONE_SECOND_DISTINGUISHER]];

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

@end

