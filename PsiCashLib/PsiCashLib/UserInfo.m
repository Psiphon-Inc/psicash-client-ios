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
//  UserInfo.m
//  PsiCashLib
//

#import <Foundation/Foundation.h>
#import "UserInfo.h"


NSString * const TOKENS_DEFAULTS_KEY = @"Psiphon-PsiCash-UserInfo-Tokens";
NSString * const ISACCOUNT_DEFAULTS_KEY = @"Psiphon-PsiCash-UserInfo-IsAccount";
NSString * const BALANCE_DEFAULTS_KEY = @"Psiphon-PsiCash-UserInfo-Balance";
NSString * const PURCHASE_PRICES_DEFAULTS_KEY = @"Psiphon-PsiCash-UserInfo-PurchasePrices";
NSString * const SERVER_TIME_DIFF_DEFAULTS_KEY = @"Psiphon-PsiCash-UserInfo-ServerTimeDiff";
NSString * const LAST_TRANSACTION_ID_DEFAULTS_KEY = @"Psiphon-PsiCash-UserInfo-LastTransactionID";


@implementation UserInfo {
    NSInteger _isAccount;
}

@synthesize authTokens = _authTokens;
@synthesize balance = _balance;
@synthesize purchasePrices = _purchasePrices;
@synthesize serverTimeDiff = _serverTimeDiff;
@synthesize lastTransactionID = _lastTransactionID;

- (id)init
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

    [self setAuthTokens:[defaults dictionaryForKey:TOKENS_DEFAULTS_KEY]
              isAccount:[defaults integerForKey:ISACCOUNT_DEFAULTS_KEY]];
    self->_balance = [defaults objectForKey:BALANCE_DEFAULTS_KEY];
    self->_purchasePrices = [NSKeyedUnarchiver unarchiveObjectWithData:[defaults objectForKey:PURCHASE_PRICES_DEFAULTS_KEY]];
    self->_serverTimeDiff = [defaults doubleForKey:SERVER_TIME_DIFF_DEFAULTS_KEY];
    self->_lastTransactionID = [defaults stringForKey:LAST_TRANSACTION_ID_DEFAULTS_KEY];

    return self;
}

- (void)clear
{
    @synchronized(self)
    {
        NSDictionary *emptyAuthTokens = [[NSDictionary alloc] init];
        [self setAuthTokens:emptyAuthTokens isAccount:NO];
        self.balance = @0;
        self.purchasePrices = @[];
        self.serverTimeDiff = 0.0;
        self.lastTransactionID = nil;
    }
}

- (void)setAuthTokens:(NSDictionary*)authTokens isAccount:(BOOL)isAccount
{
    @synchronized(self)
    {
        // If these don't seem to be saving, remember that killing a debug run
        // may prevent persistence.
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        [defaults setObject:authTokens forKey:TOKENS_DEFAULTS_KEY];
        [defaults setInteger:isAccount forKey:ISACCOUNT_DEFAULTS_KEY];
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
        retVal = [self->_authTokens copy];
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
        retVal = self->_isAccount;
    }

    return retVal;
}

- (void)setBalance:(NSNumber*)balance
{
    @synchronized(self)
    {
        [[NSUserDefaults standardUserDefaults] setValue:balance forKey:BALANCE_DEFAULTS_KEY];
        self->_balance = balance;
    }
}

- (NSNumber*)balance
{
    NSNumber *retVal;
    @synchronized(self)
    {
        retVal = [self->_balance copy];
    }
    return retVal;
}

- (void)setPurchasePrices:(NSArray*)purchasePrices
{
    @synchronized(self)
    {
        NSData *data = [NSKeyedArchiver archivedDataWithRootObject:purchasePrices];
        [[NSUserDefaults standardUserDefaults] setObject:data forKey:PURCHASE_PRICES_DEFAULTS_KEY];
        self->_purchasePrices = purchasePrices;
    }
}

- (NSArray*)purchasePrices
{
    NSArray *retVal;
    @synchronized(self)
    {
        retVal = [self->_purchasePrices copy];
    }
    return retVal;
}

- (void)setServerTimeDiff:(NSTimeInterval)serverTimeDiff
{
    @synchronized(self)
    {
        [[NSUserDefaults standardUserDefaults] setDouble:serverTimeDiff forKey:SERVER_TIME_DIFF_DEFAULTS_KEY];
        self->_serverTimeDiff = serverTimeDiff;
    }
}

- (NSTimeInterval)serverTimeDiff
{
    NSTimeInterval retVal;
    @synchronized(self)
    {
        retVal = self->_serverTimeDiff;
    }
    return retVal;
}

- (void)setLastTransactionID:(NSString*)lastTransactionID
{
    @synchronized(self)
    {
        [[NSUserDefaults standardUserDefaults] setObject:lastTransactionID forKey:LAST_TRANSACTION_ID_DEFAULTS_KEY];
        self->_lastTransactionID = lastTransactionID;
    }
}

- (NSString*)lastTransactionID
{
    NSString *retVal;
    @synchronized(self)
    {
        retVal = [self->_lastTransactionID copy];
    }
    return retVal;
}

@end
