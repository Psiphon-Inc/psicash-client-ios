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
//  PsiCash.m
//  PsiCashLib
//

#import "PsiCash.h"
#import "NSError+NSErrorExt.h"
#import "UserInfo.h"
#import "HTTPStatusCodes.h"
#import "PurchasePrice.h"

/* TODO
 - Consider using NSUbiquitousKeyValueStore instead of NSUserDefaults for
 cross-device synchronized storage. (Not using it for now because it introduces
 complexity.)
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

NSString * const PSICASH_SERVER_SCHEME = @"https";
NSString * const PSICASH_SERVER_HOSTNAME = @"api.psi.cash";
int const PSICASH_SERVER_PORT = 443;
/* Local testing values
NSString * const PSICASH_SERVER_SCHEME = @"http"; // @"https";
NSString * const PSICASH_SERVER_HOSTNAME = @"127.0.0.1";
int const PSICASH_SERVER_PORT = 51337;
*/

NSString * const PSICASH_API_VERSION_PATH = @"/v1";
NSTimeInterval const TIMEOUT_SECS = 10.0;
NSString * const AUTH_HEADER = @"X-PsiCash-Auth";
NSString * const PSICASH_USER_AGENT = @"Psiphon-PsiCash-iOS";
NSUInteger const REQUEST_RETRY_LIMIT = 2;
NSString * const LANDING_PAGE_TOKEN_KEY = @"psicash";
NSString * const EARNER_TOKEN_TYPE = @"earner";

@implementation PsiCash {
    NSString *serverScheme;
    NSString *serverHostname;
    NSNumber *serverPort;
    UserInfo *userInfo;
    dispatch_queue_t completionQueue;
}

# pragma mark - Init

- (id)init
{
    self->completionQueue = dispatch_queue_create("com.psiphon3.PsiCashLib.CompletionQueue", DISPATCH_QUEUE_SERIAL);

    self->serverScheme = PSICASH_SERVER_SCHEME;
    self->serverHostname = PSICASH_SERVER_HOSTNAME;
    self->serverPort = [[NSNumber alloc] initWithInt:PSICASH_SERVER_PORT];

    // authTokens may still be nil if the value has never been stored.
    self->userInfo = [[UserInfo alloc] init];

    return self;
}

# pragma mark - Stored info accessors

- (NSArray<NSString*>*_Nullable)validTokenTypes
{
    return [self->userInfo.authTokens allKeys];
}

- (BOOL)isAccount
{
    return self->userInfo.isAccount;
}

- (NSNumber*_Nullable)balance
{
    return self->userInfo.balance;
}

- (NSArray<PsiCashPurchasePrice*>*_Nullable)purchasePrices
{
    return self->userInfo.purchasePrices;
}

- (NSArray<PsiCashPurchase*>*_Nullable)purchases
{
    return self->userInfo.purchases;
}

- (NSDate*_Nonnull)adjustForServerTimeDiff:(NSDate*_Nonnull)date
{
    // Use the negative of serverTimeDiff because if the server time is ahead
    // of the local time, we need to shift our perceived expiry time back.
    return [NSDate dateWithTimeInterval:-self->userInfo.serverTimeDiff
                              sinceDate:date];
}

- (BOOL)nextExpiringPurchase:(PsiCashPurchase*_Nonnull*_Nullable)purchase
                      expiry:(NSDate*_Nonnull*_Nullable)expiry
{
    *purchase = nil;
    *expiry = nil;

    PsiCashPurchase *next;
    for (PsiCashPurchase *purchase in self->userInfo.purchases) {
        if (purchase.expiry == nil) {
            continue;
        }

        if (next == nil) {
            next = purchase;
            continue;
        }

        if ([purchase.expiry compare:next.expiry] == NSOrderedAscending) {
            next = purchase;
        }
    }

    if (next == nil) {
        return NO;
    }

    NSDate *nextExpiry = [self adjustForServerTimeDiff:next.expiry];

    *purchase = next;
    *expiry = nextExpiry;

    return YES;
}

- (NSArray<PsiCashPurchase*>*_Nullable)expirePurchases
{
    NSArray<PsiCashPurchase*> *purchases = self->userInfo.purchases;

    if (!purchases) {
        return nil;
    }

    NSMutableArray<PsiCashPurchase*> *expiredPurchases = [[NSMutableArray alloc] init];
    NSDate *now = [NSDate date];

    for (PsiCashPurchase *purchase in purchases) {
        if ([purchase.expiry compare:now] == NSOrderedAscending) {
            [expiredPurchases addObject:purchase];
        }
    }

    if (expiredPurchases.count == 0) {
        return nil;
    }

    [self->userInfo removePurchases:expiredPurchases];

    return expiredPurchases;
}

