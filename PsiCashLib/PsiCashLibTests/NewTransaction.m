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
//  NewTransaction.m
//  PsiCashLibTests
//

#import <XCTest/XCTest.h>
#import "TestHelpers.h"
#import "SecretTestValues.h"



@interface NewTransactionTests : XCTestCase

@property PsiCash *psiCash;

@end

@implementation NewTransactionTests {
    NSNumber *mutatorsEnabled;
}

@synthesize psiCash;

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.

    psiCash = [[PsiCash alloc] init];

    if (mutatorsEnabled == nil) {
        XCTestExpectation *expMutatorsEnabled = [self expectationWithDescription:@"Check if mutators enabled"];
        [TestHelpers checkMutatorSupport:psiCash completion:^(BOOL supported) {
            self->mutatorsEnabled = [NSNumber numberWithBool:supported];
            [expMutatorsEnabled fulfill];
        }];
    }

    XCTestExpectation *exp = [self expectationWithDescription:@"Init tokens"];

    [psiCash refreshState:@[] withCompletion:^(PsiCashStatus status,
                                               NSArray * _Nullable validTokenTypes,
                                               BOOL isAccount,
                                               NSNumber * _Nullable balance,
                                               NSArray * _Nullable purchasePrices,
                                               NSError * _Nullable error) {
        XCTAssertNil(error);
        XCTAssertEqual(status, PsiCashStatus_Success);

        [exp fulfill];
    }];

    [self waitForExpectationsWithTimeout:100 handler:nil];

    [self->psiCash expirePurchases];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [NSThread sleepForTimeInterval:1.0];
    [self->psiCash expirePurchases];
    [super tearDown];
}

- (void)testBasic {
    XCTestExpectation *exp = [self expectationWithDescription:@"Success: simple"];

    // Start by ensuring we have sufficient balance
    [TestHelpers make1TRewardRequest:psiCash
                          completion:^(BOOL success)
     {
         XCTAssert(success);

         // Check our balance to compare against later.
         [self->psiCash refreshState:@[] withCompletion:^(PsiCashStatus status,
                                                          NSArray * _Nullable validTokenTypes,
                                                          BOOL isAccount,
                                                          NSNumber * _Nullable prePurchaseBalance,
                                                          NSArray * _Nullable purchasePrices,
                                                          NSError * _Nullable error) {
             XCTAssertNil(error);
             XCTAssertEqual(status, PsiCashStatus_Success);
             XCTAssertGreaterThanOrEqual(prePurchaseBalance.integerValue, ONE_TRILLION);

             // Now make the transaction
             [self->psiCash newExpiringPurchaseTransactionForClass:@TEST_DEBIT_TRANSACTION_CLASS
                                                 withDistinguisher:@TEST_ONE_TRILLION_ONE_MICROSECOND_DISTINGUISHER
                                                 withExpectedPrice:@ONE_TRILLION
                                                    withCompletion:^(PsiCashStatus status,
                                                                     NSNumber*_Nullable price,
                                                                     NSNumber*_Nullable balance,
                                                                     NSDate*_Nullable expiry,
                                                                     NSString*_Nullable transactionID,
                                                                     NSString*_Nullable authorization,
                                                                     NSError*_Nullable error)
              {
                  XCTAssertNil(error);
                  XCTAssertEqual(status, PsiCashStatus_Success);
                  XCTAssertEqual(price.integerValue, ONE_TRILLION);
                  XCTAssertEqual(balance, @(prePurchaseBalance.integerValue - ONE_TRILLION));
                  XCTAssertNotNil(expiry);

                  NSDate *now = [NSDate dateWithTimeIntervalSinceNow:0];
                  // Check that the expiry is within 2 seconds of now.
                  XCTAssertLessThan(fabs([expiry timeIntervalSinceDate:now]), 2.0);

                  XCTAssertNotNil(transactionID);

                  // Our test class doesn't produce an authorization
                  XCTAssertNil(authorization);

                  XCTAssertGreaterThan([[self->psiCash validTokenTypes] count], 0);
                  XCTAssertEqual([self->psiCash balance], balance);

                  XCTAssert([transactionID isEqualToString:[[TestHelpers userInfo:self->psiCash] lastTransactionID]]);

                  XCTAssert([self containsTransactionWithID:transactionID
                                           transactionClass:@TEST_DEBIT_TRANSACTION_CLASS
                                              distinguisher:@TEST_ONE_TRILLION_ONE_MICROSECOND_DISTINGUISHER
                                              authorization:authorization]);

                  [exp fulfill];
              }];
         }];
     }];

    [self waitForExpectationsWithTimeout:100 handler:nil];
}

