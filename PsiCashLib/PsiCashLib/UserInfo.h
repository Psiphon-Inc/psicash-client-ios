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
//  UserInfo.h
//  PsiCashLib
//

#ifndef UserInfo_h
#define UserInfo_h

#import "Purchase.h"

//
// Stores persistent info about the user.
//

@interface UserInfo : NSObject

//! authTokens maps token type to value.
@property (readonly) NSDictionary *authTokens;
@property BOOL isAccount;
@property NSNumber *balance;
@property NSArray *purchasePrices; // of PsiCashPurchasePrice
@property NSArray *purchases; // of PsiCashPurchase
@property NSTimeInterval serverTimeDiff;
@property NSString *lastTransactionID;

- (id)init;

//! Clears all user ID state.
- (void)clear;

- (void)setAuthTokens:(NSDictionary *)authTokens
                isAccount:(BOOL)isAccount;

//! Add the given purchase to the stored purchases.
- (void)addPurchase:(PsiCashPurchase*)purchase;

@end

#endif /* UserInfo_h */
