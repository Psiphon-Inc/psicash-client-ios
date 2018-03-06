//
//  PsiCash.m
//  PsiCashLib
//

#import "PsiCash.h"
#import "NSError+NSErrorExt.h"
#import "UserIdentity.h"

/* TODO
 - Consider using NSUbiquitousKeyValueStore instead of NSUserDefaults for
 cross-device synchronized storage. (Not using it for now because it introduces
 complexity.)
 - Have init() take a queue on which the completion calls should be made? (Like
   PsiphonTunnel does.)
 */

/*
NOTES
 - Methods like getBalance are specifically not checking if authTokens have been
   properly populated before trying to use them. We (probably?) don't want to call
   the completion block on the queue that is calling our method, so we'll let the
   request attempt go through and fail with "401 Authorization Required", at which
   point the completion block will be called. This shouldn't happen anyway, as it
   indicates an incorrect use of the library.
 - See the note at the bottom of this file about proxy support.
*/

NSString * const PSICASH_SERVER_HOSTNAME = @"127.0.0.1:51337"; // TODO
NSTimeInterval const TIMEOUT_SECS = 5.0; // TODO
NSString * const AUTH_HEADER = @"X-PsiCash-Auth";

@implementation PsiCash {
    UserIdentity *userID;
}

# pragma mark - Init

- (id)init
{
    // authTokens may still be nil if the value has never been stored.
    self->userID = [[UserIdentity alloc] init];

    return self;
}

#pragma mark - GetBalance

- (void)getBalance:(void (^)(NSNumber* balance, BOOL isAccount, NSError *error))completionBlock
{
    NSMutableURLRequest *request = [PsiCash makeRequestFor:@"/balance" withMethod:@"GET" withAuthTokens:self->userID.authTokens];

    NSURLSession *session = [NSURLSession sharedSession];

    NSURLSessionDataTask *task = [session dataTaskWithRequest:request
                                            completionHandler:
                                  ^(NSData *data, NSURLResponse *response, NSError *error) {
                                      if (error) {
                                          error = [NSError errorWrapping:error withMessage:@"request failed" fromFunction:__FUNCTION__];
                                          completionBlock(nil, false, error);
                                          return;
                                      }
                                      else if (!data) {
                                          error = [NSError errorWithMessage:@"request returned no data" fromFunction:__FUNCTION__];
                                          completionBlock(nil, false, error);
                                          return;
                                      } else {
                                          NSNumber* balance;
                                          BOOL isAccount;
                                          NSError* error;
                                          [PsiCash parseGetBalanceResponse:data balance:&balance isAccount:&isAccount withError:&error];
                                          if (error != nil) {
                                              error = [NSError errorWrapping:error withMessage:@"" fromFunction:__FUNCTION__];
                                              completionBlock(nil, false, error);
                                              return;
                                          }

                                          self->userID.isAccount = isAccount;

                                          completionBlock(balance, isAccount, nil);
                                          return;
                                      }
                                  }];
    [task resume];
}

+ (void)parseGetBalanceResponse:(NSData*)jsonData balance:(NSNumber**)balance isAccount:(BOOL*)isAccount withError:(NSError**)error
{
    *error = nil;
    *balance = 0;
    *isAccount = false;

    id object = [NSJSONSerialization
                 JSONObjectWithData:jsonData
                 options:0
                 error:error];

    if (*error) {
        *error = [NSError errorWrapping:*error withMessage:@"NSJSONSerialization failed" fromFunction:__FUNCTION__];
        return;
    }

    if (![object isKindOfClass:[NSDictionary class]]) {
        *error = [NSError errorWithMessage:@"Invalid JSON structure" fromFunction:__FUNCTION__];
        return;
    }

    NSDictionary* data = object;

    // Note: isKindOfClass is false if the key isn't found

    if (![data[@"Balance"] isKindOfClass:NSNumber.class]) {
        *error = [NSError errorWithMessage:@"Balance is not a number" fromFunction:__FUNCTION__];
        return;
    }
    *balance = data[@"Balance"];

    if (![data[@"IsAccount"] isKindOfClass:NSNumber.class]) {
        *error = [NSError errorWithMessage:@"IsAccount is not a number" fromFunction:__FUNCTION__];
        return;
    }
    *isAccount = [(NSNumber*)data[@"IsAccount"] boolValue];
}

