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
//  Accessors.m
//  PsiCashLibTests
//

#import <XCTest/XCTest.h>
#import "TestHelpers.h"
#import "SecretTestValues.h"


// Expose some private methods to help with testing
@interface PsiCash (Testing)
- (NSDate*_Nullable)adjustServerTimeToLocal:(NSDate*_Nullable)date;
- (NSDate*_Nullable)adjustLocalTimeToServer:(NSDate*_Nullable)date;
@end


@interface AccessorsTests : XCTestCase

@property PsiCash *psiCash;

@end


@implementation AccessorsTests

@synthesize psiCash;

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.

    psiCash = [TestHelpers newPsiCash];

    XCTestExpectation *exp = [self expectationWithDescription:@"Init tokens"];

    [psiCash refreshState:@[] withCompletion:^(PsiCashStatus status,
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

    // Let the transactions expire
    [NSThread sleepForTimeInterval:1.0];
    // Clear out the expired purchases.
    [self->psiCash expirePurchases];

    [super tearDown];
}

- (void)testAdjustServerTimeToLocal {
    NSDate *arbitraryDate = [NSDate date];

    // Positive server time diff means the server clock is ahead.
    [TestHelpers userInfo:self->psiCash].serverTimeDiff = 1000.0;
    NSDate *adjusted = [psiCash adjustServerTimeToLocal:arbitraryDate];
    XCTAssertNotNil(adjusted);

    // If the server thinks the expiry is 09:00, but the server is 1000 secs ahead
    // of the client, then the client needs to consider the expiry to be 09:00 - 1000secs.
    NSTimeInterval adjustment = [adjusted timeIntervalSinceDate:arbitraryDate];
    XCTAssertEqual(adjustment, -1000.0);

    // Negative server time diff means the server clock is behind.
    [TestHelpers userInfo:self->psiCash].serverTimeDiff = -1000.0;
    adjusted = [psiCash adjustServerTimeToLocal:arbitraryDate];
    XCTAssertNotNil(adjusted);
    adjustment = [adjusted timeIntervalSinceDate:arbitraryDate];
    XCTAssertEqual(adjustment, 1000.0);

    // Test nil
    adjusted = [psiCash adjustServerTimeToLocal:nil];
    XCTAssertNil(adjusted);
}

- (void)testAdjustLocalTimeToServer {
    NSDate *arbitraryDate = [NSDate date];

    // Positive server time diff means the server clock is ahead.
    [TestHelpers userInfo:self->psiCash].serverTimeDiff = 1000.0;
    NSDate *adjusted = [psiCash adjustLocalTimeToServer:arbitraryDate];
    XCTAssertNotNil(adjusted);

    // If the client thinks the expiry is 09:00, but the server is 1000 secs ahead
    // of the client, then the server thinks the expiry is 09:00 + 1000secs.
    NSTimeInterval adjustment = [adjusted timeIntervalSinceDate:arbitraryDate];
    XCTAssertEqual(adjustment, 1000.0);

    // Negative server time diff means the server clock is behind.
    [TestHelpers userInfo:self->psiCash].serverTimeDiff = -1000.0;
    adjusted = [psiCash adjustLocalTimeToServer:arbitraryDate];
    XCTAssertNotNil(adjusted);
    adjustment = [adjusted timeIntervalSinceDate:arbitraryDate];
    XCTAssertEqual(adjustment, -1000.0);

    // Test nil
    adjusted = [psiCash adjustLocalTimeToServer:nil];
    XCTAssertNil(adjusted);
}

- (void)testGetPurchasePrices {
    XCTestExpectation *exp = [self expectationWithDescription:@"Success: getPurchasePrices"];

    [self->psiCash refreshState:@[@"speed-boost"] withCompletion:^(PsiCashStatus status,
                                                                   NSError * _Nullable error)
     {
         XCTAssertNil(error);
         XCTAssertEqual(status, PsiCashStatus_Success);

         XCTAssertGreaterThan(self->psiCash.purchasePrices.count, 0);

         [exp fulfill];
     }];


    [self waitForExpectationsWithTimeout:100 handler:nil];
}

- (void)testGetPurchases {
    XCTestExpectation *exp = [self expectationWithDescription:@"Success: getPurchases"];

    // Start by ensuring we have sufficient balance
    [TestHelpers makeRewardRequests:self->psiCash
                             amount:2
                         completion:^(BOOL success)
     {
         XCTAssertTrue(success);

         // Clear out any pre-existing expired purchases.
         [self->psiCash expirePurchases];


         [self->psiCash newExpiringPurchaseTransactionForClass:@TEST_DEBIT_TRANSACTION_CLASS
                                             withDistinguisher:@TEST_ONE_TRILLION_ONE_MICROSECOND_DISTINGUISHER
                                             withExpectedPrice:@ONE_TRILLION
                                                withCompletion:^(PsiCashStatus status,
                                                                 PsiCashPurchase*_Nullable purchase1,
                                                                 NSError*_Nullable error)
          {
              XCTAssertNil(error);
              XCTAssertEqual(status, PsiCashStatus_Success);

              NSArray *purchases = self->psiCash.purchases;
              XCTAssert([purchases count] == 1);
              for (PsiCashPurchase *p in purchases) {
                  XCTAssertEqualObjects(p.ID, purchase1.ID);
              }

              [self->psiCash newExpiringPurchaseTransactionForClass:@TEST_DEBIT_TRANSACTION_CLASS
                                                  withDistinguisher:@TEST_ONE_TRILLION_ONE_MICROSECOND_DISTINGUISHER
                                                  withExpectedPrice:@ONE_TRILLION
                                                     withCompletion:^(PsiCashStatus status,
                                                                      PsiCashPurchase*_Nullable purchase2,
                                                                      NSError*_Nullable error)
               {
                   XCTAssertNil(error);
                   XCTAssertEqual(status, PsiCashStatus_Success);

                   NSArray *purchases = self->psiCash.purchases;
                   XCTAssert([purchases count] == 2);
                   for (PsiCashPurchase *p in purchases) {
                       XCTAssert([p.ID isEqualToString:purchase1.ID] || [p.ID isEqualToString:purchase2.ID]);
                   }

                   [exp fulfill];
               }];
          }];
     }];


    [self waitForExpectationsWithTimeout:100 handler:nil];
}

- (void)testValidPurchases {
    XCTestExpectation *exp = [self expectationWithDescription:@"Success: validPurchases"];

    // Start by ensuring we have sufficient balance
    [TestHelpers makeRewardRequests:self->psiCash
                             amount:2
                         completion:^(BOOL success)
     {
         XCTAssertTrue(success);

         // Clear out any pre-existing expired purchases.
         [self->psiCash expirePurchases];

         // Make a fast-expiring purchase
         [self->psiCash newExpiringPurchaseTransactionForClass:@TEST_DEBIT_TRANSACTION_CLASS
                                             withDistinguisher:@TEST_ONE_TRILLION_ONE_MICROSECOND_DISTINGUISHER
                                             withExpectedPrice:@ONE_TRILLION
                                                withCompletion:^(PsiCashStatus status,
                                                                 PsiCashPurchase*_Nullable purchase1,
                                                                 NSError*_Nullable error)
          {
              XCTAssertNil(error);
              XCTAssertEqual(status, PsiCashStatus_Success);
              XCTAssertNotNil(purchase1);

              // Make a long-expiring purchase
              [self->psiCash newExpiringPurchaseTransactionForClass:@TEST_DEBIT_TRANSACTION_CLASS
                                                  withDistinguisher:@TEST_ONE_TRILLION_TEN_SECOND_DISTINGUISHER
                                                  withExpectedPrice:@ONE_TRILLION
                                                     withCompletion:^(PsiCashStatus status,
                                                                      PsiCashPurchase*_Nullable purchase2,
                                                                      NSError*_Nullable error)
               {
                   XCTAssertNil(error);
                   XCTAssertEqual(status, PsiCashStatus_Success);
                   XCTAssertNotNil(purchase2);

                   XCTAssertEqual([self->psiCash purchases].count, 2);

                   // Wait long enough that the short purchase is likely to have expired.
                   [NSThread sleepForTimeInterval:5.0];

                   NSArray<PsiCashPurchase*> *validPurchases = [self->psiCash validPurchases];
                   XCTAssertNotNil(validPurchases);

                   // NOTE: Incorrect server time diff may mess up this test.
                   XCTAssertEqual([validPurchases count], 1);

                   // Ensure validPurchases didn't alter the stored set of purchases.
                   XCTAssertEqual([[self->psiCash purchases] count], 2);

                   // Wait for the longer-lived purchase to expire.
                   [NSThread sleepForTimeInterval:10.0];

                   XCTAssertEqual([[self->psiCash validPurchases] count], 0);

                   XCTAssertEqual([[self->psiCash purchases] count], 2);
                   [self->psiCash expirePurchases];
                   XCTAssertEqual([[self->psiCash purchases] count], 0);

                   [exp fulfill];
               }];
          }];
     }];


    [self waitForExpectationsWithTimeout:100 handler:nil];
}

- (void)testNextExpiringPurchase1 {
    XCTestExpectation *exp = [self expectationWithDescription:@"Success: nextExpiringPurchase; long then short"];

    // Start by ensuring we have sufficient balance
    [TestHelpers makeRewardRequests:self->psiCash
                             amount:2
                         completion:^(BOOL success)
     {
         XCTAssertTrue(success);

        // Clear out any pre-existing expired purchases.
        [self->psiCash expirePurchases];

        [self->psiCash newExpiringPurchaseTransactionForClass:@TEST_DEBIT_TRANSACTION_CLASS
                                            withDistinguisher:@TEST_ONE_TRILLION_ONE_SECOND_DISTINGUISHER
                                            withExpectedPrice:@ONE_TRILLION
                                               withCompletion:^(PsiCashStatus status,
                                                                PsiCashPurchase*_Nullable longPurchase,
                                                                NSError*_Nullable error)
         {
             XCTAssertNil(error);
             XCTAssertEqual(status, PsiCashStatus_Success);
             XCTAssertNotNil(longPurchase);

             [self->psiCash newExpiringPurchaseTransactionForClass:@TEST_DEBIT_TRANSACTION_CLASS
                                                 withDistinguisher:@TEST_ONE_TRILLION_ONE_MICROSECOND_DISTINGUISHER
                                                 withExpectedPrice:@ONE_TRILLION
                                                    withCompletion:^(PsiCashStatus status,
                                                                     PsiCashPurchase*_Nullable shortPurchase,
                                                                     NSError*_Nullable error)
              {
                  XCTAssertNil(error);
                  XCTAssertEqual(status, PsiCashStatus_Success);
                  XCTAssertNotNil(shortPurchase);

                  PsiCashPurchase *p = [self->psiCash nextExpiringPurchase];
                  XCTAssertNotNil(p);
                  XCTAssert([p.ID isEqualToString:shortPurchase.ID]);
                  XCTAssert([p.localTimeExpiry isEqualToDate:shortPurchase.localTimeExpiry]);

                  [exp fulfill];
              }];
         }];
    }];


    [self waitForExpectationsWithTimeout:100 handler:nil];
}

- (void)testNextExpiringPurchase2 {
    XCTestExpectation *exp = [self expectationWithDescription:@"Success: nextExpiringPurchase; short then long"];

    // Start by ensuring we have sufficient balance
    [TestHelpers makeRewardRequests:self->psiCash
                             amount:2
                         completion:^(BOOL success)
     {
         XCTAssertTrue(success);

        // Clear out any pre-existing purchases.
        [TestHelpers userInfo:self->psiCash].purchases = nil;

        [self->psiCash newExpiringPurchaseTransactionForClass:@TEST_DEBIT_TRANSACTION_CLASS
                                            withDistinguisher:@TEST_ONE_TRILLION_ONE_MICROSECOND_DISTINGUISHER
                                            withExpectedPrice:@ONE_TRILLION
                                               withCompletion:^(PsiCashStatus status,
                                                                PsiCashPurchase*_Nullable shortPurchase,
                                                                NSError*_Nullable error)
         {
             XCTAssertNil(error);
             XCTAssertEqual(status, PsiCashStatus_Success);

             PsiCashPurchase *firstNextExpiringPurchase = [self->psiCash nextExpiringPurchase];
             XCTAssertNotNil(firstNextExpiringPurchase);
             XCTAssert([firstNextExpiringPurchase.ID isEqualToString:shortPurchase.ID]);
             XCTAssert([firstNextExpiringPurchase.localTimeExpiry isEqualToDate:shortPurchase.localTimeExpiry]);


             [self->psiCash newExpiringPurchaseTransactionForClass:@TEST_DEBIT_TRANSACTION_CLASS
                                                 withDistinguisher:@TEST_ONE_TRILLION_ONE_SECOND_DISTINGUISHER
                                                 withExpectedPrice:@ONE_TRILLION
                                                    withCompletion:^(PsiCashStatus status,
                                                                     PsiCashPurchase*_Nullable longPurchase,
                                                                     NSError*_Nullable error)
              {
                  XCTAssertNil(error);
                  XCTAssertEqual(status, PsiCashStatus_Success);

                  PsiCashPurchase *secondNextExpiringPurchase = [self->psiCash nextExpiringPurchase];
                  XCTAssertNotNil(secondNextExpiringPurchase);
                  XCTAssert([secondNextExpiringPurchase.ID isEqualToString:shortPurchase.ID]);
                  // We can't compare shortLocalTimeExpiry to anything at this
                  // point because the serverTimeDiff changed with the last request.

                  // Let the longer purchase expire.
                  [NSThread sleepForTimeInterval:1.1];

                  [exp fulfill];
              }];
         }];
    }];


    [self waitForExpectationsWithTimeout:100 handler:nil];
}

- (void)testExpirePurchases {
    XCTestExpectation *exp = [self expectationWithDescription:@"Success: expirePurchases"];

    // Start by ensuring we have sufficient balance
    [TestHelpers makeRewardRequests:self->psiCash
                             amount:2
                         completion:^(BOOL success)
     {
         XCTAssertTrue(success);

        // Clear out any pre-existing expired purchases.
        [self->psiCash expirePurchases];

         XCTAssertEqual(self->psiCash.purchases.count, 0);

        [self->psiCash newExpiringPurchaseTransactionForClass:@TEST_DEBIT_TRANSACTION_CLASS
                                            withDistinguisher:@TEST_ONE_TRILLION_ONE_MICROSECOND_DISTINGUISHER
                                            withExpectedPrice:@ONE_TRILLION
                                               withCompletion:^(PsiCashStatus status,
                                                                PsiCashPurchase*_Nullable purchase1,
                                                                NSError*_Nullable error)
         {
             XCTAssertNil(error);
             XCTAssertEqual(status, PsiCashStatus_Success);
             XCTAssertNotNil(purchase1);

             [self->psiCash newExpiringPurchaseTransactionForClass:@TEST_DEBIT_TRANSACTION_CLASS
                                                 withDistinguisher:@TEST_ONE_TRILLION_TEN_SECOND_DISTINGUISHER
                                                 withExpectedPrice:@ONE_TRILLION
                                                    withCompletion:^(PsiCashStatus status,
                                                                     PsiCashPurchase*_Nullable purchase2,
                                                                     NSError*_Nullable error)
              {
                  XCTAssertNil(error);
                  XCTAssertEqual(status, PsiCashStatus_Success);
                  XCTAssertNotNil(purchase2);

                  // NOTE: These tests may fail if the client-server time adjustment
                  // is too inaccurate. We're going to sleep for 5 secs, which
                  // should ensure that the 1 microsecond purchase is expired
                  // but the 10 second purchase is not.
                  [NSThread sleepForTimeInterval:5.0];

                  NSArray *expiredPurchases = [self->psiCash expirePurchases];
                  XCTAssertNotNil(expiredPurchases);
                  XCTAssertEqual(expiredPurchases.count, 1);
                  for (PsiCashPurchase *p in expiredPurchases) {
                      XCTAssert([p.ID isEqualToString:purchase1.ID]);
                  }

                  // Let the longer purchase expire
                  [NSThread sleepForTimeInterval:11.0];

                  expiredPurchases = [self->psiCash expirePurchases];
                  XCTAssertNotNil(expiredPurchases);
                  XCTAssertEqual(expiredPurchases.count, 1);
                  for (PsiCashPurchase *p in expiredPurchases) {
                      XCTAssert([p.ID isEqualToString:purchase2.ID]);
                  }

                  [exp fulfill];
              }];
         }];
    }];


    [self waitForExpectationsWithTimeout:100 handler:nil];
}

- (void)testRemovePurchases {
    XCTestExpectation *exp = [self expectationWithDescription:@"Success: removePurchases"];

    // Start by ensuring we have sufficient balance
    [TestHelpers makeRewardRequests:self->psiCash
                             amount:3
                         completion:^(BOOL success)
     {
         XCTAssertTrue(success);

        // First add and remove a single transaction
        [self->psiCash newExpiringPurchaseTransactionForClass:@TEST_DEBIT_TRANSACTION_CLASS
                                            withDistinguisher:@TEST_ONE_TRILLION_ONE_MICROSECOND_DISTINGUISHER
                                            withExpectedPrice:@ONE_TRILLION
                                               withCompletion:^(PsiCashStatus status,
                                                                PsiCashPurchase*_Nullable purchase,
                                                                NSError*_Nullable error)
         {
             XCTAssertNil(error);
             XCTAssertEqual(status, PsiCashStatus_Success);
             XCTAssertNotNil(purchase);

             XCTAssert([self->psiCash.purchases count] == 1 &&
                       [self->psiCash.purchases[0].ID isEqualToString:purchase.ID]);

             // Remove this transaction
             [self->psiCash removePurchases:@[purchase.ID]];
             XCTAssert([self->psiCash.purchases count] == 0);

             // Now add and remove two transactions
             [self->psiCash newExpiringPurchaseTransactionForClass:@TEST_DEBIT_TRANSACTION_CLASS
                                                 withDistinguisher:@TEST_ONE_TRILLION_ONE_MICROSECOND_DISTINGUISHER
                                                 withExpectedPrice:@ONE_TRILLION
                                                    withCompletion:^(PsiCashStatus status,
                                                                     PsiCashPurchase*_Nullable purchase1,
                                                                     NSError*_Nullable error)
              {
                  XCTAssertNil(error);
                  XCTAssertEqual(status, PsiCashStatus_Success);

                  XCTAssertEqual([self->psiCash.purchases count], 1);
                  XCTAssertEqualObjects(self->psiCash.purchases[0].ID, purchase1.ID);

                  [self->psiCash newExpiringPurchaseTransactionForClass:@TEST_DEBIT_TRANSACTION_CLASS
                                                      withDistinguisher:@TEST_ONE_TRILLION_ONE_MICROSECOND_DISTINGUISHER
                                                      withExpectedPrice:@ONE_TRILLION
                                                         withCompletion:^(PsiCashStatus status,
                                                                          PsiCashPurchase*_Nullable purchase2,
                                                                          NSError*_Nullable error)
                   {
                       XCTAssertEqual([self->psiCash.purchases count], 2);
                       XCTAssertNotEqualObjects(self->psiCash.purchases[0].ID, self->psiCash.purchases[1].ID);
                       XCTAssert([self->psiCash.purchases[0].ID isEqualToString:purchase1.ID] || [self->psiCash.purchases[1].ID isEqualToString:purchase1.ID]);
                       XCTAssert([self->psiCash.purchases[0].ID isEqualToString:purchase2.ID] || [self->psiCash.purchases[1].ID isEqualToString:purchase2.ID]);

                       // Remove the transactions
                       [self->psiCash removePurchases:@[purchase1.ID, purchase2.ID]];
                       XCTAssertEqual([self->psiCash.purchases count], 0);

                       [exp fulfill];
                   }];
              }];
         }];
    }];


    [self waitForExpectationsWithTimeout:100 handler:nil];
}

- (void)testPurchaseTimeAdjustment {
    XCTestExpectation *exp = [self expectationWithDescription:@"Success: removePurchases"];

    // Start by ensuring we have sufficient balance
    [TestHelpers makeRewardRequests:self->psiCash
                             amount:3
                         completion:^(BOOL success)
     {
         XCTAssertTrue(success);

         [self->psiCash newExpiringPurchaseTransactionForClass:@TEST_DEBIT_TRANSACTION_CLASS
                                             withDistinguisher:@TEST_ONE_TRILLION_ONE_MICROSECOND_DISTINGUISHER
                                             withExpectedPrice:@ONE_TRILLION
                                                withCompletion:^(PsiCashStatus status,
                                                                 PsiCashPurchase*_Nullable purchase,
                                                                 NSError*_Nullable error)
          {
              XCTAssertNil(error);
              XCTAssertEqual(status, PsiCashStatus_Success);
              XCTAssertNotNil(purchase);

              [self->psiCash newExpiringPurchaseTransactionForClass:@TEST_DEBIT_TRANSACTION_CLASS
                                                  withDistinguisher:@TEST_ONE_TRILLION_ONE_MICROSECOND_DISTINGUISHER
                                                  withExpectedPrice:@ONE_TRILLION
                                                     withCompletion:^(PsiCashStatus status,
                                                                      PsiCashPurchase*_Nullable purchase,
                                                                      NSError*_Nullable error)
               {
                   XCTAssertNil(error);
                   XCTAssertEqual(status, PsiCashStatus_Success);
                   XCTAssertNotNil(purchase);

                   // Even though `purchase` was initialized before we start
                   // tweaking serverTimeDiff, it is still probably a pointer
                   // to an object that will get modified by our accessors.
                   // So we shouldn't expect its localTimeExpiry to remain
                   // different than the ones below. (And so we won't test it
                   // directly.)

                   void (^test)(NSTimeInterval, PsiCashPurchase*) = ^(NSTimeInterval serverTimeDiff, PsiCashPurchase *purchase) {
                       XCTAssertNotNil(purchase.localTimeExpiry);

                       NSTimeInterval timeInterval = [purchase.serverTimeExpiry timeIntervalSinceDate:purchase.localTimeExpiry];
                       XCTAssertEqual(timeInterval, serverTimeDiff);

                   };

                   //
                   // purchases accessor
                   //

                   // Force the server time diff to a large value.
                   NSTimeInterval serverTimeDiff = 10000.0;
                   [TestHelpers setServerTimeDiff:self->psiCash to:serverTimeDiff];

                   NSArray<PsiCashPurchase*> *purchases = [self->psiCash purchases];
                   XCTAssertEqual(purchases.count, 2);

                   for (PsiCashPurchase *purchase in purchases) {
                       test(serverTimeDiff, purchase);
                   }

                   //
                   // validPurchases accessor
                   //

                   // Make negative so that our purchases are _not_ already expired.
                   serverTimeDiff = -10000.0;
                   [TestHelpers setServerTimeDiff:self->psiCash to:serverTimeDiff];

                   purchases = [self->psiCash validPurchases];
                   XCTAssertGreaterThanOrEqual(purchases.count, 1);

                   for (PsiCashPurchase *purchase in purchases) {
                       test(serverTimeDiff, purchase);
                   }

                   //
                   // nextExpiringPurchase accessor
                   //

                   PsiCashPurchase *nextExpiring = [self->psiCash nextExpiringPurchase];
                   XCTAssertNotNil(nextExpiring);

                   test(serverTimeDiff, nextExpiring);

                   //
                   // expirePurchases accessor
                   //

                   // Make positive so that our purchases _are_ already expired.
                   serverTimeDiff = 10000.0;
                   [TestHelpers setServerTimeDiff:self->psiCash to:serverTimeDiff];

                   purchases = [self->psiCash expirePurchases];
                   XCTAssertGreaterThanOrEqual(purchases.count, 1);

                   for (PsiCashPurchase *purchase in purchases) {
                       test(serverTimeDiff, purchase);
                   }

                   [exp fulfill];
               }];
          }];
     }];

    [self waitForExpectationsWithTimeout:100 handler:nil];
}

- (void)testModifyLandingPage {
    NSString *result, *expected;
    NSError *err;

    // Remove all tokens.
    [TestHelpers clearUserInfo:self->psiCash];
    err = [self->psiCash modifyLandingPage:@"https://example.com"
                               modifiedURL:&result];
    XCTAssertNil(err);
    expected = @"https://example.com#psicash=%7B%22metadata%22%3A%7B%7D%2C%22tokens%22%3Anull%2C%22v%22%3A2%7D";
    XCTAssertEqualObjects(result, expected);

    // Set tokens but not an earner token.
    [[TestHelpers userInfo:self->psiCash] setAuthTokens:@{@"faketype1": @"abcd", @"faketype2": @"1234"}
                                              isAccount:NO];
    err = [self->psiCash modifyLandingPage:@"https://example.com"
                               modifiedURL:&result];
    XCTAssertNil(err);
    expected = @"https://example.com#psicash=%7B%22metadata%22%3A%7B%7D%2C%22tokens%22%3Anull%2C%22v%22%3A2%7D";
    XCTAssertEqualObjects(result, expected);

    // Set tokens with an earner token, for use in following tests.
    [[TestHelpers userInfo:self->psiCash] setAuthTokens:@{EARNER_TOKEN_TYPE: @"mytoken", @"faketype1": @"abcd", @"faketype2": @"1234"}
                                              isAccount:NO];
    // Set metadata
    [self->psiCash setRequestMetadataAtKey:@"client_region" withValue:@"myclientregion"];
    [self->psiCash setRequestMetadataAtKey:@"client_version" withValue:@"myclientversion"];
    [self->psiCash setRequestMetadataAtKey:@"sponsor_id" withValue:@"mysponsorid"];
    [self->psiCash setRequestMetadataAtKey:@"propagation_channel_id" withValue:@"mypropchannelid"];

    // Bad URL
    err = [self->psiCash modifyLandingPage:@"http://汉"
                               modifiedURL:&result];
    XCTAssertNotNil(err);

    // Has no query or fragment
    err = [self->psiCash modifyLandingPage:@"https://example.com"
                               modifiedURL:&result];
    XCTAssertNil(err);
    expected = @"https://example.com#psicash=%7B%22metadata%22%3A%7B%22client%5Fregion%22%3A%22myclientregion%22%2C%22client%5Fversion%22%3A%22myclientversion%22%2C%22propagation%5Fchannel%5Fid%22%3A%22mypropchannelid%22%2C%22sponsor%5Fid%22%3A%22mysponsorid%22%7D%2C%22tokens%22%3A%22mytoken%22%2C%22v%22%3A2%7D";
    XCTAssertEqualObjects(result, expected);

    // Has fragment
    err = [self->psiCash modifyLandingPage:@"https://example.com#anchor"
                               modifiedURL:&result];
    XCTAssertNil(err);
    expected = @"https://example.com?psicash=%7B%22metadata%22:%7B%22client_region%22:%22myclientregion%22,%22client_version%22:%22myclientversion%22,%22propagation_channel_id%22:%22mypropchannelid%22,%22sponsor_id%22:%22mysponsorid%22%7D,%22tokens%22:%22mytoken%22,%22v%22:2%7D#anchor";
    XCTAssertEqualObjects(result, expected);

    // Has query
    err = [self->psiCash modifyLandingPage:@"https://example.com?a=b"
                               modifiedURL:&result];
    XCTAssertNil(err);
    expected = @"https://example.com?a=b#psicash=%7B%22metadata%22%3A%7B%22client%5Fregion%22%3A%22myclientregion%22%2C%22client%5Fversion%22%3A%22myclientversion%22%2C%22propagation%5Fchannel%5Fid%22%3A%22mypropchannelid%22%2C%22sponsor%5Fid%22%3A%22mysponsorid%22%7D%2C%22tokens%22%3A%22mytoken%22%2C%22v%22%3A2%7D";
    XCTAssertEqualObjects(result, expected);

    // Has query and fragment
    err = [self->psiCash modifyLandingPage:@"https://example.com?a=b#anchor"
                               modifiedURL:&result];
    XCTAssertNil(err);
    expected = @"https://example.com?a=b&psicash=%7B%22metadata%22:%7B%22client_region%22:%22myclientregion%22,%22client_version%22:%22myclientversion%22,%22propagation_channel_id%22:%22mypropchannelid%22,%22sponsor_id%22:%22mysponsorid%22%7D,%22tokens%22:%22mytoken%22,%22v%22:2%7D#anchor";
    XCTAssertEqualObjects(result, expected);

    // Has query and fragment; query has trailing &
    err = [self->psiCash modifyLandingPage:@"https://example.com?a=b&#anchor"
                               modifiedURL:&result];
    XCTAssertNil(err);
    expected = @"https://example.com?a=b&&psicash=%7B%22metadata%22:%7B%22client_region%22:%22myclientregion%22,%22client_version%22:%22myclientversion%22,%22propagation_channel_id%22:%22mypropchannelid%22,%22sponsor_id%22:%22mysponsorid%22%7D,%22tokens%22:%22mytoken%22,%22v%22:2%7D#anchor";
    XCTAssertEqualObjects(result, expected);

    // Some path variations
    err = [self->psiCash modifyLandingPage:@"http://example.com/"
                               modifiedURL:&result];
    XCTAssertNil(err);
    expected = @"http://example.com/#psicash=%7B%22metadata%22%3A%7B%22client%5Fregion%22%3A%22myclientregion%22%2C%22client%5Fversion%22%3A%22myclientversion%22%2C%22propagation%5Fchannel%5Fid%22%3A%22mypropchannelid%22%2C%22sponsor%5Fid%22%3A%22mysponsorid%22%7D%2C%22tokens%22%3A%22mytoken%22%2C%22v%22%3A2%7D";
    XCTAssertEqualObjects(result, expected);

    err = [self->psiCash modifyLandingPage:@"http://sub.example.com/"
                               modifiedURL:&result];
    XCTAssertNil(err);
    expected = @"http://sub.example.com/#psicash=%7B%22metadata%22%3A%7B%22client%5Fregion%22%3A%22myclientregion%22%2C%22client%5Fversion%22%3A%22myclientversion%22%2C%22propagation%5Fchannel%5Fid%22%3A%22mypropchannelid%22%2C%22sponsor%5Fid%22%3A%22mysponsorid%22%7D%2C%22tokens%22%3A%22mytoken%22%2C%22v%22%3A2%7D";
    XCTAssertEqualObjects(result, expected);

    err = [self->psiCash modifyLandingPage:@"http://example.com/x/y/z.html"
                               modifiedURL:&result];
    XCTAssertNil(err);
    expected = @"http://example.com/x/y/z.html#psicash=%7B%22metadata%22%3A%7B%22client%5Fregion%22%3A%22myclientregion%22%2C%22client%5Fversion%22%3A%22myclientversion%22%2C%22propagation%5Fchannel%5Fid%22%3A%22mypropchannelid%22%2C%22sponsor%5Fid%22%3A%22mysponsorid%22%7D%2C%22tokens%22%3A%22mytoken%22%2C%22v%22%3A2%7D";
    XCTAssertEqualObjects(result, expected);

    err = [self->psiCash modifyLandingPage:@"http://sub.example.com/x/y/z.html?a=b#anchor"
                               modifiedURL:&result];
    XCTAssertNil(err);
    expected = @"http://sub.example.com/x/y/z.html?a=b&psicash=%7B%22metadata%22:%7B%22client_region%22:%22myclientregion%22,%22client_version%22:%22myclientversion%22,%22propagation_channel_id%22:%22mypropchannelid%22,%22sponsor_id%22:%22mysponsorid%22%7D,%22tokens%22:%22mytoken%22,%22v%22:2%7D#anchor";
    XCTAssertEqualObjects(result, expected);
}

- (void)testGetDiagnosticInfo {
    XCTestExpectation *exp = [self expectationWithDescription:@"Success: getDiagnosticInfo"];

    // Start by ensuring we have sufficient balance
    [TestHelpers makeRewardRequests:self->psiCash
                             amount:2
                         completion:^(BOOL success)
     {
         XCTAssertTrue(success);

        [self->psiCash refreshState:@[@"speed-boost"] withCompletion:^(PsiCashStatus status,
                                                                       NSError * _Nullable error)
         {
             XCTAssertNil(error);
             XCTAssertEqual(status, PsiCashStatus_Success);


             [self->psiCash newExpiringPurchaseTransactionForClass:@TEST_DEBIT_TRANSACTION_CLASS
                                                 withDistinguisher:@TEST_ONE_TRILLION_ONE_MICROSECOND_DISTINGUISHER
                                                 withExpectedPrice:@ONE_TRILLION
                                                    withCompletion:^(PsiCashStatus status,
                                                                     PsiCashPurchase*_Nullable purchase,
                                                                     NSError*_Nullable error)
              {
                  XCTAssertNil(error);
                  XCTAssertEqual(status, PsiCashStatus_Success);

                  NSDictionary *info = [self->psiCash getDiagnosticInfo];

                  // JSON serialize, partly to ensure it doesn't crash.
                  NSData *jsonData = [NSJSONSerialization dataWithJSONObject:info
                                                                     options:NSJSONWritingPrettyPrinted
                                                                       error:&error];
                  XCTAssertNil(error);
                  NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
                  //NSLog(@"%@", jsonString);
                  XCTAssertGreaterThan(jsonString.length, 0);

                  [exp fulfill];
              }];
         }];
    }];


    [self waitForExpectationsWithTimeout:100 handler:nil];
}

- (void)testGetDiagnosticInfoNoState {
    [TestHelpers clearUserInfo:self->psiCash];

    NSDictionary *info = [self->psiCash getDiagnosticInfo];

    // JSON serialize, partly to ensure it doesn't crash.
    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:info
                                                       options:NSJSONWritingPrettyPrinted
                                                         error:&error];
    XCTAssertNil(error);
    NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    //NSLog(@"%@", jsonString);
    XCTAssertGreaterThan(jsonString.length, 0);
}

@end
