//
//  PsiCash.h
//  PsiCashLib
//

#ifndef PsiCash_h
#define PsiCash_h

#import <Foundation/Foundation.h>

typedef enum {
    kInvalid = -1,
    kSuccess = 0,
    kExistingTransaction,
    kInsufficientBalance,
    kTransactionAmountMismatch,
    kTransactionTypeNotFound,
    kInvalidTokens,
    kServerError
} PsiCashRequestStatus;

@interface PsiCash : NSObject

- (id)init;

/*!
 If no existing tokens are stored locally, new ones will be acquired. Otherwise,
 the existing tokens will be validated.

 If error is non-nil, the request failed utterly and no other params are valid.

 Possible status codes:

    • kSuccess

 ??????????????

    • kServerError
 */
- (void)validateOrAcquireTokens:(void (^)(PsiCashRequestStatus status,
                                          NSArray *validTokenTypes,
                                          BOOL isAccount,
                                          NSError *error))completionHandler;

/*!
 Retrieves the user's balance.

 If error is non-nil, the request failed utterly and no other params are valid.

 Possible status codes:

    • kSuccess

    • kInvalidTokens: TODO: Figure out how to handle this.

    • kServerError
 */
- (void)getBalance:(void (^)(PsiCashRequestStatus status,
                             NSNumber *balance,
                             NSError *error))completionHandler;

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

    • kSuccess: The purchase transaction was successful. price, balance,
      and expiry will be valid. authorization will be valid if applicable.

    • kExistingTransaction: There is already a non-expired purchase that
      prevents this purchase from proceeding. price and balance will be valid.
      expiry will be valid and will be set to the expiry of the existing purchase.

    • kInsufficientBalance: The user does not have sufficient Psi to make
      the requested purchase. price and balance are valid.

    • kTransactionAmountMismatch: The actual purchase price does not match
      expectedPrice, so the purchase cannot proceed. The price list should be updated
      immediately. price and balance are valid.

    • kTransactionTypeNotFound: A transaction type with the given class and
      distinguisher could not be found. The price list should be updated immediately,
      but it might also indicate an out-of-date app.

    • kInvalidTokens: The current auth tokens are invalid.
      TODO: Figure out how to handle this. It shouldn't be a factor for Trackers or MVP.

    • kServerError: An error occurred on the server. Probably report to the user and
      try again later.
*/
- (void)newExpiringPurchaseTransactionForClass:(NSString*)transactionClass
                             withDistinguisher:(NSString*)transactionDistinguisher 
                             withExpectedPrice:(NSNumber*)expectedPrice
                                withCompletion:(void (^)(PsiCashRequestStatus status,
                                                         NSNumber *price,
                                                         NSNumber *balance,
                                                         NSDate *expiry,
                                                         NSString *authorization,
                                                         NSError *error))completion;

@end

#endif /* PsiCash_h */
