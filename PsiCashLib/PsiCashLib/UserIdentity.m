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
    [self setAuthTokens:[[NSUserDefaults standardUserDefaults] dictionaryForKey:TOKENS_DEFAULTS_KEY]
              isAccount:[[NSUserDefaults standardUserDefaults] integerForKey:ISACCOUNT_DEFAULTS_KEY]];

    return self;
}

- (void)setAuthTokens:(NSDictionary *)authTokens isAccount:(BOOL)isAccount
{
    @synchronized(self)
    {
        // If these don't seem to be saving, remember that killing a debug run
        // may prevent persistence.
        [[NSUserDefaults standardUserDefaults] setObject:authTokens forKey:TOKENS_DEFAULTS_KEY];
        [[NSUserDefaults standardUserDefaults] setInteger:isAccount forKey:ISACCOUNT_DEFAULTS_KEY];
        self->_authTokens = authTokens;
        self->_isAccount = isAccount;

#ifdef DEBUG
        NSLog(@"PsiCashLib::authTokens:%@", self->_authTokens);
#endif
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
    @synchronized(self)
    {
        [[NSUserDefaults standardUserDefaults] setInteger:isAccount forKey:ISACCOUNT_DEFAULTS_KEY];
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
