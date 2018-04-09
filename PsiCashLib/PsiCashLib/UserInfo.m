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


@implementation UserInfo {
    NSInteger _isAccount;
}

@synthesize authTokens = _authTokens;
@synthesize balance = _balance;
@synthesize purchasePrices = _purchasePrices;
@synthesize serverTimeDiff = _serverTimeDiff;

- (id)init
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

    [self setAuthTokens:[defaults dictionaryForKey:TOKENS_DEFAULTS_KEY]
              isAccount:[defaults integerForKey:ISACCOUNT_DEFAULTS_KEY]];
    self->_balance = [defaults objectForKey:BALANCE_DEFAULTS_KEY];
    self->_purchasePrices = [NSKeyedUnarchiver unarchiveObjectWithData:[defaults objectForKey:PURCHASE_PRICES_DEFAULTS_KEY]];
    self->_serverTimeDiff = [defaults doubleForKey:SERVER_TIME_DIFF_DEFAULTS_KEY];

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
    }
}

- (void)setAuthTokens:(NSDictionary *)authTokens isAccount:(BOOL)isAccount
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

- (NSNumber *)balance
{
    NSNumber *retVal;
    @synchronized(self)
    {
        retVal = [self->_balance copy];
    }
    return retVal;
}

- (void)setPurchasePrices:(NSArray *)purchasePrices
{
    @synchronized(self)
    {
        NSData *data = [NSKeyedArchiver archivedDataWithRootObject:purchasePrices];
        [[NSUserDefaults standardUserDefaults] setObject:data forKey:PURCHASE_PRICES_DEFAULTS_KEY];
        self->_purchasePrices = purchasePrices;
    }
}

- (NSArray *)purchasePrices
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

@end
