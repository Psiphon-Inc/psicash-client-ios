//
//  AuthTokens.m
//  PsiCashLib
//
//  Created by Adam Pritchard on 2018-03-05.
//  Copyright © 2018 Adam Pritchard. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "UserIdentity.h"


NSString * const TOKENS_DEFAULTS_KEY = @"Psiphon-PsiCash-UserIdentity-Tokens";
NSString * const ISACCOUNT_DEFAULTS_KEY = @"Psiphon-PsiCash-UserIdentity-IsAccount";


@implementation UserIdentity {
    NSInteger _isAccount;
}

@synthesize authTokens = _authTokens;

- (id)init
{
    self->_authTokens = [[NSUserDefaults standardUserDefaults] dictionaryForKey:TOKENS_DEFAULTS_KEY];
    self->_isAccount = [[NSUserDefaults standardUserDefaults] integerForKey:ISACCOUNT_DEFAULTS_KEY];
    return self;
}

- (void)setAuthTokens:(NSDictionary *)authTokens isAccount:(BOOL)isAccount
{
    NSNumber *isAccountNum = [NSNumber numberWithBool:isAccount];
    @synchronized(self)
    {
        [[NSUserDefaults standardUserDefaults] setObject:authTokens forKey:TOKENS_DEFAULTS_KEY];
        [[NSUserDefaults standardUserDefaults] setObject:isAccountNum forKey:ISACCOUNT_DEFAULTS_KEY];
        self->_authTokens = authTokens;
    }
}

- (NSDictionary*)authTokens
{
    NSDictionary *retVal;

    @synchronized(self)
    {
        retVal = _authTokens;
    }

    return retVal;
}

- (void)setIsAccount:(BOOL)isAccount
{
    NSNumber *isAccountNum = [NSNumber numberWithBool:isAccount];
    @synchronized(self)
    {
        [[NSUserDefaults standardUserDefaults] setObject:isAccountNum forKey:ISACCOUNT_DEFAULTS_KEY];
        self->_isAccount = isAccount;
    }
}

- (BOOL)isAccount
{
    NSInteger retVal;

    @synchronized(self)
    {
        retVal = _isAccount;
    }

    return retVal;
}

@end