- (void)testInsufficientBalance {
    XCTestExpectation *exp = [self expectationWithDescription:@"Failure: insufficient balance"];

    // Check our balance to compare against later.
    [psiCash refreshState:@[] withCompletion:^(PsiCashStatus status,
                                               NSArray * _Nullable validTokenTypes,
                                               BOOL isAccount,
                                               NSNumber * _Nullable prePurchaseBalance,
                                               NSArray * _Nullable purchasePrices,
                                               NSError * _Nullable error) {
        XCTAssertNil(error);
        XCTAssertEqual(status, PsiCashStatus_Success);
        XCTAssertGreaterThanOrEqual(prePurchaseBalance, @0);

        [self->psiCash newExpiringPurchaseTransactionForClass:@TEST_DEBIT_TRANSACTION_CLASS
                                            withDistinguisher:@TEST_INT64_MAX_DISTINGUISHER
                                            withExpectedPrice:@TEST_INT64_MAX
                                               withCompletion:^(PsiCashStatus status,
                                                                NSNumber*_Nullable price,
                                                                NSNumber*_Nullable balance,
                                                                NSDate*_Nullable expiry,
                                                                NSString*_Nullable transactionID,
                                                                NSString*_Nullable authorization,
                                                                NSError*_Nullable error)
         {
             XCTAssertNil(error);
             XCTAssertEqual(status, PsiCashStatus_InsufficientBalance);
             XCTAssertEqual(price.integerValue, TEST_INT64_MAX);
             XCTAssertEqual(balance, prePurchaseBalance);
             XCTAssertNil(expiry);
             XCTAssertNil(transactionID);
             XCTAssertNil(authorization);

             [exp fulfill];
         }];
    }];

    [self waitForExpectationsWithTimeout:100 handler:nil];
}

