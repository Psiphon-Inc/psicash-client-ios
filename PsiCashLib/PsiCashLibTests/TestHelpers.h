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
