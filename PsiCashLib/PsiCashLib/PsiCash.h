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


@interface PsiCashPurchasePrice : NSObject
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


/*!
 Refreshes the client state. Retrieves info about whether the user has an
 account (vs tracker), balance, valid token types. It also retrieves purchase
 prices, as specified by the purchaseClasses param.

 If there are no tokens stored locally (e.g., if this is the first run), then new
 tracker tokens will obtained.

 If isAccount is true, then it is possible that not all expected tokens will be
 returned valid (they expire at different rates). Login may be necessary
 before spending, etc. (It's even possible that validTokenTypes is empty --
 i.e., there are no valid tokens.)

 If there is no valid indicator token, then balance and purchasePrices will be nil.

 If error is non-nil, the request failed utterly and no other params are valid.

 validTokenTypes will contain the available valid token types, like:
 @code ["earner", "indicator", "spender"] @endcode

 isAccount will be true if the tokens belong to an Account or false if a Tracker.

 purchasePrices is an array of PsiCashPurchasePrice objects. May be emtpy if no
 transaction types of the given class(es) are found.

 Possible status codes:

 • PsiCashStatus_Success

 • PsiCashStatus_ServerError

 • PsiCashStatus_Invalid: error will be non-nil.

 • PsiCashStatus_InvalidTokens: Should never happen. The local user ID will be cleared.

 */
- (void)refreshState:(NSArray*_Nonnull)purchaseClasses
      withCompletion:(void (^_Nonnull)(PsiCashStatus status,
                                       NSArray*_Nullable validTokenTypes,
                                       BOOL isAccount,
                                       NSNumber*_Nullable balance,
                                       NSArray*_Nullable purchasePrices, // of PsiCashPurchasePrice
                                       NSError*_Nullable error))completionHandler;


/*!
 Makes a new transaction for an "expiring-purchase" class, such as "speed-boost".
 The validity of completion params varies with status and input. Here are the
 meanings of the params:

 • status: Indicates whether the request succeeded or which failure condition occurred.

 • price: Indicates the price of the purchase. In success cases, will match the expectedPrice input.

 • balance: The user's balance, newly updated if a successful purchase occurred.

 • expiry: When the purchase is valid until.

 • authorization: The purchase authorization, if applicable to the purchase class (i.e., "speed-boost").

 If error is non-nil, the request failed utterly and no other params are valid.

 Possible status codes:

 • PsiCashStatus_Success: The purchase transaction was successful. price, balance,
 and expiry will be valid. authorization will be valid if applicable.

 • PsiCashStatus_ExistingTransaction: There is already a non-expired purchase that
 prevents this purchase from proceeding. price and balance will be valid.
 expiry will be valid and will be set to the expiry of the existing purchase.

 • PsiCashStatus_InsufficientBalance: The user does not have sufficient Psi to make
 the requested purchase. price and balance are valid.

 • PsiCashStatus_TransactionAmountMismatch: The actual purchase price does not match
 expectedPrice, so the purchase cannot proceed. The price list should be updated
 immediately. price and balance are valid.

 • PsiCashStatus_TransactionTypeNotFound: A transaction type with the given class and
 distinguisher could not be found. The price list should be updated immediately,
 but it might also indicate an out-of-date app.

 • PsiCashStatus_InvalidTokens: The current auth tokens are invalid.
 TODO: Figure out how to handle this. It shouldn't be a factor for Trackers or MVP.

 • PsiCashStatus_ServerError: An error occurred on the server. Probably report to the user and
 try again later.
 */
- (void)newExpiringPurchaseTransactionForClass:(NSString*_Nonnull)transactionClass
                             withDistinguisher:(NSString*_Nonnull)transactionDistinguisher
                             withExpectedPrice:(NSNumber*_Nonnull)expectedPrice
                                withCompletion:(void (^_Nonnull)(PsiCashStatus status,
                                                                 NSNumber*_Nullable price,
                                                                 NSNumber*_Nullable balance,
                                                                 NSDate*_Nullable expiry,
                                                                 NSString*_Nullable authorization,
                                                                 NSError*_Nullable error))completion;

@end

#endif /* PsiCash_h */
