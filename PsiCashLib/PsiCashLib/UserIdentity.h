//
//  AuthTokens.h
//  PsiCashLib
//
//  Created by Adam Pritchard on 2018-03-05.
//  Copyright © 2018 Adam Pritchard. All rights reserved.
//

#ifndef AuthTokens_h
#define AuthTokens_h

@interface UserIdentity : NSObject

//! authTokens maps token type to value.
@property (readonly) NSDictionary *authTokens;
@property BOOL isAccount;

- (id)init;

//! Clears all user ID state.
- (void)clear;

- (void)setAuthTokens:(NSDictionary *)authTokens
                isAccount:(BOOL)isAccount;

@end

#endif /* AuthTokens_h */