- (void)testExistingTransaction {
    XCTestExpectation *exp = [self expectationWithDescription:@"Failure: existing transaction"];

    // Start by ensuring we have sufficient balance
    [TestHelpers make1TRewardRequest:psiCash
                          completion:^(BOOL success)
     {
         XCTAssert(success);

         // Successfully purchase the long-lived item
         [self->psiCash newExpiringPurchaseTransactionForClass:@TEST_DEBIT_TRANSACTION_CLASS
                                             withDistinguisher:@TEST_ONE_TRILLION_TEN_SECOND_DISTINGUISHER
                                             withExpectedPrice:@ONE_TRILLION
                                                withCompletion:^(PsiCashStatus status,
                                                                 NSNumber*_Nullable price,
                                                                 NSNumber*_Nullable balance,
                                                                 NSDate*_Nullable successfulExpiry,
                                                                 NSString*_Nullable successfulTransactionID,
                                                                 NSString*_Nullable authorization,
                                                                 NSError*_Nullable error)
          {
              XCTAssertNil(error);
              XCTAssertEqual(status, PsiCashStatus_Success); // IF THIS FAILS, WAIT ONE MINUTE AND TRY AGAIN
              XCTAssertEqual(price.integerValue, ONE_TRILLION);
              XCTAssertGreaterThanOrEqual(balance.integerValue, 0);
              XCTAssertNotNil(successfulTransactionID);
              XCTAssertNil(authorization);
              XCTAssertNotNil(successfulExpiry);

              XCTAssert([successfulTransactionID isEqualToString:[[TestHelpers userInfo:self->psiCash] lastTransactionID]]);

              XCTAssert([self containsTransactionWithID:successfulTransactionID
                                       transactionClass:@TEST_DEBIT_TRANSACTION_CLASS
                                          distinguisher:@TEST_ONE_TRILLION_TEN_SECOND_DISTINGUISHER
                                          authorization:authorization]);

              NSDate *now = [NSDate dateWithTimeIntervalSinceNow:0];
              XCTAssertEqual([successfulExpiry earlierDate:now], now);

              // Try and fail to make the same purchase again
              [self->psiCash newExpiringPurchaseTransactionForClass:@TEST_DEBIT_TRANSACTION_CLASS
                                                  withDistinguisher:@TEST_ONE_TRILLION_TEN_SECOND_DISTINGUISHER
                                                  withExpectedPrice:@ONE_TRILLION
                                                     withCompletion:^(PsiCashStatus status,
                                                                      NSNumber*_Nullable price,
                                                                      NSNumber*_Nullable balance,
                                                                      NSDate*_Nullable expiry,
                                                                      NSString*_Nullable transactionID,
                                                                      NSString*_Nullable authorization,
                                                                      NSError*_Nullable error)
               {
                   XCTAssertNil(error);
                   XCTAssertEqual(status, PsiCashStatus_ExistingTransaction);
                   XCTAssertEqual(price.integerValue, ONE_TRILLION);
                   XCTAssertGreaterThanOrEqual(balance.integerValue, 0);
                   XCTAssertNil(transactionID);
                   XCTAssertNil(authorization);

                   // Ensure the lastTransactionID hasn't been lost.
                   XCTAssert([successfulTransactionID isEqualToString:[[TestHelpers userInfo:self->psiCash] lastTransactionID]]);

                   // Let the transaction expire before continuing.
                   [NSThread sleepForTimeInterval:11.0];

                   [exp fulfill];
               }];
          }];
     }];

    [self waitForExpectationsWithTimeout:100 handler:nil];
}

- (void)testTransactionAmountMismatch {
    XCTestExpectation *exp = [self expectationWithDescription:@"Failure: transaction amount mismatch"];

    [psiCash newExpiringPurchaseTransactionForClass:@TEST_DEBIT_TRANSACTION_CLASS
                                  withDistinguisher:@TEST_INT64_MAX_DISTINGUISHER
                                  withExpectedPrice:@(TEST_INT64_MAX-1) // MISMATCH!
                                     withCompletion:^(PsiCashStatus status,
                                                      NSNumber*_Nullable price,
                                                      NSNumber*_Nullable balance,
                                                      NSDate*_Nullable expiry,
                                                      NSString*_Nullable transactionID,
                                                      NSString*_Nullable authorization,
                                                      NSError*_Nullable error)
     {
         XCTAssertNil(error);
         XCTAssertEqual(status, PsiCashStatus_TransactionAmountMismatch);
         XCTAssertEqual(price.integerValue, TEST_INT64_MAX);
         XCTAssertGreaterThanOrEqual(balance.integerValue, 0);
         XCTAssertNil(expiry);
         XCTAssertNil(transactionID);
         XCTAssertNil(authorization);

         [exp fulfill];
     }];

    [self waitForExpectationsWithTimeout:100 handler:nil];
}

- (void)testTransactionTypeNotFound {
    XCTestExpectation *exp = [self expectationWithDescription:@"Failure: transaction type not found"];

    [psiCash newExpiringPurchaseTransactionForClass:@TEST_DEBIT_TRANSACTION_CLASS
                                  withDistinguisher:@"INVALID"
                                  withExpectedPrice:@(TEST_INT64_MAX)
                                     withCompletion:^(PsiCashStatus status,
                                                      NSNumber*_Nullable price,
                                                      NSNumber*_Nullable balance,
                                                      NSDate*_Nullable expiry,
                                                      NSString*_Nullable transactionID,
                                                      NSString*_Nullable authorization,
                                                      NSError*_Nullable error)
     {
         XCTAssertNil(error);
         XCTAssertEqual(status, PsiCashStatus_TransactionTypeNotFound);
         XCTAssertNil(price);
         XCTAssertNil(balance);
         XCTAssertNil(expiry);
         XCTAssertNil(transactionID);
         XCTAssertNil(authorization);

         [exp fulfill];
     }];

    [self waitForExpectationsWithTimeout:100 handler:nil];
}

