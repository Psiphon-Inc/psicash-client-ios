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