#pragma mark - NewTracker

- (void)newTracker:(void (^)(NSDictionary* authTokens, NSError *error))completionBlock
{
    NSMutableURLRequest *request = [PsiCash makeRequestFor:@"/new-tracker" withMethod:@"POST" withAuthTokens:nil];

    NSURLSession *session = [NSURLSession sharedSession];

    NSURLSessionDataTask *task = [session dataTaskWithRequest:request
                                            completionHandler:
                                  ^(NSData *data, NSURLResponse *response, NSError *error) {
                                      if (error) {
                                          error = [NSError errorWrapping:error withMessage:@"request failed" fromFunction:__FUNCTION__];
                                          completionBlock(nil, error);
                                          return;
                                      }
                                      else if (!data) {
                                          error = [NSError errorWithMessage:@"request returned no data" fromFunction:__FUNCTION__];
                                          completionBlock(nil, error);
                                          return;
                                      } else {
                                          NSDictionary* authTokens;
                                          NSError* error;
                                          [PsiCash parseNewTrackerResponse:data authTokens:&authTokens withError:&error];
                                          if (error != nil) {
                                              error = [NSError errorWrapping:error withMessage:@"" fromFunction:__FUNCTION__];
                                              completionBlock(nil, error);
                                              return;
                                          }

                                          [self->userID setAuthTokens:authTokens isAccount:false];

                                          completionBlock(authTokens, nil);
                                          return;
                                      }
                                  }];
    [task resume];

}

+ (void)parseNewTrackerResponse:(NSData*)jsonData authTokens:(NSDictionary**)authTokens withError:(NSError**)error
{
    *error = nil;
    *authTokens = 0;

    id object = [NSJSONSerialization
                 JSONObjectWithData:jsonData
                 options:0
                 error:error];

    if (*error) {
        *error = [NSError errorWrapping:*error withMessage:@"NSJSONSerialization failed" fromFunction:__FUNCTION__];
        return;
    }

    if (![object isKindOfClass:[NSDictionary class]]) {
        *error = [NSError errorWithMessage:@"Invalid JSON structure" fromFunction:__FUNCTION__];
        return;
    }

    NSDictionary* data = object;

    // Sanity check that there are at least three tokens present

    int tokensFound = 0;
    for (id key in data) {
        id value = [data objectForKey:key];

        // Note: isKindOfClass is false if the value is nil
        if (![value isKindOfClass:NSString.class]) {
            *error = [NSError errorWithMessage:@"token is not a string" fromFunction:__FUNCTION__];
            return;
        }
        else if ([(NSString*)value length] == 0) {
            *error = [NSError errorWithMessage:@"token string is empty" fromFunction:__FUNCTION__];
            return;
        }

        tokensFound += 1;
    }

    if (tokensFound < 3) {
        *error = [NSError errorWithMessage:@"not enough tokens received" fromFunction:__FUNCTION__];
        return;
    }

    *authTokens = data;
}

#pragma mark - ValidateTokens