- (void)testInvalidTokens {
    if (![self->mutatorsEnabled boolValue]) {
        return;
    }

    XCTestExpectation *exp = [self expectationWithDescription:@"Failure: invalid tokens"];

    [TestHelpers setRequestMutators:self->psiCash
                           mutators:@[@"InvalidTokens"]];

    [self->psiCash newExpiringPurchaseTransactionForClass:@TEST_DEBIT_TRANSACTION_CLASS
                                        withDistinguisher:@TEST_ONE_TRILLION_ONE_MICROSECOND_DISTINGUISHER
                                        withExpectedPrice:@ONE_TRILLION
                                           withCompletion:^(PsiCashStatus status,
                                                            NSNumber*_Nullable price,
                                                            NSNumber*_Nullable balance,
                                                            NSDate*_Nullable expiry,
                                                            NSString*_Nullable transactionID,
                                                            NSString*_Nullable authorization,
                                                            NSError*_Nullable error)
     {
         XCTAssertNil(error);
         XCTAssertEqual(status, PsiCashStatus_InvalidTokens);
         XCTAssertNil(price);
         XCTAssertNil(balance);
         XCTAssertNil(expiry);
         XCTAssertNil(transactionID);
         XCTAssertNil(authorization);

         [exp fulfill];
     }];

    [self waitForExpectationsWithTimeout:100 handler:nil];
}

- (void)testNoServerResponse {
    if (![self->mutatorsEnabled boolValue]) {
        return;
    }

    XCTestExpectation *exp = [self expectationWithDescription:@"Error: no response from server"];

    [TestHelpers setRequestMutators:self->psiCash
                           mutators:@[@"Timeout:11"]];  // sleep for 11 secs

    [self->psiCash newExpiringPurchaseTransactionForClass:@TEST_DEBIT_TRANSACTION_CLASS
                                        withDistinguisher:@TEST_ONE_TRILLION_ONE_MICROSECOND_DISTINGUISHER
                                        withExpectedPrice:@ONE_TRILLION
                                           withCompletion:^(PsiCashStatus status,
                                                            NSNumber*_Nullable price,
                                                            NSNumber*_Nullable balance,
                                                            NSDate*_Nullable expiry,
                                                            NSString*_Nullable transactionID,
                                                            NSString*_Nullable authorization,
                                                            NSError*_Nullable error)
     {
         XCTAssertNotNil(error);
         XCTAssertEqual(status, PsiCashStatus_Invalid);

         [exp fulfill];
     }];

    [self waitForExpectationsWithTimeout:100 handler:nil];
}


- (void)testNoData {
    if (![self->mutatorsEnabled boolValue]) {
        return;
    }

    XCTestExpectation *exp = [self expectationWithDescription:@"Error: no data in response from server"];

    [TestHelpers setRequestMutators:self->psiCash
                           mutators:@[@"Response:code=200,body=none"]];

    [self->psiCash newExpiringPurchaseTransactionForClass:@TEST_DEBIT_TRANSACTION_CLASS
                                        withDistinguisher:@TEST_ONE_TRILLION_ONE_MICROSECOND_DISTINGUISHER
                                        withExpectedPrice:@ONE_TRILLION
                                           withCompletion:^(PsiCashStatus status,
                                                            NSNumber*_Nullable price,
                                                            NSNumber*_Nullable balance,
                                                            NSDate*_Nullable expiry,
                                                            NSString*_Nullable transactionID,
                                                            NSString*_Nullable authorization,
                                                            NSError*_Nullable error)
     {
         XCTAssertNotNil(error);
         XCTAssertEqual(status, PsiCashStatus_Invalid);

         [exp fulfill];
     }];

    [self waitForExpectationsWithTimeout:100 handler:nil];
}

