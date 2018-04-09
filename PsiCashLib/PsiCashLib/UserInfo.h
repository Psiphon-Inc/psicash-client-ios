//
//  UserInfo.h
//  PsiCashLib
//

#ifndef UserInfo_h
#define UserInfo_h

//
// Stores persistent info about the user.
//

@interface UserInfo : NSObject

//! authTokens maps token type to value.
@property (readonly) NSDictionary *authTokens;
@property BOOL isAccount;
@property NSNumber *balance;
@property NSArray *purchasePrices;
@property NSTimeInterval serverTimeDiff;

- (id)init;

//! Clears all user ID state.
- (void)clear;

- (void)setAuthTokens:(NSDictionary *)authTokens
                isAccount:(BOOL)isAccount;

@end

#endif /* UserInfo_h */
