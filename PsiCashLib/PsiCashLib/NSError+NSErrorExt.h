//
//  NSError+NSErrorExt.h
//  PsiCashLib
//

#import <Foundation/Foundation.h>

@interface NSError (NSErrorExt)

+ (NSError *)errorWrapping:(NSError*)error withMessage:(NSString*)message fromFunction:(const char*)funcname;

+ (NSError *)errorWithMessage:(NSString*)message fromFunction:(const char*)funcname;

@end