- (void)testBadJSON {
    if (![self->mutatorsEnabled boolValue]) {
        return;
    }

    XCTestExpectation *exp = [self expectationWithDescription:@"Error: invalid JSON in response from server"];

    [TestHelpers setRequestMutators:self->psiCash
                           mutators:@[@"BadJSON:200"]];

    [self->psiCash newExpiringPurchaseTransactionForClass:@TEST_DEBIT_TRANSACTION_CLASS
                                        withDistinguisher:@TEST_ONE_TRILLION_ONE_MICROSECOND_DISTINGUISHER
                                        withExpectedPrice:@ONE_TRILLION
                                           withCompletion:^(PsiCashStatus status,
                                                            NSNumber*_Nullable price,
                                                            NSNumber*_Nullable balance,
                                                            NSDate*_Nullable expiry,
                                                            NSString*_Nullable transactionID,
                                                            NSString*_Nullable authorization,
                                                            NSError*_Nullable error)
     {
         XCTAssertNotNil(error);
         XCTAssertEqual(status, PsiCashStatus_Invalid);

         [exp fulfill];
     }];

    [self waitForExpectationsWithTimeout:100 handler:nil];
}

- (void)testServer500 {
    if (![self->mutatorsEnabled boolValue]) {
        return;
    }

    XCTestExpectation *exp = [self expectationWithDescription:@"Error: 500 response from server"];

    [TestHelpers setRequestMutators:self->psiCash
                           mutators:@[@"Response:code=500"]];

    [self->psiCash newExpiringPurchaseTransactionForClass:@TEST_DEBIT_TRANSACTION_CLASS
                                        withDistinguisher:@TEST_ONE_TRILLION_ONE_MICROSECOND_DISTINGUISHER
                                        withExpectedPrice:@ONE_TRILLION
                                           withCompletion:^(PsiCashStatus status,
                                                            NSNumber*_Nullable price,
                                                            NSNumber*_Nullable balance,
                                                            NSDate*_Nullable expiry,
                                                            NSString*_Nullable transactionID,
                                                            NSString*_Nullable authorization,
                                                            NSError*_Nullable error)
     {
         XCTAssertNil(error);
         XCTAssertEqual(status, PsiCashStatus_ServerError);

         [exp fulfill];
     }];

    [self waitForExpectationsWithTimeout:100 handler:nil];
}

- (void)testServerUnknownCode {
    if (![self->mutatorsEnabled boolValue]) {
        return;
    }

    XCTestExpectation *exp = [self expectationWithDescription:@"Error: unknown response code from server"];

    [TestHelpers setRequestMutators:self->psiCash
                           mutators:@[@"Response:code=666"]];

    [self->psiCash newExpiringPurchaseTransactionForClass:@TEST_DEBIT_TRANSACTION_CLASS
                                        withDistinguisher:@TEST_ONE_TRILLION_ONE_MICROSECOND_DISTINGUISHER
                                        withExpectedPrice:@ONE_TRILLION
                                           withCompletion:^(PsiCashStatus status,
                                                            NSNumber*_Nullable price,
                                                            NSNumber*_Nullable balance,
                                                            NSDate*_Nullable expiry,
                                                            NSString*_Nullable transactionID,
                                                            NSString*_Nullable authorization,
                                                            NSError*_Nullable error)
     {
         XCTAssertNotNil(error);
         XCTAssertEqual(status, PsiCashStatus_Invalid);

         [exp fulfill];
     }];

    [self waitForExpectationsWithTimeout:100 handler:nil];
}

- (BOOL)containsTransactionWithID:(NSString*_Nonnull)ID
                 transactionClass:(NSString*_Nonnull)transactionClass
                       distinguisher:(NSString*_Nonnull)distinguisher
                       authorization:(NSString*_Nullable)authorization
{
    NSArray *purchases = self->psiCash.purchases;
    if ([purchases count] == 0) {
        return NO;
    }

    for (PsiCashPurchase *purchase in purchases) {
        if ([TestHelpers is:purchase.ID equalTo:ID] &&
            [TestHelpers is:purchase.transactionClass equalTo:transactionClass] &&
            [TestHelpers is:purchase.distinguisher equalTo:distinguisher] &&
            [TestHelpers is:purchase.authorization equalTo:authorization]) {
            return YES;
        }
    }

    return NO;
}

@end