- (void)removePurchases:(NSArray<NSString*>*_Nonnull)ids
{
    if ([ids count] == 0) {
        return;
    }

    NSArray<PsiCashPurchase*> *purchases = self->userInfo.purchases;

    if ([purchases count] == 0) {
        return;
    }

    NSMutableArray *purchasesToRemove = [[NSMutableArray alloc] init];

    for (PsiCashPurchase *purchase in purchases) {
        if ([ids containsObject:purchase.ID]) {
            [purchasesToRemove addObject:purchase];
        }
    }

    [self->userInfo removePurchases:purchasesToRemove];
}

- (NSError*_Nullable)modifyLandingPage:(NSString*_Nonnull)url
                           modifiedURL:(NSString*_Nullable*_Nonnull)modifiedURL
{
    *modifiedURL = nil;

    NSURLComponents *urlComponents = [NSURLComponents componentsWithString:url];
    if (!urlComponents) {
        // Decomposing the URL failed. We can't possibly modify it.
        return [NSError errorWithMessage:@"NSURLComponents::componentsWithString failed to decompose URL"
                            fromFunction:__FUNCTION__];
    }

    // Get the earner token. If we don't have one, we can't modify the URL.
    if (!self->userInfo.authTokens ||
        ![self->userInfo.authTokens[EARNER_TOKEN_TYPE] isKindOfClass:[NSString class]]) {
        return [NSError errorWithMessage:@"no valid earner token"
                            fromFunction:__FUNCTION__];
    }

    NSString *earnerToken = self->userInfo.authTokens[EARNER_TOKEN_TYPE];

    // Our preference is to put the token into the URL's fragment/hash/anchor,
    // because we'd prefer the token not to be sent to the server.
    // But if there already is a value there we'll put it into the query parameters.
    // (Because altering the fragment is more likely to have negative consequences
    // for the page than adding a query parameter that will be ignored.)

    if (!urlComponents.fragment) {
        urlComponents.fragment = [NSString stringWithFormat:@"%@=%@",
                                  LANDING_PAGE_TOKEN_KEY,
                                  earnerToken];
    }
    else {
        NSMutableArray<NSURLQueryItem*> *queryItems = [NSMutableArray arrayWithArray:urlComponents.queryItems];
        [queryItems addObject:[NSURLQueryItem queryItemWithName:LANDING_PAGE_TOKEN_KEY
                                                          value:earnerToken]];
        urlComponents.queryItems = queryItems;
    }

    *modifiedURL = [NSString stringWithString:urlComponents.string];

    return nil;
}

#pragma mark - NewTracker

- (void)newTracker:(void (^_Nonnull)(PsiCashStatus status,
                             NSDictionary<NSString*, NSString*>*_Nullable authTokens,
                             NSError*_Nullable error))completionHandler
{
    NSMutableURLRequest *request = [self createRequestFor:@"/tracker"
                                               withMethod:@"POST"
                                           withQueryItems:nil
                                        includeAuthTokens:NO];

    [self doRequestWithRetry:request
                    useCache:NO
           completionHandler:^(NSData *data, NSHTTPURLResponse *response, NSError *error)
     {
         if (error) {
             error = [NSError errorWrapping:error withMessage:@"request error" fromFunction:__FUNCTION__];
             dispatch_async(self->completionQueue, ^{ completionHandler(PsiCashStatus_Invalid,
                                                                        nil,
                                                                        error); });
             return;
         }

         if (response.statusCode == kHTTPStatusOK) {
             if (!data || data.length == 0) {
                 error = [NSError errorWithMessage:@"request returned no data" fromFunction:__FUNCTION__];
                 dispatch_async(self->completionQueue, ^{ completionHandler(PsiCashStatus_Invalid,
                                                                            nil,
                                                                            error); });
                 return;
             }

             NSDictionary<NSString*, NSString*>* authTokens;
             [PsiCash parseNewTrackerResponse:data authTokens:&authTokens withError:&error];
             if (error != nil) {
                 error = [NSError errorWrapping:error withMessage:@"" fromFunction:__FUNCTION__];
                 dispatch_async(self->completionQueue, ^{ completionHandler(PsiCashStatus_Invalid,
                                                                            nil,
                                                                            error); });
                 return;
             }

             [self->userInfo setAuthTokens:authTokens isAccount:NO];
             self->userInfo.balance = @0;

             dispatch_async(self->completionQueue, ^{ completionHandler(PsiCashStatus_Success,
                                                                        authTokens,
                                                                        nil); });
             return;
         }
         else if (response.statusCode == kHTTPStatusInternalServerError) {
             dispatch_async(self->completionQueue, ^{ completionHandler(PsiCashStatus_ServerError,
                                                                        nil,
                                                                        nil); });
             return;
         }
         else {
             error = [NSError errorWithMessage:[NSString stringWithFormat:@"request failure: %ld", response.statusCode]
                                  fromFunction:__FUNCTION__];
             dispatch_async(self->completionQueue, ^{ completionHandler(PsiCashStatus_Invalid,
                                                                        nil,
                                                                        error); });
             return;
         }
     }];
}

