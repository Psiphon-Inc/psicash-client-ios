//
//  TestHelpers.h
//  PsiCashLib
//

#ifndef TestHelpers_h
#define TestHelpers_h

#import <PsiCashLib/PsiCashLib.h>
#import "SecretTestValues.h" // This file is in CipherShare

@interface TestHelpers : NSObject

//! Clears user tokens, etc.
+ (void)clearUserInfo:(PsiCash*_Nonnull)psiCash;

//! Set the user as an account. (Note that this messes up state.)
+ (void)setIsAccount:(PsiCash*_Nonnull)psiCash;

//! Get the current auth tokens.
+ (NSDictionary*)getAuthTokens:(PsiCash*_Nonnull)psiCash;

+ (void)setRequestMutators:(PsiCash*_Nonnull)psiCash
                  mutators:(NSArray*_Nonnull)mutators;

+ (void)checkMutatorSupport:(PsiCash*_Nonnull)psiCash
                 completion:(void (^_Nonnull)(BOOL supported))completionHandler;

+ (void)make1TRewardRequest:(PsiCash*_Nonnull)psiCash
                 completion:(void (^_Nonnull)(BOOL success))completionHandler;

@end


#endif /* TestHelpers_h */
