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


@interface AccessorsTests : XCTestCase

@property PsiCash *psiCash;

@end

@implementation AccessorsTests

@synthesize psiCash;

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.

    psiCash = [[PsiCash alloc] init];
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

- (void)testServerTimeAdjustment {
    NSDate *now = [NSDate date];

    // Positive server time diff means the server clock is ahead.
    [TestHelpers userInfo:self->psiCash].serverTimeDiff = 1000.0;
    NSDate *adjusted = [psiCash adjustForServerTimeDiff:now];

    // If the server thinks the exiry is 09:00, but the server is 1000 secs ahead
    // of the client, then the client needs to consider the expiry to be 09:00 - 1000secs.
    NSTimeInterval adjustment = [adjusted timeIntervalSinceDate:now];
    XCTAssertEqual(adjustment, -1000.0);

    // Negative server time diff means the server clock is behind.
    [TestHelpers userInfo:self->psiCash].serverTimeDiff = -1000.0;
    adjusted = [psiCash adjustForServerTimeDiff:now];
    adjustment = [adjusted timeIntervalSinceDate:now];
    XCTAssertEqual(adjustment, 1000.0);
}

- (void)testGetPurchases {
    XCTestExpectation *exp = [self expectationWithDescription:@"Success: getPurchases"];

    dispatch_group_t group = dispatch_group_create();

    dispatch_group_enter(group);
    dispatch_group_async(group,dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^ {
        // Start by ensuring we have sufficient balance
        [TestHelpers make1TRewardRequest:self->psiCash
                              completion:^(BOOL success)
         {
             XCTAssertTrue(success);
             dispatch_group_leave(group);
         }];
    });

    dispatch_group_enter(group);
    dispatch_group_async(group,dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^ {
        // Start by ensuring we have sufficient balance
        [TestHelpers make1TRewardRequest:self->psiCash
                              completion:^(BOOL success)
         {
             XCTAssertTrue(success);
             dispatch_group_leave(group);
         }];
    });

    dispatch_group_notify(group,dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^ {

        // Clear out any pre-existing expired purchases.
        [self->psiCash expirePurchases];


        [self->psiCash newExpiringPurchaseTransactionForClass:@TEST_DEBIT_TRANSACTION_CLASS
                                            withDistinguisher:@TEST_ONE_TRILLION_ONE_MICROSECOND_DISTINGUISHER
                                            withExpectedPrice:@ONE_TRILLION
                                               withCompletion:^(PsiCashStatus status,
                                                                NSNumber*_Nullable price,
                                                                NSNumber*_Nullable balance,
                                                                NSDate*_Nullable expiry,
                                                                NSString*_Nullable transactionID1,
                                                                NSString*_Nullable authorization,
                                                                NSError*_Nullable error)
         {
             XCTAssertNil(error);
             XCTAssertEqual(status, PsiCashStatus_Success);

             NSArray *purchases = self->psiCash.purchases;
             XCTAssert([purchases count] == 1);
             for (PsiCashPurchase *p in purchases) {
                 XCTAssertEqualObjects(p.ID, transactionID1);
             }

             [self->psiCash newExpiringPurchaseTransactionForClass:@TEST_DEBIT_TRANSACTION_CLASS
                                                 withDistinguisher:@TEST_ONE_TRILLION_ONE_MICROSECOND_DISTINGUISHER
                                                 withExpectedPrice:@ONE_TRILLION
                                                    withCompletion:^(PsiCashStatus status,
                                                                     NSNumber*_Nullable price,
                                                                     NSNumber*_Nullable balance,
                                                                     NSDate*_Nullable expiry,
                                                                     NSString*_Nullable transactionID2,
                                                                     NSString*_Nullable authorization,
                                                                     NSError*_Nullable error)
              {
                  XCTAssertNil(error);
                  XCTAssertEqual(status, PsiCashStatus_Success);

                  NSArray *purchases = self->psiCash.purchases;
                  XCTAssert([purchases count] == 2);
                  for (PsiCashPurchase *p in purchases) {
                      XCTAssert([p.ID isEqualToString:transactionID1] || [p.ID isEqualToString:transactionID2]);
                  }

                  [exp fulfill];
              }];
         }];
    });


    [self waitForExpectationsWithTimeout:100 handler:nil];
}

