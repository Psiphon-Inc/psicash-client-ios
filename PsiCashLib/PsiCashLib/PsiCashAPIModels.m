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
//  PsiCashAPIModels.m
//  PsiCashLib
//

#import <Foundation/Foundation.h>
#import "PsiCashAPIModels.h"

@implementation PsiCashRefreshResultModel

+ (PsiCashRefreshResultModel*)inProgress {
    PsiCashRefreshResultModel *instance = [[PsiCashRefreshResultModel alloc] init];
    instance.inProgress = YES;
    instance.error = nil;
    return instance;
}

+ (PsiCashRefreshResultModel*)success {
    PsiCashRefreshResultModel *instance = [[PsiCashRefreshResultModel alloc] init];
    instance.inProgress = NO;
    instance.error = nil;
    return instance;
}

@end

@implementation PsiCashMakePurchaseResultModel

+ (PsiCashMakePurchaseResultModel*)inProgress {
    PsiCashMakePurchaseResultModel *instance = [[PsiCashMakePurchaseResultModel alloc] init];
    instance.inProgress = YES;
    instance.status = PsiCashStatus_Invalid;
    instance.purchase = nil;
    instance.error = nil;
    return instance;
}

+ (PsiCashMakePurchaseResultModel*)failedWithStatus:(PsiCashStatus)status
                                           andError:(NSError*)error {
    PsiCashMakePurchaseResultModel *instance = [[PsiCashMakePurchaseResultModel alloc] init];
    instance.inProgress = NO;
    instance.status = status;
    instance.purchase = nil;
    instance.error = error;
    return instance;
}

+ (PsiCashMakePurchaseResultModel*)successWithStatus:(PsiCashStatus)status
                                         andPurchase:(PsiCashPurchase*)purchase
                                            andError:(NSError*)error {
    PsiCashMakePurchaseResultModel *instance = [[PsiCashMakePurchaseResultModel alloc] init];
    instance.inProgress = NO;
    instance.status = status;
    instance.purchase = purchase;
    instance.error = error;
    return instance;
}

@end
