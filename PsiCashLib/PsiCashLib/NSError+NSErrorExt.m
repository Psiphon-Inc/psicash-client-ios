//
//  NSError+NSErrorExt.m
//  PsiCashLib
//

#import "NSError+NSErrorExt.h"

NSString * const ERROR_DOMAIN = @"PsiCashLibErrorDomain";
int const DEFAULT_ERROR_CODE = -1;

@implementation NSError (NSErrorExt)

+ (NSError *)errorWrapping:(NSError*)error withMessage:(NSString*)message fromFunction:(const char*)funcname
{
    NSString *desc = [NSString stringWithFormat:@"PsiCashLib:: %s: %@", funcname, message];
    return [NSError errorWithDomain:ERROR_DOMAIN
                               code:DEFAULT_ERROR_CODE
                           userInfo:@{NSLocalizedDescriptionKey: desc,
                                      NSUnderlyingErrorKey: error}];
}

+ (NSError *)errorWithMessage:(NSString*)message fromFunction:(const char*)funcname
{
    NSString *desc = [NSString stringWithFormat:@"PsiCashLib:: %s: %@", funcname, message];
    return [NSError errorWithDomain:ERROR_DOMAIN
                               code:DEFAULT_ERROR_CODE
                           userInfo:@{NSLocalizedDescriptionKey: desc}];
}

@end