- (void)testNextExpiringPurchase1 {
    XCTestExpectation *exp = [self expectationWithDescription:@"Success: nextExpiringPurchase; long then short"];

    dispatch_group_t group = dispatch_group_create();

    dispatch_group_enter(group);
    dispatch_group_async(group,dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^ {
        // Start by ensuring we have sufficient balance
        [TestHelpers make1TRewardRequest:self->psiCash
                              completion:^(BOOL success)
         {
             XCTAssertTrue(success);
             dispatch_group_leave(group);
         }];
    });

    dispatch_group_enter(group);
    dispatch_group_async(group,dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^ {
            // Start by ensuring we have sufficient balance
            [TestHelpers make1TRewardRequest:self->psiCash
                                  completion:^(BOOL success)
             {
                 XCTAssertTrue(success);
                 dispatch_group_leave(group);
             }];
    });

    dispatch_group_notify(group,dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^ {

        // Clear out any pre-existing expired purchases.
        [self->psiCash expirePurchases];

        [self->psiCash newExpiringPurchaseTransactionForClass:@TEST_DEBIT_TRANSACTION_CLASS
                                            withDistinguisher:@TEST_ONE_TRILLION_ONE_SECOND_DISTINGUISHER
                                            withExpectedPrice:@ONE_TRILLION
                                               withCompletion:^(PsiCashStatus status,
                                                                NSNumber*_Nullable price,
                                                                NSNumber*_Nullable balance,
                                                                NSDate*_Nullable longExpiry,
                                                                NSString*_Nullable longTransactionID,
                                                                NSString*_Nullable authorization,
                                                                NSError*_Nullable error)
         {
             XCTAssertNil(error);
             XCTAssertEqual(status, PsiCashStatus_Success);

             [self->psiCash newExpiringPurchaseTransactionForClass:@TEST_DEBIT_TRANSACTION_CLASS
                                                 withDistinguisher:@TEST_ONE_TRILLION_ONE_MICROSECOND_DISTINGUISHER
                                                 withExpectedPrice:@ONE_TRILLION
                                                    withCompletion:^(PsiCashStatus status,
                                                                     NSNumber*_Nullable price,
                                                                     NSNumber*_Nullable balance,
                                                                     NSDate*_Nullable shortExpiry,
                                                                     NSString*_Nullable shortTransactionID,
                                                                     NSString*_Nullable authorization,
                                                                     NSError*_Nullable error)
              {
                  XCTAssertNil(error);
                  XCTAssertEqual(status, PsiCashStatus_Success);

                  PsiCashPurchase *p;
                  NSDate *e;
                  XCTAssertTrue([self->psiCash nextExpiringPurchase:&p expiry:&e]);
                  XCTAssertNotNil(p);
                  XCTAssertNotNil(e);
                  XCTAssert([p.ID isEqualToString:shortTransactionID]);
                  XCTAssert([e isEqualToDate:shortExpiry]);

                  [exp fulfill];
              }];
         }];
    });


    [self waitForExpectationsWithTimeout:100 handler:nil];
}

- (void)testNextExpiringPurchase2 {
    XCTestExpectation *exp = [self expectationWithDescription:@"Success: nextExpiringPurchase; short then long"];

    dispatch_group_t group = dispatch_group_create();

    dispatch_group_enter(group);
    dispatch_group_async(group,dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^ {
        // Start by ensuring we have sufficient balance
        [TestHelpers make1TRewardRequest:self->psiCash
                              completion:^(BOOL success)
         {
             XCTAssertTrue(success);
             dispatch_group_leave(group);
         }];
    });

    dispatch_group_enter(group);
    dispatch_group_async(group,dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^ {
        // Start by ensuring we have sufficient balance
        [TestHelpers make1TRewardRequest:self->psiCash
                              completion:^(BOOL success)
         {
             XCTAssertTrue(success);
             dispatch_group_leave(group);
         }];
    });

    dispatch_group_notify(group,dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^ {

        // Clear out any pre-existing purchases.
        [TestHelpers userInfo:self->psiCash].purchases = nil;

        [self->psiCash newExpiringPurchaseTransactionForClass:@TEST_DEBIT_TRANSACTION_CLASS
                                            withDistinguisher:@TEST_ONE_TRILLION_ONE_MICROSECOND_DISTINGUISHER
                                            withExpectedPrice:@ONE_TRILLION
                                               withCompletion:^(PsiCashStatus status,
                                                                NSNumber*_Nullable price,
                                                                NSNumber*_Nullable balance,
                                                                NSDate*_Nullable shortExpiry,
                                                                NSString*_Nullable shortTransactionID,
                                                                NSString*_Nullable authorization,
                                                                NSError*_Nullable error)
         {
             XCTAssertNil(error);
             XCTAssertEqual(status, PsiCashStatus_Success);

             [self->psiCash newExpiringPurchaseTransactionForClass:@TEST_DEBIT_TRANSACTION_CLASS
                                                 withDistinguisher:@TEST_ONE_TRILLION_ONE_SECOND_DISTINGUISHER
                                                 withExpectedPrice:@ONE_TRILLION
                                                    withCompletion:^(PsiCashStatus status,
                                                                     NSNumber*_Nullable price,
                                                                     NSNumber*_Nullable balance,
                                                                     NSDate*_Nullable longExpiry,
                                                                     NSString*_Nullable longTransactionID,
                                                                     NSString*_Nullable authorization,
                                                                     NSError*_Nullable error)
              {
                  XCTAssertNil(error);
                  XCTAssertEqual(status, PsiCashStatus_Success);

                  PsiCashPurchase *p;
                  NSDate *e;
                  XCTAssertTrue([self->psiCash nextExpiringPurchase:&p expiry:&e]);
                  XCTAssertNotNil(p);
                  XCTAssertNotNil(e);
                  XCTAssert([p.ID isEqualToString:shortTransactionID]);
                  // We can't compare shortExpiry to e because the serverTimeDiff changed with the last request.
                  //XCTAssert([e isEqualToDate:shortExpiry]);
                  XCTAssert([e isEqualToDate:[self->psiCash adjustForServerTimeDiff:p.expiry]]);

                  [exp fulfill];
              }];
         }];
    });


    [self waitForExpectationsWithTimeout:100 handler:nil];
}