- (void)validateTokens:(void (^)(BOOL isAccount, NSDictionary* tokensValid, NSError *error))completionBlock
{
    NSMutableURLRequest *request = [PsiCash makeRequestFor:@"/validate-tokens" withMethod:@"GET" withAuthTokens:self->userID.authTokens];

    NSURLSession *session = [NSURLSession sharedSession];

    NSURLSessionDataTask *task = [session dataTaskWithRequest:request
                                            completionHandler:
                                  ^(NSData *data, NSURLResponse *response, NSError *error) {
                                      if (error) {
                                          error = [NSError errorWrapping:error withMessage:@"request failed" fromFunction:__FUNCTION__];
                                          completionBlock(false, nil, error);
                                          return;
                                      }
                                      else if (!data) {
                                          error = [NSError errorWithMessage:@"request returned no data" fromFunction:__FUNCTION__];
                                          completionBlock(false, nil, error);
                                          return;
                                      } else {
                                          BOOL isAccount;
                                          NSDictionary* tokensValid;
                                          NSError* error;
                                          [PsiCash parseValidateTokensResponse:data isAccount:&isAccount tokensValid:&tokensValid withError:&error];
                                          if (error != nil) {
                                              error = [NSError errorWrapping:error withMessage:@"" fromFunction:__FUNCTION__];
                                              completionBlock(false, nil, error);
                                              return;
                                          }

                                          self->userID.isAccount = isAccount;

                                          completionBlock(isAccount, tokensValid, nil);
                                          return;
                                      }
                                  }];
    [task resume];

}

+ (void)parseValidateTokensResponse:(NSData*)jsonData isAccount:(BOOL*)isAccount tokensValid:(NSDictionary**)tokensValid withError:(NSError**)error
{
    *error = nil;
    *isAccount = NO;
    *tokensValid = 0;

    id object = [NSJSONSerialization
                 JSONObjectWithData:jsonData
                 options:0
                 error:error];

    if (*error) {
        *error = [NSError errorWrapping:*error withMessage:@"NSJSONSerialization failed" fromFunction:__FUNCTION__];
        return;
    }

    if (![object isKindOfClass:[NSDictionary class]]) {
        *error = [NSError errorWithMessage:@"Invalid JSON structure" fromFunction:__FUNCTION__];
        return;
    }

    NSDictionary* data = object;

    if (![data[@"IsAccount"] isKindOfClass:NSNumber.class]) {
        *error = [NSError errorWithMessage:@"IsAccount is not a number" fromFunction:__FUNCTION__];
        return;
    }
    *isAccount = [(NSNumber*)data[@"IsAccount"] boolValue];

    if (![data[@"TokensValid"] isKindOfClass:NSDictionary.class]) {
        *error = [NSError errorWithMessage:@"TokensValid is not a dictionary" fromFunction:__FUNCTION__];
        return;
    }
    *tokensValid = data[@"TokensValid"];
}

#pragma mark - ValidateOrAcquireTokens

- (void)validateOrAcquireTokens:(void (^)(NSArray *validTokenTypes, BOOL isAccount, NSError *error))completionBlock
{
    NSDictionary *authTokens = self->userID.authTokens;
    if (!authTokens || [authTokens count] == 0) {
        // No tokens. Get new Tracker tokens.
        [self newTracker:^(NSDictionary *authTokens, NSError *error) {
            if (error) {
                error = [NSError errorWrapping:error withMessage:@"newTracker request failed" fromFunction:__FUNCTION__];
                completionBlock(nil, false, error);
                return;
            }

            [self->userID setAuthTokens:authTokens isAccount:false];

            completionBlock([authTokens allKeys], false, nil);
            return;
        }];
        return;
    }

    // Validate the tokens we have.
    [self validateTokens:^(BOOL isAccount, NSDictionary *tokensValid, NSError *error) {
        if (error) {
            error = [NSError errorWrapping:error withMessage:@"validateTokens request failed" fromFunction:__FUNCTION__];
            completionBlock(nil, false, error);
            return;
        }

        // If none of the tokens is valid, then the validateTokens won't know if they
        // belong to an account or not. In that case, we only have our previous
        // isAccount value to check.
        isAccount |= self->userID.isAccount;

        NSDictionary* onlyValidTokens = [PsiCash onlyValidTokens:self->userID.authTokens tokensValid:tokensValid];

        [self->userID setAuthTokens:onlyValidTokens isAccount:isAccount];

        // If the tokens are for an account, then there's nothing more to do
        // (unlike for a Tracker, we can't just get new ones).
        if (isAccount) {
            completionBlock([onlyValidTokens allKeys], true, nil);
            return;
        }

        // If the tokens are for a Tracker, then if they're all expired we should
        // get new ones. (They should all expire at the same time.)
        if ([onlyValidTokens count] == 0) {
            [self newTracker:^(NSDictionary *authTokens, NSError *error) {
                if (error) {
                    error = [NSError errorWrapping:error withMessage:@"newTracker request failed" fromFunction:__FUNCTION__];
                    completionBlock(nil, false, error);
                    return;
                }

                [self->userID setAuthTokens:authTokens isAccount:false];

                completionBlock([authTokens allKeys], false, nil);
                return;
            }];
            return;
        }

        // Otherwise we have valid Tracker tokens.
        completionBlock([onlyValidTokens allKeys], false, nil);
        return;
    }];

    return;
}

