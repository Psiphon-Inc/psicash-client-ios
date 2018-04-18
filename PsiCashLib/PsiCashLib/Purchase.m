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
//  Purchase.m
//  PsiCashLib
//

#import <Foundation/Foundation.h>
#import "Purchase.h"

#define CODER_VERSION 1

@implementation PsiCashPurchase

- (id)initWithID:(NSString*_Nonnull)ID
transactionClass:(NSString*_Nonnull)transactionClass
   distinguisher:(NSString*_Nonnull)distinguisher
          expiry:(NSDate*_Nullable)expiry
   authorization:(NSString*_Nullable)authorization
{
    self.ID = ID;
    self.transactionClass = transactionClass;
    self.distinguisher = distinguisher;
    self.expiry = expiry;
    self.authorization = authorization;
    return self;
}

// Enable this object to be serializable into NSUserDefaults as NSData
- (instancetype _Nullable)initWithCoder:(NSCoder*_Nonnull)decoder
{
    self = [super init];
    if (!self) {
        return nil;
    }

    // Not checking CODER_VERSION yet

    self.ID = [decoder decodeObjectForKey:@"ID"];
    self.transactionClass = [decoder decodeObjectForKey:@"transactionClass"];
    self.distinguisher = [decoder decodeObjectForKey:@"distinguisher"];
    self.expiry = [decoder decodeObjectForKey:@"expiry"];
    self.authorization = [decoder decodeObjectForKey:@"authorization"];

    return self;
}
- (void)encodeWithCoder:(NSCoder*_Nonnull)encoder
{
    [encoder encodeObject:@CODER_VERSION forKey:@"CODER_VERSION"];
    [encoder encodeObject:self.ID forKey:@"ID"];
    [encoder encodeObject:self.transactionClass forKey:@"transactionClass"];
    [encoder encodeObject:self.distinguisher forKey:@"distinguisher"];
    [encoder encodeObject:self.expiry forKey:@"expiry"];
    [encoder encodeObject:self.authorization forKey:@"authorization"];
}

@end // @implementation PsiCashPurchase
