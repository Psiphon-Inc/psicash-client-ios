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
//  PsiCash.h
//  PsiCashLib
//

#ifndef PsiCash_h
#define PsiCash_h

#import <Foundation/Foundation.h>


typedef NS_ENUM(NSInteger, PsiCashStatus) {
    PsiCashStatus_Invalid = -1,
    PsiCashStatus_Success = 0,
    PsiCashStatus_ExistingTransaction,
    PsiCashStatus_InsufficientBalance,
    PsiCashStatus_TransactionAmountMismatch,
    PsiCashStatus_TransactionTypeNotFound,
    PsiCashStatus_InvalidTokens,
    PsiCashStatus_ServerError
} NS_ENUM_AVAILABLE_IOS(6_0);


@interface PsiCashPurchasePrice : NSObject <NSCoding>
@property NSString*_Nonnull transactionClass;
@property NSString*_Nonnull distinguisher;
@property NSNumber*_Nonnull price;
@end

// NOTE: All completion handlers will be called on a single serial dispatch queue.
// They will be made asynchronously unless otherwise noted.
// (If it would be better for the library consumer to provide the queue, we can
// change the interface to do that.)

@interface PsiCash : NSObject

- (id _Nonnull)init;

/*! Returns the stored valid token types. Like ["spender", "indicator"]. May be
 nil or empty. */
- (NSArray*_Nullable)validTokenTypes;
//! Returns the stored info about whether the user is a tracker or an account.
- (BOOL)isAccount;
//! Returns the stored user balance. May be nil.
- (NSNumber*_Nullable)balance;
//! Returns the stored purchase prices. May be nil.
- (NSArray*_Nullable)purchasePrices;
/*! Returns the stored difference between the server time and the local time.
 (Positive if the server time is ahead, negative if behind.) */
- (NSTimeInterval)serverTimeDiff;

/*!
 Refreshes the client state. Retrieves info about whether the user has an
 account (vs tracker), balance, valid token types, and purchase prices.

 Input parameters:

 • purchaseClasses: The purchase class names for which prices should be retrieved,
   like `@["speed-boost"]`. If nil or empty, no purchase prices will be retrieved.

 Completion handler parameters:

 • serverTimeDiff: Indicates the difference between the server time and the local
   time. (Positive if the server time is ahead, negative if behind.)

 • validTokenTypes: Will contain the available valid token types, like:
   @code ["earner", "indicator", "spender"] @endcode

   If there are no tokens stored locally (e.g., if this is the first run), then
   new tracker tokens will obtained.

   If isAccount is true, then it is possible that not all expected tokens will be
   returned valid (they expire at different rates). Login may be necessary
   before spending, etc. (It's even possible that validTokenTypes is empty --
   i.e., there are no valid tokens.)

   If there is no valid indicator token, then balance and purchasePrices will be nil.

 • isAccount: Will be true if the tokens belong to an Account or false if a Tracker.

 • balance: The current balance of the user (tracker or account). Nil if there is
   no valid indicator token.

 • purchasePrices: An array of PsiCashPurchasePrice objects. May be emtpy if no
   transaction types of the given class(es) are found, or no classes where provided.
   Nil if there is no valid indicator token.

 • error: If non-nil, the request failed utterly and no other params are valid.

 Possible status codes:

 • PsiCashStatus_Success

 • PsiCashStatus_ServerError: The server returned 500 error response. Note that
   the request has already been retried internally and any further retry should
   not be immediate.

 • PsiCashStatus_Invalid: Error will be non-nil. This indicates that the server
   was totally unreachable or some other unrecoverable error occurred.

 • PsiCashStatus_InvalidTokens: Should never happen (indicates something like
   local storage corruption). The local user ID will be cleared.
 */
- (void)refreshState:(NSArray*_Nonnull)purchaseClasses
      withCompletion:(void (^_Nonnull)(PsiCashStatus status,
                                       NSTimeInterval serverTimeDiff,
                                       NSArray*_Nullable validTokenTypes,
                                       BOOL isAccount,
                                       NSNumber*_Nullable balance,
                                       NSArray*_Nullable purchasePrices, // of PsiCashPurchasePrice
                                       NSError*_Nullable error))completionHandler;

/*!
 Makes a new transaction for an "expiring-purchase" class, such as "speed-boost".

 Input parameters:

 • transactionClass: The class name of the desired purchase. (Like "speed-boost".)

 • transactionDistinguisher: The distinguisher for the desired purchase. (Like "1hr".)

 • expectedPrice: The expected price of the purchase (previously obtained by refreshState).
   The transaction will fail if the expectedPrice does not match the actual price.

Completion handler parameters:

 • status: Indicates whether the request succeeded or which failure condition occurred.

 • serverTimeDiff: Indicates the difference between the server time and the local
   time. (Positive if the server time is ahead, negative if behind.)

 • price: Indicates the price of the purchase. In success cases, will match the
   expectedPrice input. Nil if indicator token was not provided.

 • balance: The user's balance, newly updated if a successful purchase occurred.
   Nil if indicator token was not provided.

 • expiry: When the purchase is valid until, in server time.

 • authorization: The purchase authorization, if applicable to the purchase class
   (i.e., "speed-boost"). Nil if not applicable.

 • error: If non-nil, the request failed utterly and no other params are valid.

 Possible status codes:

 • PsiCashStatus_Success: The purchase transaction was successful. All completion
   handler arguments will be valid (authorization only if applicable).

 • PsiCashStatus_ExistingTransaction: There is already a non-expired purchase that
   prevents this purchase from proceeding. serverTimeDiff, price, and balance
   will be valid. expiry will be valid and will be set to the expiry of the existing
   purchase. This status suggests that a purchase retrieval is necessary (because
   an outstanding purchase is no known locally).

 • PsiCashStatus_InsufficientBalance: The user does not have sufficient Psi to make
   the requested purchase. serverTimeDiff, price, and balance are valid.

 • PsiCashStatus_TransactionAmountMismatch: The actual purchase price does not match
   expectedPrice, so the purchase cannot proceed. The price list should be updated
   immediately. serverTimeDiff, price, and balance are valid.

 • PsiCashStatus_TransactionTypeNotFound: A transaction type with the given class and
   distinguisher could not be found. The price list should be updated immediately,
   but it might also indicate an out-of-date app.

 • PsiCashStatus_InvalidTokens: The current auth tokens are invalid.
   TODO: Figure out how to handle this. It shouldn't be a factor for Trackers or MVP.

 • PsiCashStatus_ServerError: An error occurred on the server. Probably report to
   the user and try again later. Note that the request has already been retried
   internally and any further retry should not be immediate.
 */
- (void)newExpiringPurchaseTransactionForClass:(NSString*_Nonnull)transactionClass
                             withDistinguisher:(NSString*_Nonnull)transactionDistinguisher
                             withExpectedPrice:(NSNumber*_Nonnull)expectedPrice
                                withCompletion:(void (^_Nonnull)(PsiCashStatus status,
                                                                 NSTimeInterval serverTimeDiff,
                                                                 NSNumber*_Nullable price,
                                                                 NSNumber*_Nullable balance,
                                                                 NSDate*_Nullable expiry,
                                                                 NSString*_Nullable transactionID,
                                                                 NSString*_Nullable authorization,
                                                                 NSError*_Nullable error))completion;

@end

#endif /* PsiCash_h */