+ (void)parseNewTrackerResponse:(NSData*)jsonData authTokens:(NSDictionary<NSString*, NSString*>**)authTokens withError:(NSError**)error
{
    *error = nil;
    *authTokens = nil;

    id object = [NSJSONSerialization
                 JSONObjectWithData:jsonData
                 options:0
                 error:error];

    if (*error) {
        *error = [NSError errorWrapping:*error withMessage:@"NSJSONSerialization error" fromFunction:__FUNCTION__];
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

        if (![value isKindOfClass:NSString.class]) {
            // Note: isKindOfClass is false if the value is nil
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


#pragma mark - RefreshState

- (void)refreshState:(NSArray<NSString*>*_Nonnull)purchaseClasses
      withCompletion:(void (^_Nonnull)(PsiCashStatus status,
                                       NSArray<NSString*>*_Nullable validTokenTypes,
                                       BOOL isAccount,
                                       NSNumber*_Nullable balance,
                                       NSArray<PsiCashPurchasePrice*>*_Nullable purchasePrices,
                                       NSError*_Nullable error))completionHandler
{
    // Call the helper, indicating that it can do one level of recursion.
    [self refreshStateHelper:purchaseClasses
              allowRecursion:YES
              withCompletion:completionHandler];
}

// allowRecursion must be set to YES when called by refreshState and when this
// this method is entered with tokens in hand. This prevents infinite recursion.
- (void)refreshStateHelper:(NSArray<NSString*>*_Nonnull)purchaseClasses
            allowRecursion:(BOOL)allowRecursion
            withCompletion:(void (^_Nonnull)(PsiCashStatus status,
                                             NSArray<NSString*>*_Nullable validTokenTypes,
                                             BOOL isAccount,
                                             NSNumber*_Nullable balance,
                                             NSArray<PsiCashPurchasePrice*>*_Nullable purchasePrices,
                                             NSError*_Nullable error))completionHandler
{
    /*
     Logic flow overview:

     1. If there are no tokens:
     a. If isAccount then return. The user needs to log in immediately.
     b. If !isAccount then call NewTracker to get new tracker tokens.
     2. Make the RefreshClientState request.
     3. If isAccount then return. (Even if there are no valid tokens.)
     4. If there are valid (tracker) tokens then return.
     5. If there are no valid tokens call NewTracker. Call RefreshClientState again.
     6. If there are still no valid tokens, then things are horribly wrong. Return error.
     */

    NSDictionary<NSString*, NSString*> *authTokens = self->userInfo.authTokens;
    if (!authTokens || [authTokens count] == 0) {
        // No tokens.

        if (self->userInfo.isAccount) {
            // This is/was a logged-in account. We can't just get a new tracker.
            // The app will have to force a login for the user to do anything.
            dispatch_async(self->completionQueue, ^{ completionHandler(PsiCashStatus_Success, @[], YES, nil, nil, nil); });
            return;
        }

        if (!allowRecursion) {
            // We have already recursed and can't do it again. This is an error condition.
            NSError *error = [NSError errorWithMessage:@"failed to obtain valid tracker tokens (a)" fromFunction:__FUNCTION__];
            dispatch_async(self->completionQueue, ^{ completionHandler(PsiCashStatus_Invalid, nil, NO, nil, nil, error); });
            return;
        }

        // Get new tracker tokens. (Which is effectively getting a new identity.)
        [self newTracker:^(PsiCashStatus status,
                           NSDictionary<NSString*, NSString*> *authTokens,
                           NSError *error)
         {
             if (error) {
                 error = [NSError errorWrapping:error withMessage:@"newTracker request error" fromFunction:__FUNCTION__];
                 dispatch_async(self->completionQueue, ^{ completionHandler(PsiCashStatus_Invalid, nil, NO, nil, nil, error); });
                 return;
             }

             if (status != PsiCashStatus_Success) {
                 dispatch_async(self->completionQueue, ^{ completionHandler(status, nil, NO, nil, nil, error); });
                 return;
             }

             // newTracker calls [self->userInfo setAuthTokens]

             // Recursive refreshState call now that we have tokens.
             [self refreshStateHelper:purchaseClasses
                       allowRecursion:NO
                       withCompletion:completionHandler];
             return;
         }];

        return;
    }

    // We have tokens. Make the RefreshClientState request.

    NSMutableArray *queryItems = [[NSMutableArray alloc] init];
    for (NSString *val in purchaseClasses) {
        NSURLQueryItem *qi = [NSURLQueryItem queryItemWithName:@"class" value:val];
        [queryItems addObject:qi];
    }

    NSMutableURLRequest *request = [self createRequestFor:@"/refresh-state"
                                               withMethod:@"GET"
                                           withQueryItems:queryItems
                                        includeAuthTokens:YES];

    [self doRequestWithRetry:request
                    useCache:NO
           completionHandler:^(NSData *data, NSHTTPURLResponse *response, NSError *error)
     {
         if (error) {
             error = [NSError errorWrapping:error withMessage:@"request error" fromFunction:__FUNCTION__];
             dispatch_async(self->completionQueue, ^{ completionHandler(PsiCashStatus_Invalid, nil, NO, nil, nil, error); });
             return;
         }

         if (response.statusCode == kHTTPStatusOK) {
             if (!data || data.length == 0) {
                 error = [NSError errorWithMessage:@"request returned no data" fromFunction:__FUNCTION__];
                 dispatch_async(self->completionQueue, ^{ completionHandler(PsiCashStatus_Invalid, nil, NO, nil, nil, error); });
                 return;
             }

             NSNumber *balance;
             BOOL isAccount;
             NSDictionary<NSString*, NSNumber*> *tokensValid;
             NSArray<PsiCashPurchasePrice*> *purchasePrices;
             [PsiCash parseRefreshStateResponse:data
                                    tokensValid:&tokensValid
                                      isAccount:&isAccount
                                        balance:&balance
                                 purchasePrices:&purchasePrices
                                      withError:&error];
             if (error != nil) {
                 error = [NSError errorWrapping:error withMessage:@"" fromFunction:__FUNCTION__];
                 dispatch_async(self->completionQueue, ^{ completionHandler(PsiCashStatus_Invalid, nil, NO, nil, nil, error); });
                 return;
             }

             if (balance) {
                 self->userInfo.balance = balance;
             }
             if (purchasePrices) {
                 self->userInfo.purchasePrices = purchasePrices;
             }

             // NOTE: Even though there's no error, there could still be no valid tokens,
             // no balance or is-account, and no purchase prices.

             NSDictionary<NSString*, NSString*>* onlyValidTokens =
                [PsiCash onlyValidTokens:self->userInfo.authTokens
                             tokensValid:tokensValid];

             // If any of our tokens were valid, then the isAccount value from the
             // server is authoritative. Otherwise we'll respect our existing value.
             if (onlyValidTokens.count == 0) {
                 isAccount = self->userInfo.isAccount;
             }

             // If we have moved from being an account to not being an account,
             // something is very wrong.
             if (self->userInfo.isAccount && !isAccount) {
                 error = [NSError errorWithMessage:@"invalid is-account state" fromFunction:__FUNCTION__];
                 dispatch_async(self->completionQueue, ^{ completionHandler(PsiCashStatus_Invalid, nil, NO, nil, nil, error); });
                 return;
             }

             [self->userInfo setAuthTokens:onlyValidTokens isAccount:isAccount];

             if (self->userInfo.isAccount) {
                 // For accounts there's nothing else we can do, regardless of the state of token validity.
                 dispatch_async(self->completionQueue, ^{ completionHandler(PsiCashStatus_Success,
                                                                            [onlyValidTokens allKeys],
                                                                            self->userInfo.isAccount,
                                                                            balance,
                                                                            purchasePrices,
                                                                            nil); });
                 return;
             }

             if (onlyValidTokens.count > 0) {
                 // We have a good tracker state.
                 dispatch_async(self->completionQueue, ^{ completionHandler(PsiCashStatus_Success,
                                                                            [onlyValidTokens allKeys],
                                                                            self->userInfo.isAccount,
                                                                            balance,
                                                                            purchasePrices,
                                                                            nil); });
                 return;
             }

             // We started out with tracker tokens, but they're all invalid.

             if (!allowRecursion) {
                 // No further recursion is allowed, so there's nothing more we can do.
                 NSError *error = [NSError errorWithMessage:@"failed to obtain valid tracker tokens (b)" fromFunction:__FUNCTION__];
                 dispatch_async(self->completionQueue, ^{ completionHandler(PsiCashStatus_Invalid, nil, NO, nil, nil, error); });
                 return;
             }

             // Start the call all over, which will begin with NewTracker.

             // We have no tokens, so allow recusion in order for the
             // NewTracker+RefreshClientState to occur.
             [self refreshStateHelper:purchaseClasses
                       allowRecursion:YES
                       withCompletion:completionHandler];
             return;
         }
         else if (response.statusCode == kHTTPStatusUnauthorized) {
             // This can only happen if the tokens we sent didn't all belong to
             // same user. This really should never happen.
             [self->userInfo clear];
             dispatch_async(self->completionQueue, ^{ completionHandler(PsiCashStatus_InvalidTokens, nil, NO, nil, nil, nil); });
             return;
         }
         else if (response.statusCode == kHTTPStatusInternalServerError) {
             dispatch_async(self->completionQueue, ^{ completionHandler(PsiCashStatus_ServerError, nil, NO, nil, nil, nil); });
             return;
         }
         else {
             // This could happen on a kHTTPStatusBadRequest, which means we sent bad data.
             // Shouldn't happen.
             error = [NSError errorWithMessage:[NSString stringWithFormat:@"request failure: %ld", response.statusCode]
                                  fromFunction:__FUNCTION__];
             dispatch_async(self->completionQueue, ^{ completionHandler(PsiCashStatus_Invalid, nil, NO, nil, nil, error); });
             return;
         }
     }];
}

+ (void)parseRefreshStateResponse:(NSData*_Nonnull)jsonData
                      tokensValid:(NSDictionary<NSString*, NSNumber*>**_Nonnull)tokensValid
                        isAccount:(BOOL*_Nonnull)isAccount
                          balance:(NSNumber**_Nonnull)balance
                   purchasePrices:(NSArray<PsiCashPurchasePrice*>**_Nonnull)purchasePrices
                        withError:(NSError**_Nonnull)error
{
    *error = nil;
    *tokensValid = nil;
    *isAccount = NO;
    *balance = nil;
    *purchasePrices = nil;

    id object = [NSJSONSerialization
                 JSONObjectWithData:jsonData
                 options:0
                 error:error];

    if (*error) {
        *error = [NSError errorWrapping:*error withMessage:@"NSJSONSerialization error" fromFunction:__FUNCTION__];
        return;
    }

    if (![object isKindOfClass:[NSDictionary class]]) {
        // Note: isKindOfClass is false if the value is nil
        *error = [NSError errorWithMessage:@"Invalid JSON structure" fromFunction:__FUNCTION__];
        return;
    }

    NSDictionary* data = object;

    // Note: isKindOfClass is false if the key isn't found

    if (data[@"Balance"] != [NSNull null]) {
        if (![data[@"Balance"] isKindOfClass:NSNumber.class]) {
            *error = [NSError errorWithMessage:@"Balance is not a number" fromFunction:__FUNCTION__];
            return;
        }
        *balance = data[@"Balance"];
    }

    if (data[@"IsAccount"] != [NSNull null]) {
        if (![data[@"IsAccount"] isKindOfClass:NSNumber.class]) {
            *error = [NSError errorWithMessage:@"IsAccount is not a number" fromFunction:__FUNCTION__];
            return;
        }
        *isAccount = [(NSNumber*)data[@"IsAccount"] boolValue];
    }

    // TokensValid is never null on success.
    if (![data[@"TokensValid"] isKindOfClass:NSDictionary.class]) {
        // Note: isKindOfClass is false if the value is nil
        *error = [NSError errorWithMessage:@"TokensValid is not a dictionary" fromFunction:__FUNCTION__];
        return;
    }
    *tokensValid = data[@"TokensValid"];

    if (data[@"PurchasePrices"] != [NSNull null]) {
        if (![data[@"PurchasePrices"] isKindOfClass:NSArray.class]) {
            *error = [NSError errorWithMessage:@"PurchasePrices is not an array" fromFunction:__FUNCTION__];
            return;
        }

        NSArray *jsonPPs = data[@"PurchasePrices"];
        NSMutableArray *pps = [NSMutableArray arrayWithCapacity:jsonPPs.count];
        for (id jpp in jsonPPs) {
            if (![jpp isKindOfClass:NSDictionary.class]) {
                *error = [NSError errorWithMessage:@"PurchasePrices item is not a dictionary" fromFunction:__FUNCTION__];
                return;
            }

            PsiCashPurchasePrice *pp = [[PsiCashPurchasePrice alloc] init];

            if (![jpp[@"Class"] isKindOfClass:NSString.class]) {
                *error = [NSError errorWithMessage:@"Class is not a string" fromFunction:__FUNCTION__];
                return;
            }
            pp.transactionClass = jpp[@"Class"];

            if (![jpp[@"Distinguisher"] isKindOfClass:NSString.class]) {
                *error = [NSError errorWithMessage:@"Distinguisher is not a string" fromFunction:__FUNCTION__];
                return;
            }
            pp.distinguisher = jpp[@"Distinguisher"];

            if (![jpp[@"Price"] isKindOfClass:NSNumber.class]) {
                *error = [NSError errorWithMessage:@"Price is not a number" fromFunction:__FUNCTION__];
                return;
            }
            pp.price = jpp[@"Price"];

            [pps addObject:pp];
        }

        *purchasePrices = pps;
    }
}


#pragma mark - NewTransaction

- (void)newExpiringPurchaseTransactionForClass:(NSString*_Nonnull)transactionClass
                             withDistinguisher:(NSString*_Nonnull)transactionDistinguisher
                             withExpectedPrice:(NSNumber*_Nonnull)expectedPrice
                                withCompletion:(void (^_Nonnull)(PsiCashStatus status,
                                                                 NSNumber*_Nullable price,
                                                                 NSNumber*_Nullable balance,
                                                                 NSDate*_Nullable expiry,
                                                                 NSString*_Nullable transactionID,
                                                                 NSString*_Nullable authorization,
                                                                 NSError*_Nullable error))completionHandler
{
    NSMutableArray *queryItems = [[NSMutableArray alloc] init];
    [queryItems addObject:[NSURLQueryItem queryItemWithName:@"class"
                                                      value:transactionClass]];
    [queryItems addObject:[NSURLQueryItem queryItemWithName:@"distinguisher"
                                                      value:transactionDistinguisher]];

    // Note the conversion from positive to negative: price to amount.
    [queryItems addObject:[NSURLQueryItem queryItemWithName:@"expectedAmount"
                                                      value:[NSString stringWithFormat:@"-%lld", expectedPrice.longLongValue]]];

    NSMutableURLRequest *request = [self createRequestFor:@"/transaction"
                                               withMethod:@"POST"
                                           withQueryItems:queryItems
                                        includeAuthTokens:YES];

    [self doRequestWithRetry:request
                    useCache:NO
           completionHandler:^(NSData *data, NSHTTPURLResponse *response, NSError *error)
     {
         if (error) {
             error = [NSError errorWrapping:error withMessage:@"request error" fromFunction:__FUNCTION__];
             dispatch_async(self->completionQueue, ^{
                 completionHandler(PsiCashStatus_Invalid, nil, nil, nil, nil, nil, error);
             });
             return;
         }

         NSNumber *price, *balance;
         NSDate *expiry, *adjustedExpiry;
         NSString *transactionID, *authorization;

         if (response.statusCode == kHTTPStatusOK ||
             response.statusCode == kHTTPStatusTooManyRequests ||
             response.statusCode == kHTTPStatusPaymentRequired ||
             response.statusCode == kHTTPStatusConflict) {
             if (!data || data.length == 0) {
                 error = [NSError errorWithMessage:@"request returned no data" fromFunction:__FUNCTION__];
                 dispatch_async(self->completionQueue, ^{
                     completionHandler(PsiCashStatus_Invalid, nil, nil, nil, nil, nil, error);
                 });
                 return;
             }

             NSNumber *transactionAmount;

             [PsiCash parseNewTransactionResponse:data
                                transactionAmount:&transactionAmount
                                          balance:&balance
                                           expiry:&expiry
                                    transactionID:&transactionID
                                    authorization:&authorization
                                        withError:&error];
             if (error != nil) {
                 error = [NSError errorWrapping:error withMessage:@"" fromFunction:__FUNCTION__];
                 dispatch_async(self->completionQueue, ^{
                     completionHandler(PsiCashStatus_Invalid, nil, nil, nil, nil, nil, error);
                 });
                 return;
             }

             if (expiry) {
                 adjustedExpiry = [self adjustForServerTimeDiff:expiry];
             }

             self->userInfo.balance = balance;

             // Price is positive, transaction amount is negative.
             price = [NSNumber numberWithLongLong:-transactionAmount.longLongValue];
         }

         if (response.statusCode == kHTTPStatusOK) {
             [self->userInfo addPurchase:[[PsiCashPurchase alloc] initWithID:transactionID
                                                            transactionClass:transactionClass
                                                               distinguisher:transactionDistinguisher
                                                                      expiry:expiry
                                                               authorization:authorization]];

             dispatch_async(self->completionQueue, ^{
                 completionHandler(PsiCashStatus_Success, price, balance, adjustedExpiry, transactionID, authorization, nil);
             });
             return;
         }
         else if (response.statusCode == kHTTPStatusTooManyRequests) {
             dispatch_async(self->completionQueue, ^{
                 completionHandler(PsiCashStatus_ExistingTransaction, price, balance, adjustedExpiry, nil, nil, nil);
             });
             return;
         }
         else if (response.statusCode == kHTTPStatusPaymentRequired) {
             dispatch_async(self->completionQueue, ^{
                 completionHandler(PsiCashStatus_InsufficientBalance, price, balance, nil, nil, nil, nil);
             });
             return;
         }
         else if (response.statusCode == kHTTPStatusConflict) {
             dispatch_async(self->completionQueue, ^{
                 completionHandler(PsiCashStatus_TransactionAmountMismatch, price, balance, nil, nil, nil, nil);
             });
             return;
         }
         else if (response.statusCode == kHTTPStatusNotFound) {
             dispatch_async(self->completionQueue, ^{
                 completionHandler(PsiCashStatus_TransactionTypeNotFound, nil, nil, nil, nil, nil, nil);
             });
             return;
         }
         else if (response.statusCode == kHTTPStatusUnauthorized) {
             dispatch_async(self->completionQueue, ^{
                 completionHandler(PsiCashStatus_InvalidTokens, nil, nil, nil, nil, nil, nil);
             });
             return;
         }
         else if (response.statusCode == kHTTPStatusInternalServerError) {
             dispatch_async(self->completionQueue, ^{
                 completionHandler(PsiCashStatus_ServerError, nil, nil, nil, nil, nil, nil);
             });
             return;
         }
         else {
             error = [NSError errorWithMessage:[NSString stringWithFormat:@"request failure: %ld", response.statusCode]
                                  fromFunction:__FUNCTION__];
             dispatch_async(self->completionQueue, ^{
                 completionHandler(PsiCashStatus_Invalid, nil, nil, nil, nil, nil, error);
             });
             return;
         }
     }];
}

+ (void)parseNewTransactionResponse:(NSData*)jsonData
                  transactionAmount:(NSNumber**)transactionAmount
                            balance:(NSNumber**)balance
                             expiry:(NSDate**)expiry
                      transactionID:(NSString**)transactionID
                      authorization:(NSString**)authorization
                          withError:(NSError**)error
{
    *error = nil;
    *balance = nil;
    *transactionAmount = nil;
    *expiry = nil;
    *transactionID = nil;
    *authorization = nil;

    id object = [NSJSONSerialization
                 JSONObjectWithData:jsonData
                 options:0
                 error:error];

    if (*error) {
        *error = [NSError errorWrapping:*error withMessage:@"NSJSONSerialization error" fromFunction:__FUNCTION__];
        return;
    }

    if (![object isKindOfClass:[NSDictionary class]]) {
        *error = [NSError errorWithMessage:@"Invalid JSON structure" fromFunction:__FUNCTION__];
        return;
    }

    NSDictionary* data = object;

    // Note: isKindOfClass is false if the key isn't found

    if (data[@"TransactionAmount"] != [NSNull null]) {
        if (![data[@"TransactionAmount"] isKindOfClass:NSNumber.class]) {
            *error = [NSError errorWithMessage:@"TransactionAmount is not a number" fromFunction:__FUNCTION__];
            return;
        }
        *transactionAmount = data[@"TransactionAmount"];
    }

    if (data[@"Balance"] != [NSNull null]) {
        if (![data[@"Balance"] isKindOfClass:NSNumber.class]) {
            *error = [NSError errorWithMessage:@"Balance is not a number" fromFunction:__FUNCTION__];
            return;
        }
        *balance = data[@"Balance"];
    }

    if (data[@"TransactionID"] != nil && data[@"TransactionID"] != [NSNull null]) {
        if (![data[@"TransactionID"] isKindOfClass:NSString.class]) {
            *error = [NSError errorWithMessage:@"TransactionID is not a string" fromFunction:__FUNCTION__];
            return;
        }
        *transactionID = data[@"TransactionID"];
    }

    if (data[@"Authorization"] != nil && data[@"Authorization"] != [NSNull null]) {
        if (![data[@"Authorization"] isKindOfClass:NSString.class]) {
            *error = [NSError errorWithMessage:@"Authorization is not a string" fromFunction:__FUNCTION__];
            return;
        }
        *authorization = data[@"Authorization"];
    }

    if (data[@"TransactionResponse"] != nil) {
        if (![data[@"TransactionResponse"] isKindOfClass:NSDictionary.class]) {
            *error = [NSError errorWithMessage:@"TransactionResponse is not a dictionary" fromFunction:__FUNCTION__];
            return;
        }

        NSDictionary *transactionResponse = data[@"TransactionResponse"];

        if (![transactionResponse[@"Type"] isKindOfClass:NSString.class]) {
            *error = [NSError errorWithMessage:@"Type is not a number" fromFunction:__FUNCTION__];
            return;
        }

        NSString *type = transactionResponse[@"Type"];
        if (![type isEqualToString:@"expiring-purchase"]) {
            *error = [NSError errorWithMessage:@"Type is not 'expiring-purchase'" fromFunction:__FUNCTION__];
            return;
        }

        if (![transactionResponse[@"Values"] isKindOfClass:NSDictionary.class]) {
            *error = [NSError errorWithMessage:@"TransactionResponse.Values is not a dictionary" fromFunction:__FUNCTION__];
            return;
        }

        NSDictionary *transactionResponseValues = transactionResponse[@"Values"];

        if (![transactionResponseValues[@"Expires"] isKindOfClass:NSString.class]) {
            *error = [NSError errorWithMessage:@"TransactionResponse.Values.Expires is not a string" fromFunction:__FUNCTION__];
            return;
        }

        *expiry = [PsiCash dateFromISO8601String:transactionResponseValues[@"Expires"]];
        if (!*expiry) {
            *error = [NSError errorWithMessage:@"TransactionResponse.Values.Expires failed to parse" fromFunction:__FUNCTION__];
            return;
        }
    }
}


#pragma mark - helpers

- (NSMutableURLRequest*_Nonnull)createRequestFor:(NSString*_Nonnull)path
                                      withMethod:(NSString*_Nonnull)method
                                  withQueryItems:(NSArray<NSURLQueryItem*>*_Nullable)queryItems
                               includeAuthTokens:(BOOL)includeAuthTokens
{
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    [request setCachePolicy:NSURLRequestUseProtocolCachePolicy];
    [request setTimeoutInterval:TIMEOUT_SECS];

    [request setHTTPMethod:method];

    NSURLComponents *urlComponents = [[NSURLComponents alloc] init];
    urlComponents.scheme = self->serverScheme;
    urlComponents.host = self->serverHostname;
    urlComponents.port = self->serverPort;
    urlComponents.path = [PSICASH_API_VERSION_PATH stringByAppendingString:path];
    urlComponents.queryItems = queryItems;

    [request setURL:urlComponents.URL];

    [request setValue:PSICASH_USER_AGENT forHTTPHeaderField:@"User-Agent"];

    if (includeAuthTokens)
    {
        [request setValue:[PsiCash authTokensToHeader:self->userInfo.authTokens]
       forHTTPHeaderField:AUTH_HEADER];
    }

    [PsiCash requestMutator:request];

    return request;
}

+ (void)requestMutator:(NSMutableURLRequest*)request
{
    // Only does something when replaced by testing code.
}

// If error is non-nil, data and response will be nil.
- (void)doRequestWithRetry:(NSURLRequest*_Nonnull)request
                  useCache:(BOOL)useCache
         completionHandler:(void (^_Nonnull)(NSData*_Nullable data,
                                             NSHTTPURLResponse*_Nullable response,
                                             NSError*_Nullable error))completionHandler
{
    [self doRequestWithRetryHelper:request
                          useCache:useCache
                   numberOfRetries:REQUEST_RETRY_LIMIT
                 completionHandler:completionHandler];
}

- (void)doRequestWithRetryHelper:(NSURLRequest*_Nonnull)request
                        useCache:(BOOL)useCache
                 numberOfRetries:(NSUInteger)numRetries // Set to REQUEST_RETRY_LIMIT on first call
               completionHandler:(void (^_Nonnull)(NSData*_Nullable data,
                                                   NSHTTPURLResponse*_Nullable response,
                                                   NSError*_Nullable error))completionHandler
{
    __weak typeof (self) weakSelf = self;

    __block NSInteger remainingRetries = numRetries;

    NSURLSessionConfiguration* config = NSURLSessionConfiguration.defaultSessionConfiguration.copy;
    config.timeoutIntervalForRequest = TIMEOUT_SECS;

    if (!useCache) {
        config.requestCachePolicy = NSURLRequestReloadIgnoringCacheData;
    }

    NSURLSession *session = [NSURLSession sessionWithConfiguration:config];

    NSURLSessionDataTask *dataTask =
        [session dataTaskWithRequest:request
                   completionHandler:^(NSData *data, NSURLResponse *response, NSError *error)
         {
             if (error) {
                 // Don't retry in the case of an actual error.
                 dispatch_async(self->completionQueue, ^{
                     completionHandler(nil, nil, error);
                 });
                 return;
             }

             NSHTTPURLResponse* httpResponse = (NSHTTPURLResponse*)response;
             NSUInteger responseStatusCode = [httpResponse statusCode];

             if (responseStatusCode >= 500 && remainingRetries > 0) {
                 // Server is having trouble. Retry.

                 remainingRetries -= 1;

                 // Back off per attempt.
                 dispatch_time_t retryTime = dispatch_time(DISPATCH_TIME_NOW, (REQUEST_RETRY_LIMIT-remainingRetries) * NSEC_PER_SEC);

                 dispatch_after(retryTime, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0ul), ^{
                     // Recursive retry.
                     [weakSelf doRequestWithRetryHelper:request
                                               useCache:useCache
                                        numberOfRetries:remainingRetries
                                      completionHandler:completionHandler];
                 });
                 return;
             }
             else {
                 self->userInfo.serverTimeDiff = [PsiCash serverTimeDiff:httpResponse];

                 // Success or no more retries available.
                 dispatch_async(self->completionQueue, ^{
                     completionHandler(data, httpResponse, nil);
                 });
                 return;
             }
         }];

    [dataTask resume];
}

+ (NSDictionary<NSString*, NSString*>*_Nonnull)onlyValidTokens:(NSDictionary*)authTokens
                                                   tokensValid:(NSDictionary<NSString*, NSNumber*>*)tokensValid
{
    NSMutableDictionary* onlyValidTokens = [[NSMutableDictionary alloc] init];

    for (id tokenType in authTokens) {
        NSString *token = [authTokens objectForKey:tokenType];
        NSNumber *valid = [tokensValid objectForKey:token];

        if ([valid boolValue]) {
            onlyValidTokens[tokenType] = token;
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

+ (NSDate*)dateFromISO8601String:(NSString*)dateString
{
    // From https://stackoverflow.com/a/17559601/729729
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss.SSSZ"];
    // Always use this locale when parsing fixed format date strings
    NSLocale *posix = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
    [formatter setLocale:posix];
    NSDate *date = [formatter dateFromString:dateString];

    // NOTE: NSISO8601DateFormatter totally fails when the date has milliseconds. http://www.openradar.me/29609526

    return date;
}

+ (NSTimeInterval)serverTimeDiff:(NSHTTPURLResponse*)response
{
    NSTimeInterval noDiff = 0.0;

    if (!response) {
        return noDiff;
    }

    NSString *serverDateString = response.allHeaderFields[@"Date"];
    if (!serverDateString) {
        NSLog(@"Server date header absent");
        return noDiff;
    }

    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"EEE',' dd' 'MMM' 'yyyy HH':'mm':'ss zzz"];

    NSDate *serverDate = [dateFormatter dateFromString:serverDateString];
    if (!serverDate) {
        NSLog(@"Server date parse fail");
        return noDiff;
    }

    return serverDate.timeIntervalSinceNow;
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
