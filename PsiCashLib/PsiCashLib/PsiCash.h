//
//  PsiCash.h
//  PsiCashLib
//

#import <Foundation/Foundation.h>

@interface PsiCash : NSObject

// The given tokens will be used for subsequent API calls. If no tokens are available,
// pass nil and then call validateOrAcquireTokens.
- (id)initWithAuthTokens:(NSDictionary*)authTokens;

- (void)validateOrAcquireTokens:(Boolean)isAccount completion:(void (^)(NSDictionary* authTokens, Boolean isAccount, NSError*))completionBlock;

- (void)getBalance:(void (^)(NSNumber* balance, Boolean isAccount, NSError*))completionBlock;

@end