#pragma mark - helpers

+ (NSMutableURLRequest*)makeRequestFor:(NSString*)path withMethod:(NSString*)method withAuthTokens:(NSDictionary*)authTokens
{
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    [request setCachePolicy:NSURLRequestUseProtocolCachePolicy];
    [request setTimeoutInterval:TIMEOUT_SECS];

    [request setHTTPMethod:method];

    NSString* urlString = [NSString stringWithFormat:@"http://%@%@", PSICASH_SERVER_HOSTNAME, path];
    [request setURL:[NSURL URLWithString:urlString]];

    if (authTokens != nil)
    {
        [request setValue:[PsiCash authTokensToHeader:authTokens] forHTTPHeaderField:AUTH_HEADER];
    }

    return request;
}

+ (NSDictionary*)onlyValidTokens:(NSDictionary*)authTokens tokensValid:(NSDictionary*)tokensValid
{
    NSMutableDictionary* onlyValidTokens = [[NSMutableDictionary alloc] init];

    for (id key in tokensValid) {
        NSNumber* valid = [tokensValid objectForKey:key];

        if (![valid boolValue]) {
            onlyValidTokens[key] = authTokens[key];
        }
    }

    return onlyValidTokens;
}

+ (id)authTokensToHeader:(NSDictionary*)authTokens
{
    NSMutableString *authTokensString = [NSMutableString string];

    for (id key in authTokens) {
        id token = [authTokens objectForKey:key];

        if ([authTokensString length] > 0) {
            [authTokensString appendString:@","];
        }

        [authTokensString appendString:(NSString*)token];
    }

    return authTokensString;
}

@end

/*
 If we decide to add proxy support -- for using this in Psiphon Browser, say -- it
 can be done with this code (adapted from TunneledWebRequest):

 NSURLSessionConfiguration* config = NSURLSessionConfiguration.ephemeralSessionConfiguration.copy;
 config.requestCachePolicy = NSURLRequestReloadIgnoringCacheData;

 NSMutableDictionary* connectionProxyDictionary = [[NSMutableDictionary alloc] init];
 connectionProxyDictionary[(NSString*)kCFStreamPropertySOCKSProxy] = [NSNumber numberWithInt:1];
 connectionProxyDictionary[(NSString*)kCFStreamPropertySOCKSProxyHost] = @"127.0.0.1";
 connectionProxyDictionary[(NSString*)kCFStreamPropertySOCKSProxyPort] = [NSNumber numberWithInt:1234]; // SOCKS port
 connectionProxyDictionary[(NSString*)kCFNetworkProxiesHTTPEnable] = [NSNumber numberWithInt:1];
 connectionProxyDictionary[(NSString*)kCFNetworkProxiesHTTPProxy] = @"127.0.0.1";
 connectionProxyDictionary[(NSString*)kCFNetworkProxiesHTTPPort] = [NSNumber numberWithInt:1234]; // HTTP port
 connectionProxyDictionary[(NSString*)kCFStreamPropertyHTTPSProxyHost] = @"127.0.0.1";
 connectionProxyDictionary[(NSString*)kCFStreamPropertyHTTPSProxyPort] = [NSNumber numberWithInt:1234]; // HTTP port
 config.connectionProxyDictionary = connectionProxyDictionary;

 NSURLSession *session = [NSURLSession sessionWithConfiguration:config];
 */
