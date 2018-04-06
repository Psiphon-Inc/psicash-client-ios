//
//  TestHelpers.h
//  PsiCashLib
//
//  Created by Adam Pritchard on 2018-03-10.
//  Copyright © 2018 Adam Pritchard. All rights reserved.
//

#ifndef TestHelpers_h
#define TestHelpers_h

#import <PsiCashLib/PsiCashLib.h>
#import "SecretTestValues.h" // This file is in CipherShare

@interface TestHelpers : NSObject

//! Clears user tokens, etc.
+ (void)clearUserID:(PsiCash*_Nonnull)psiCash;

//! Set the user as an account. (Note that this messes up state.)
+ (void)setIsAccount:(PsiCash*_Nonnull)psiCash;

//! Get the current auth tokens.
+ (NSDictionary*)getAuthTokens:(PsiCash*_Nonnull)psiCash;

+ (void)setRequestMutators:(PsiCash*_Nonnull)psiCash
                  mutators:(NSArray*_Nonnull)mutators;

+ (void)make1TRewardRequest:(PsiCash*_Nonnull)psiCash
                 completion:(void (^_Nonnull)(BOOL success))completionHandler;

@end


#endif /* TestHelpers_h */
