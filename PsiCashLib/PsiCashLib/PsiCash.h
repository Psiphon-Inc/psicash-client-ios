//
//  PsiCash.h
//  PsiCashLib
//

#ifndef PsiCash_h
#define PsiCash_h

#import <Foundation/Foundation.h>

@interface PsiCash : NSObject

- (id)init;

// If no existing tokens are stored locally, new ones will be acquired. Otherwise,
// the existing tokens will be validated. 
- (void)validateOrAcquireTokens:(void (^)(NSArray *validTokenTypes, BOOL isAccount, NSError *error))completionBlock;

- (void)getBalance:(void (^)(NSNumber* balance, BOOL isAccount, NSError *error))completionBlock;

@end

#endif /* PsiCash_h */