- (void)testExpirePurchases {
    XCTestExpectation *exp = [self expectationWithDescription:@"Success: getPurchases"];
    
    dispatch_group_t group = dispatch_group_create();
    
    dispatch_group_enter(group);
    dispatch_group_async(group,dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^ {
        // Start by ensuring we have sufficient balance
        [TestHelpers make1TRewardRequest:self->psiCash
                              completion:^(BOOL success)
         {
             XCTAssertTrue(success);
             dispatch_group_leave(group);
         }];
    });
    
    dispatch_group_enter(group);
    dispatch_group_async(group,dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^ {
        // Start by ensuring we have sufficient balance
        [TestHelpers make1TRewardRequest:self->psiCash
                              completion:^(BOOL success)
         {
             XCTAssertTrue(success);
             dispatch_group_leave(group);
         }];
    });
    
    dispatch_group_notify(group,dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^ {
        
        // Clear out any pre-existing expired purchases.
        [self->psiCash expirePurchases];
        
        [self->psiCash newExpiringPurchaseTransactionForClass:@TEST_DEBIT_TRANSACTION_CLASS
                                            withDistinguisher:@TEST_ONE_TRILLION_ONE_MICROSECOND_DISTINGUISHER
                                            withExpectedPrice:@ONE_TRILLION
                                               withCompletion:^(PsiCashStatus status,
                                                                NSNumber*_Nullable price,
                                                                NSNumber*_Nullable balance,
                                                                NSDate*_Nullable expiry,
                                                                NSString*_Nullable transactionID1,
                                                                NSString*_Nullable authorization,
                                                                NSError*_Nullable error)
         {
             XCTAssertNil(error);
             XCTAssertEqual(status, PsiCashStatus_Success);
             
             [self->psiCash newExpiringPurchaseTransactionForClass:@TEST_DEBIT_TRANSACTION_CLASS
                                                 withDistinguisher:@TEST_ONE_TRILLION_TEN_SECOND_DISTINGUISHER
                                                 withExpectedPrice:@ONE_TRILLION
                                                    withCompletion:^(PsiCashStatus status,
                                                                     NSNumber*_Nullable price,
                                                                     NSNumber*_Nullable balance,
                                                                     NSDate*_Nullable expiry,
                                                                     NSString*_Nullable transactionID2,
                                                                     NSString*_Nullable authorization,
                                                                     NSError*_Nullable error)
              {
                  XCTAssertNil(error);
                  XCTAssertEqual(status, PsiCashStatus_Success);
                  
                  NSArray *expiredPurchases = [self->psiCash expirePurchases];
                  XCTAssert([expiredPurchases count] == 1);
                  for (PsiCashPurchase *p in expiredPurchases) {
                      XCTAssert([p.ID isEqualToString:transactionID1]);
                  }
                  
                  // Let the longer purchase expire
                  [NSThread sleepForTimeInterval:11.0];
                  
                  expiredPurchases = [self->psiCash expirePurchases];
                  XCTAssert([expiredPurchases count] == 1);
                  for (PsiCashPurchase *p in expiredPurchases) {
                      XCTAssert([p.ID isEqualToString:transactionID2]);
                  }
                  
                  [exp fulfill];
              }];
         }];
    });


    [self waitForExpectationsWithTimeout:100 handler:nil];
}

@end
