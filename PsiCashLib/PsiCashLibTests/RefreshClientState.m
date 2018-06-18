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
//  RefreshClientState.m
//  PsiCashLibTests
//

#import <XCTest/XCTest.h>
#import "TestHelpers.h"


@interface RefreshClientStateTests : XCTestCase

@property PsiCash *psiCash;

@end

@implementation RefreshClientStateTests {
    NSNumber *mutatorsEnabled;
}

@synthesize psiCash;

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.

    psiCash = [TestHelpers newPsiCash];

    if (mutatorsEnabled == nil) {
        XCTestExpectation *expMutatorsEnabled = [self expectationWithDescription:@"Check if mutators enabled"];
        [TestHelpers checkMutatorSupport:psiCash completion:^(BOOL supported) {
            self->mutatorsEnabled = [NSNumber numberWithBool:supported];
            [expMutatorsEnabled fulfill];
        }];
        [self waitForExpectationsWithTimeout:100 handler:nil];
    }
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testNewTracker {
    XCTestExpectation *exp = [self expectationWithDescription:@"Success: new tracker"];

    // Blow away any existing tokens.
    [TestHelpers clearUserInfo:psiCash];

    NSArray *purchaseClasses =  @[@"speed-boost"];

    [self->psiCash refreshState:purchaseClasses
                 withCompletion:^(PsiCashStatus status,
                                  NSArray * _Nullable validTokenTypes,
                                  BOOL isAccount,
                                  NSNumber * _Nullable balance,
                                  NSArray * _Nullable purchasePrices,
                                  NSError * _Nullable error)
     {
         XCTAssertNil(error);
         XCTAssertEqual(status, PsiCashStatus_Success);

         XCTAssertFalse(isAccount);

         XCTAssertNotNil(validTokenTypes);
         XCTAssertGreaterThanOrEqual(validTokenTypes.count, 3);

         XCTAssertNotNil(balance);
         XCTAssertEqual(balance.integerValue, 0);

         XCTAssertNotNil(purchasePrices);
         XCTAssertGreaterThanOrEqual(purchasePrices.count, 2);

         XCTAssertGreaterThan([[self->psiCash validTokenTypes] count], 0);
         XCTAssertFalse([self->psiCash isAccount]);
         XCTAssertEqual([self->psiCash balance], balance);
         XCTAssert([[self->psiCash purchasePrices] isEqualToArray:purchasePrices]);

         [exp fulfill];
     }];

    [self waitForExpectationsWithTimeout:100 handler:nil];
}

- (void)testExistingUser {
    XCTestExpectation *exp = [self expectationWithDescription:@"Success: existing user"];

    NSArray *purchaseClasses =  @[@"speed-boost"];

    // Make the request twice, to ensure the tokens exist for the second call.

    [self->psiCash refreshState:purchaseClasses
                 withCompletion:^(PsiCashStatus status,
                                  NSArray * _Nullable validTokenTypes,
                                  BOOL isAccount,
                                  NSNumber * _Nullable balance,
                                  NSArray * _Nullable purchasePrices,
                                  NSError * _Nullable error)
     {
         XCTAssertNil(error);
         XCTAssertEqual(status, PsiCashStatus_Success);

         XCTAssertFalse(isAccount);

         XCTAssertNotNil(validTokenTypes);
         XCTAssertGreaterThanOrEqual(validTokenTypes.count, 3);

         XCTAssertNotNil(balance);
         XCTAssertGreaterThanOrEqual(balance.integerValue, 0);

         XCTAssertNotNil(purchasePrices);
         XCTAssertGreaterThanOrEqual(purchasePrices.count, 2);

         [self->psiCash refreshState:purchaseClasses
                      withCompletion:^(PsiCashStatus status,
                                       NSArray * _Nullable validTokenTypes,
                                       BOOL isAccount,
                                       NSNumber * _Nullable balance,
                                       NSArray * _Nullable purchasePrices,
                                       NSError * _Nullable error)
          {
              XCTAssertNil(error);
              XCTAssertEqual(status, PsiCashStatus_Success);

              XCTAssertFalse(isAccount);

              XCTAssertNotNil(validTokenTypes);
              XCTAssertGreaterThanOrEqual(validTokenTypes.count, 3);

              XCTAssertNotNil(balance);
              XCTAssertGreaterThanOrEqual(balance.integerValue, 0);

              XCTAssertNotNil(purchasePrices);
              XCTAssertGreaterThanOrEqual(purchasePrices.count, 2);

              XCTAssertGreaterThan([[self->psiCash validTokenTypes] count], 0);
              XCTAssertEqual([self->psiCash balance], balance);
              XCTAssert([[self->psiCash purchasePrices] isEqualToArray:purchasePrices]);

              [exp fulfill];
          }];
     }];

    [self waitForExpectationsWithTimeout:100 handler:nil];
}

- (void)testNoPurchases {
    XCTestExpectation *exp = [self expectationWithDescription:@"Success: no purchase classes"];

    NSArray *purchaseClasses =  @[];

    [self->psiCash refreshState:purchaseClasses
                 withCompletion:^(PsiCashStatus status,
                                  NSArray * _Nullable validTokenTypes,
                                  BOOL isAccount,
                                  NSNumber * _Nullable balance,
                                  NSArray * _Nullable purchasePrices,
                                  NSError * _Nullable error)
     {
         XCTAssertNil(error);
         XCTAssertEqual(status, PsiCashStatus_Success);

         XCTAssertFalse(isAccount);

         XCTAssertNotNil(validTokenTypes);
         XCTAssertGreaterThanOrEqual(validTokenTypes.count, 3);

         XCTAssertNotNil(balance);
         XCTAssertGreaterThanOrEqual(balance.integerValue, 0);

         XCTAssertNotNil(purchasePrices);
         XCTAssertEqual(purchasePrices.count, 0);

         [exp fulfill];
     }];

    [self waitForExpectationsWithTimeout:100 handler:nil];
}

- (void)testMultiplePurchaseClasses {
    XCTestExpectation *exp = [self expectationWithDescription:@"Success: multiple purchase classes"];

    NSArray *purchaseClasses =  @[@"speed-boost", @TEST_DEBIT_TRANSACTION_CLASS];

    [self->psiCash refreshState:purchaseClasses
                 withCompletion:^(PsiCashStatus status,
                                  NSArray * _Nullable validTokenTypes,
                                  BOOL isAccount,
                                  NSNumber * _Nullable balance,
                                  NSArray * _Nullable purchasePrices,
                                  NSError * _Nullable error)
     {
         XCTAssertNil(error);
         XCTAssertEqual(status, PsiCashStatus_Success);

         XCTAssertFalse(isAccount);

         XCTAssertNotNil(validTokenTypes);
         XCTAssertGreaterThanOrEqual(validTokenTypes.count, 3);

         XCTAssertNotNil(balance);
         XCTAssertGreaterThanOrEqual(balance.integerValue, 0);

         XCTAssertNotNil(purchasePrices);
         XCTAssertGreaterThanOrEqual(purchasePrices.count, 3);

         [exp fulfill];
     }];

    [self waitForExpectationsWithTimeout:100 handler:nil];
}

- (void)testBalanceIncrease {
    XCTestExpectation *exp = [self expectationWithDescription:@"Success: balance increase"];

    NSArray *purchaseClasses =  @[@"speed-boost"];

    [self->psiCash refreshState:purchaseClasses
                 withCompletion:^(PsiCashStatus status,
                                  NSArray * _Nullable validTokenTypes,
                                  BOOL isAccount,
                                  NSNumber * _Nullable originalBalance,
                                  NSArray * _Nullable purchasePrices,
                                  NSError * _Nullable error)
     {
         XCTAssertNil(error);
         XCTAssertEqual(status, PsiCashStatus_Success);

         XCTAssertFalse(isAccount);

         XCTAssertNotNil(validTokenTypes);
         XCTAssertGreaterThanOrEqual(validTokenTypes.count, 3);

         XCTAssertNotNil(originalBalance);
         XCTAssertGreaterThanOrEqual(originalBalance.integerValue, 0);

         XCTAssertNotNil(purchasePrices);
         XCTAssertGreaterThanOrEqual(purchasePrices.count, 2);

         // Make a reward request so that we can test an increased balance.
         [TestHelpers makeRewardRequests:psiCash
                                  amount:1
                              completion:^(BOOL success)
          {
              XCTAssert(success);

              // Refresh state again to check balance.
              [self->psiCash refreshState:purchaseClasses
                           withCompletion:^(PsiCashStatus status,
                                            NSArray * _Nullable validTokenTypes,
                                            BOOL isAccount,
                                            NSNumber * _Nullable newBalance,
                                            NSArray * _Nullable purchasePrices,
                                            NSError * _Nullable error)
               {
                   XCTAssertNil(error);
                   XCTAssertEqual(status, PsiCashStatus_Success);

                   // Is the balance bigger?
                   XCTAssertEqual(newBalance.integerValue,
                                  originalBalance.integerValue + ONE_TRILLION);

                   [exp fulfill];
               }];
          }];
     }];

    [self waitForExpectationsWithTimeout:100 handler:nil];
}

- (void)testForceIsAccountBadTokens {
    XCTestExpectation *exp = [self expectationWithDescription:@"Error: force is-account"];

    // We're setting "isAccount" with tracker tokens. This is not okay and shouldn't happen.
    [TestHelpers setIsAccount:psiCash];

    NSArray *purchaseClasses =  @[@"speed-boost"];

    [self->psiCash refreshState:purchaseClasses
                 withCompletion:^(PsiCashStatus status,
                                  NSArray * _Nullable validTokenTypes,
                                  BOOL isAccount,
                                  NSNumber * _Nullable balance,
                                  NSArray * _Nullable purchasePrices,
                                  NSError * _Nullable error)
     {
         XCTAssertNotNil(error);
         XCTAssertEqual(status, PsiCashStatus_Invalid);

         [TestHelpers clearUserInfo:self->psiCash];

         [exp fulfill];
     }];

    [self waitForExpectationsWithTimeout:100 handler:nil];
}

- (void)testIsAccountNoTokens {
    XCTestExpectation *exp = [self expectationWithDescription:@"Success: account with no tokens"];

    // Blow away any existing tokens.
    [TestHelpers clearUserInfo:self->psiCash];
    // Force user state to is-account
    [TestHelpers setIsAccount:self->psiCash];

    NSArray *purchaseClasses =  @[@"speed-boost"];

    [self->psiCash refreshState:purchaseClasses
                 withCompletion:^(PsiCashStatus status,
                                  NSArray * _Nullable validTokenTypes,
                                  BOOL isAccount,
                                  NSNumber * _Nullable balance,
                                  NSArray * _Nullable purchasePrices,
                                  NSError * _Nullable error)
     {
         XCTAssertNil(error);
         XCTAssertEqual(status, PsiCashStatus_Success);

         XCTAssertTrue(isAccount);

         XCTAssertNotNil(validTokenTypes);
         XCTAssertEqual(validTokenTypes.count, 0);

         XCTAssertNil(balance);

         XCTAssertNil(purchasePrices);

         [TestHelpers clearUserInfo:self->psiCash];

         [exp fulfill];
     }];

    [self waitForExpectationsWithTimeout:100 handler:nil];
}

- (void)testIsAccountInvalidTokens {
    if (![self->mutatorsEnabled boolValue]) {
        return;
    }

    XCTestExpectation *exp = [self expectationWithDescription:@"Successs: is-account with tokens but none valid"];

    NSArray *purchaseClasses =  @[];

    // Blow away any existing tokens.
    [TestHelpers clearUserInfo:self->psiCash];

    // First get some valid tokens.
    [self->psiCash refreshState:purchaseClasses
                 withCompletion:^(PsiCashStatus status,
                                  NSArray * _Nullable validTokenTypes,
                                  BOOL isAccount,
                                  NSNumber * _Nullable balance,
                                  NSArray * _Nullable purchasePrices,
                                  NSError * _Nullable error)
     {
         XCTAssertNil(error);
         XCTAssertEqual(status, PsiCashStatus_Success);

         // We're setting "isAccount" with tracker tokens. This is not okay, but we're going to make them invalid anyway.
         [TestHelpers setIsAccount:self->psiCash];

         // Add a request mutator that will cause our tokens to seem invalid.
         [TestHelpers setRequestMutators:self->psiCash mutators:@[@"InvalidTokens"]];

         [self->psiCash refreshState:purchaseClasses
                      withCompletion:^(PsiCashStatus status,
                                       NSArray * _Nullable validTokenTypes,
                                       BOOL isAccount,
                                       NSNumber * _Nullable balance,
                                       NSArray * _Nullable purchasePrices,
                                       NSError * _Nullable error)
          {
              XCTAssertNil(error);
              XCTAssertEqual(status, PsiCashStatus_Success);

              XCTAssertTrue(isAccount);

              XCTAssertNotNil(validTokenTypes);
              XCTAssertEqual(validTokenTypes.count, 0);

              XCTAssertNil(balance);

              XCTAssertNil(purchasePrices);

              [TestHelpers clearUserInfo:self->psiCash];

              [exp fulfill];
          }];
     }];

    [self waitForExpectationsWithTimeout:100 handler:nil];
}

- (void)testNewTrackerWithInvalidTokens {
    if (![self->mutatorsEnabled boolValue]) {
        return;
    }

    XCTestExpectation *exp = [self expectationWithDescription:@"Success: new tracker with initially invalid tokens"];

    NSArray *purchaseClasses =  @[]; // not relevant to this test

    // Blow away any existing tokens.
    [TestHelpers clearUserInfo:self->psiCash];

    // Do an initial refresh to get Tracker tokens.
    [self->psiCash refreshState:purchaseClasses
                 withCompletion:^(PsiCashStatus status,
                                  NSArray * _Nullable validTokenTypes,
                                  BOOL isAccount,
                                  NSNumber * _Nullable balance,
                                  NSArray * _Nullable purchasePrices,
                                  NSError * _Nullable error)
     {
         XCTAssertNil(error);
         XCTAssertEqual(status, PsiCashStatus_Success);

         NSDictionary *preAuthTokens = [TestHelpers getAuthTokens:self->psiCash];
         XCTAssertGreaterThan(preAuthTokens.count, 0);

         // Add a request mutator that will cause our tokens to seem invalid.
         [TestHelpers setRequestMutators:self->psiCash mutators:@[@"InvalidTokens"]];

         // Make the request again. Should get us new tokens.
         [self->psiCash refreshState:purchaseClasses
                      withCompletion:^(PsiCashStatus status,
                                       NSArray * _Nullable validTokenTypes,
                                       BOOL isAccount,
                                       NSNumber * _Nullable balance,
                                       NSArray * _Nullable purchasePrices,
                                       NSError * _Nullable error)
          {
              XCTAssertNil(error);
              XCTAssertEqual(status, PsiCashStatus_Success);

              NSDictionary *postAuthTokens = [TestHelpers getAuthTokens:self->psiCash];
              XCTAssertGreaterThan(preAuthTokens.count, 0);

              XCTAssertFalse([postAuthTokens isEqualToDictionary:preAuthTokens]);

              [exp fulfill];
          }];
     }];

    [self waitForExpectationsWithTimeout:100 handler:nil];
}

- (void)testNewTrackerWithAlwaysInvalidTokens {
    if (![self->mutatorsEnabled boolValue]) {
        return;
    }

    // This shouldn't happen with a well-behaved server, but tests a catastrophic code path.
    XCTestExpectation *exp = [self expectationWithDescription:@"Failure: new tracker with always invalid tokens"];

    NSArray *purchaseClasses =  @[]; // not relevant to this test

    // Blow away any existing tokens.
    [TestHelpers clearUserInfo:psiCash];

    // Do an initial refresh to get Tracker tokens.
    [self->psiCash refreshState:purchaseClasses
                 withCompletion:^(PsiCashStatus status,
                                  NSArray * _Nullable validTokenTypes,
                                  BOOL isAccount,
                                  NSNumber * _Nullable balance,
                                  NSArray * _Nullable purchasePrices,
                                  NSError * _Nullable error)
     {
         XCTAssertNil(error);
         XCTAssertEqual(status, PsiCashStatus_Success);

         NSDictionary *preAuthTokens = [TestHelpers getAuthTokens:self->psiCash];
         XCTAssertGreaterThan(preAuthTokens.count, 0);

         // Add a request mutator that will cause our tokens to seem invalid.
         [TestHelpers setRequestMutators:self->psiCash
                                mutators:@[@"InvalidTokens",    // RefreshState
                                           [NSNull null],       // NewTracker
                                           @"InvalidTokens"]];  // RefreshState

         // Make the request again. Should get us new tokens.
         [self->psiCash refreshState:purchaseClasses
                      withCompletion:^(PsiCashStatus status,
                                       NSArray * _Nullable validTokenTypes,
                                       BOOL isAccount,
                                       NSNumber * _Nullable balance,
                                       NSArray * _Nullable purchasePrices,
                                       NSError * _Nullable error)
          {
              // Getting valid tokens failed utterly. Should be an error.
              XCTAssertNotNil(error);
              XCTAssertEqual(status, PsiCashStatus_Invalid);

              [exp fulfill];
          }];
     }];

    [self waitForExpectationsWithTimeout:100 handler:nil];
}

- (void)testNoServerResponseNewTracker {
    if (![self->mutatorsEnabled boolValue]) {
        return;
    }

    XCTestExpectation *exp = [self expectationWithDescription:@"Error: no response from NewTracker"];

    NSArray *purchaseClasses =  @[]; // not relevant to this test

    // Blow away any existing tokens to force internal NewTracker.
    [TestHelpers clearUserInfo:psiCash];

    [TestHelpers setRequestMutators:self->psiCash
                           mutators:@[@"Timeout:11"]];  // NewTracker, sleep for 11 secs

    [self->psiCash refreshState:purchaseClasses
                 withCompletion:^(PsiCashStatus status,
                                  NSArray * _Nullable validTokenTypes,
                                  BOOL isAccount,
                                  NSNumber * _Nullable balance,
                                  NSArray * _Nullable purchasePrices,
                                  NSError * _Nullable error)
     {
         XCTAssertNotNil(error);
         XCTAssertEqual(status, PsiCashStatus_Invalid);

         [exp fulfill];
     }];

    [self waitForExpectationsWithTimeout:100 handler:nil];
}

- (void)testNoServerResponseRefreshState {
    if (![self->mutatorsEnabled boolValue]) {
        return;
    }

    XCTestExpectation *exp = [self expectationWithDescription:@"Error: no response from RefreshState"];

    NSArray *purchaseClasses =  @[]; // not relevant to this test

    // Blow away any existing tokens.
    [TestHelpers clearUserInfo:psiCash];

    // Do an initial refresh to get Tracker tokens.
    [self->psiCash refreshState:purchaseClasses
                 withCompletion:^(PsiCashStatus status,
                                  NSArray * _Nullable validTokenTypes,
                                  BOOL isAccount,
                                  NSNumber * _Nullable balance,
                                  NSArray * _Nullable purchasePrices,
                                  NSError * _Nullable error)
     {
         XCTAssertNil(error);
         XCTAssertEqual(status, PsiCashStatus_Success);

         NSDictionary *preAuthTokens = [TestHelpers getAuthTokens:self->psiCash];
         XCTAssertGreaterThan(preAuthTokens.count, 0);

         // Add a request mutator that will cause no response.
         [TestHelpers setRequestMutators:self->psiCash
                                mutators:@[@"Timeout:11"]];  // RefreshState, sleep for 11 secs

         [self->psiCash refreshState:purchaseClasses
                      withCompletion:^(PsiCashStatus status,
                                       NSArray * _Nullable validTokenTypes,
                                       BOOL isAccount,
                                       NSNumber * _Nullable balance,
                                       NSArray * _Nullable purchasePrices,
                                       NSError * _Nullable error)
          {
              // Getting valid tokens failed utterly. Should be an error.
              XCTAssertNotNil(error);
              XCTAssertEqual(status, PsiCashStatus_Invalid);

              [exp fulfill];
          }];
     }];

    [self waitForExpectationsWithTimeout:100 handler:nil];
}

- (void)testNoDataNewTracker {
    if (![self->mutatorsEnabled boolValue]) {
        return;
    }

    // This shouldn't happen with a well-behaved server, but tests a catastrophic code path.
    XCTestExpectation *exp = [self expectationWithDescription:@"Error: no data in response from NewTracker"];

    NSArray *purchaseClasses =  @[]; // not relevant to this test

    // Blow away any existing tokens to force internal NewTracker.
    [TestHelpers clearUserInfo:psiCash];

    // Add a request mutator that will cause no response body.
    [TestHelpers setRequestMutators:self->psiCash
                           mutators:@[@"Response:code=200,body=none"]];  // NewTracker

    [self->psiCash refreshState:purchaseClasses
                 withCompletion:^(PsiCashStatus status,
                                  NSArray * _Nullable validTokenTypes,
                                  BOOL isAccount,
                                  NSNumber * _Nullable balance,
                                  NSArray * _Nullable purchasePrices,
                                  NSError * _Nullable error)
     {
         XCTAssertNotNil(error);
         XCTAssertEqual(status, PsiCashStatus_Invalid);

         [exp fulfill];
     }];

    [self waitForExpectationsWithTimeout:100 handler:nil];
}

- (void)testNoDataRefreshState {
    if (![self->mutatorsEnabled boolValue]) {
        return;
    }

    // This shouldn't happen with a well-behaved server, but tests a catastrophic code path.
    XCTestExpectation *exp = [self expectationWithDescription:@"Error: no data in response from RefreshState"];

    NSArray *purchaseClasses =  @[]; // not relevant to this test

    // Blow away any existing tokens.
    [TestHelpers clearUserInfo:psiCash];

    // Do an initial refresh to get Tracker tokens.
    [self->psiCash refreshState:purchaseClasses
                 withCompletion:^(PsiCashStatus status,
                                  NSArray * _Nullable validTokenTypes,
                                  BOOL isAccount,
                                  NSNumber * _Nullable balance,
                                  NSArray * _Nullable purchasePrices,
                                  NSError * _Nullable error)
     {
         XCTAssertNil(error);
         XCTAssertEqual(status, PsiCashStatus_Success);

         // Add a request mutator that will cause no response body.
         [TestHelpers setRequestMutators:self->psiCash
                                mutators:@[@"Response:code=200,body=none"]];  // RefreshState

         // Do another request, now that we we have tokens
         [self->psiCash refreshState:purchaseClasses
                      withCompletion:^(PsiCashStatus status,
                                       NSArray * _Nullable validTokenTypes,
                                       BOOL isAccount,
                                       NSNumber * _Nullable balance,
                                       NSArray * _Nullable purchasePrices,
                                       NSError * _Nullable error)
          {
              XCTAssertNotNil(error);
              XCTAssertEqual(status, PsiCashStatus_Invalid);

              [exp fulfill];
          }];
     }];

    [self waitForExpectationsWithTimeout:100 handler:nil];
}

- (void)testBadJSONNewTracker {
    if (![self->mutatorsEnabled boolValue]) {
        return;
    }

    // This shouldn't happen with a well-behaved server, but tests a catastrophic code path.
    XCTestExpectation *exp = [self expectationWithDescription:@"Error: invalid JSON data in response from NewTracker"];

    NSArray *purchaseClasses =  @[]; // not relevant to this test

    [TestHelpers clearUserInfo:psiCash];

    // Add a request mutator that will cause invalid JSON in the response.
    [TestHelpers setRequestMutators:self->psiCash
                           mutators:@[@"BadJSON:200"]];  // NewTracker

    [self->psiCash refreshState:purchaseClasses
                 withCompletion:^(PsiCashStatus status,
                                  NSArray * _Nullable validTokenTypes,
                                  BOOL isAccount,
                                  NSNumber * _Nullable balance,
                                  NSArray * _Nullable purchasePrices,
                                  NSError * _Nullable error)
     {
         // Getting valid tokens failed utterly. Should be an error.
         XCTAssertNotNil(error);
         XCTAssertEqual(status, PsiCashStatus_Invalid);

         [exp fulfill];
     }];

    [self waitForExpectationsWithTimeout:100 handler:nil];
}

- (void)testBadJSONRefreshState {
    if (![self->mutatorsEnabled boolValue]) {
        return;
    }

    // This shouldn't happen with a well-behaved server, but tests a catastrophic code path.
    XCTestExpectation *exp = [self expectationWithDescription:@"Error: invalid JSON data in response from RefreshState"];

    NSArray *purchaseClasses =  @[]; // not relevant to this test

    // Blow away any existing tokens.
    [TestHelpers clearUserInfo:psiCash];

    // Do an initial refresh to get Tracker tokens.
    [self->psiCash refreshState:purchaseClasses
                 withCompletion:^(PsiCashStatus status,
                                  NSArray * _Nullable validTokenTypes,
                                  BOOL isAccount,
                                  NSNumber * _Nullable balance,
                                  NSArray * _Nullable purchasePrices,
                                  NSError * _Nullable error)
     {
         XCTAssertNil(error);
         XCTAssertEqual(status, PsiCashStatus_Success);

         NSDictionary *preAuthTokens = [TestHelpers getAuthTokens:self->psiCash];
         XCTAssertGreaterThan(preAuthTokens.count, 0);

         // Add a request mutator that will cause invalid JSON in the response.
         [TestHelpers setRequestMutators:self->psiCash
                                mutators:@[@"BadJSON:200"]];  // RefreshState

         [self->psiCash refreshState:purchaseClasses
                      withCompletion:^(PsiCashStatus status,
                                       NSArray * _Nullable validTokenTypes,
                                       BOOL isAccount,
                                       NSNumber * _Nullable balance,
                                       NSArray * _Nullable purchasePrices,
                                       NSError * _Nullable error)
          {
              XCTAssertNotNil(error);
              XCTAssertEqual(status, PsiCashStatus_Invalid);

              [exp fulfill];
          }];
     }];

    [self waitForExpectationsWithTimeout:100 handler:nil];
}

- (void)testServer500NewTracker {
    if (![self->mutatorsEnabled boolValue]) {
        return;
    }

    // This shouldn't happen with a well-behaved server, but tests a catastrophic code path.
    XCTestExpectation *exp = [self expectationWithDescription:@"Error: 500 response from NewTracker"];

    NSArray *purchaseClasses =  @[]; // not relevant to this test

    // Blow away any existing tokens to force internal NewTracker.
    [TestHelpers clearUserInfo:psiCash];

    [TestHelpers setRequestMutators:self->psiCash
                           mutators:@[@"Response:code=500"]];  // NewTracker

    [self->psiCash refreshState:purchaseClasses
                 withCompletion:^(PsiCashStatus status,
                                  NSArray * _Nullable validTokenTypes,
                                  BOOL isAccount,
                                  NSNumber * _Nullable balance,
                                  NSArray * _Nullable purchasePrices,
                                  NSError * _Nullable error)
     {
         XCTAssertNil(error);
         XCTAssertEqual(status, PsiCashStatus_ServerError);

         [exp fulfill];
     }];

    [self waitForExpectationsWithTimeout:100 handler:nil];
}

- (void)testServer500RefreshState {
    if (![self->mutatorsEnabled boolValue]) {
        return;
    }

    // This shouldn't happen with a well-behaved server, but tests a catastrophic code path.
    XCTestExpectation *exp = [self expectationWithDescription:@"Error: 500 response from RefreshState"];

    NSArray *purchaseClasses =  @[]; // not relevant to this test

    // Blow away any existing tokens.
    [TestHelpers clearUserInfo:psiCash];

    // Do an initial refresh to get Tracker tokens.
    [self->psiCash refreshState:purchaseClasses
                 withCompletion:^(PsiCashStatus status,
                                  NSArray * _Nullable validTokenTypes,
                                  BOOL isAccount,
                                  NSNumber * _Nullable balance,
                                  NSArray * _Nullable purchasePrices,
                                  NSError * _Nullable error)
     {
         XCTAssertNil(error);
         XCTAssertEqual(status, PsiCashStatus_Success);

         NSDictionary *preAuthTokens = [TestHelpers getAuthTokens:self->psiCash];
         XCTAssertGreaterThan(preAuthTokens.count, 0);

         // Add a request mutator that will cause no response.
         [TestHelpers setRequestMutators:self->psiCash
                                mutators:@[@"Response:code=500"]];  // RefreshState

         [self->psiCash refreshState:purchaseClasses
                      withCompletion:^(PsiCashStatus status,
                                       NSArray * _Nullable validTokenTypes,
                                       BOOL isAccount,
                                       NSNumber * _Nullable balance,
                                       NSArray * _Nullable purchasePrices,
                                       NSError * _Nullable error)
          {
              XCTAssertNil(error);
              XCTAssertEqual(status, PsiCashStatus_ServerError);

              [exp fulfill];
          }];
     }];

    [self waitForExpectationsWithTimeout:100 handler:nil];
}

- (void)testServerUnknownCodeNewTracker {
    if (![self->mutatorsEnabled boolValue]) {
        return;
    }

    // This shouldn't happen with a well-behaved server, but tests a catastrophic code path.
    XCTestExpectation *exp = [self expectationWithDescription:@"Error: unknown response code from NewTracker"];

    NSArray *purchaseClasses =  @[]; // not relevant to this test

    // Blow away any existing tokens to force internal NewTracker.
    [TestHelpers clearUserInfo:psiCash];

    [TestHelpers setRequestMutators:self->psiCash
                           mutators:@[@"Response:code=666"]];  // NewTracker

    [self->psiCash refreshState:purchaseClasses
                 withCompletion:^(PsiCashStatus status,
                                  NSArray * _Nullable validTokenTypes,
                                  BOOL isAccount,
                                  NSNumber * _Nullable balance,
                                  NSArray * _Nullable purchasePrices,
                                  NSError * _Nullable error)
     {
         XCTAssertNotNil(error);
         XCTAssertEqual(status, PsiCashStatus_Invalid);

         [exp fulfill];
     }];

    [self waitForExpectationsWithTimeout:100 handler:nil];
}

- (void)testServerUnknownCodeRefreshState {
    if (![self->mutatorsEnabled boolValue]) {
        return;
    }

    // This shouldn't happen with a well-behaved server, but tests a catastrophic code path.
    XCTestExpectation *exp = [self expectationWithDescription:@"Error: unknown response code from RefreshState"];

    NSArray *purchaseClasses =  @[]; // not relevant to this test

    // Blow away any existing tokens.
    [TestHelpers clearUserInfo:psiCash];

    // Do an initial refresh to get Tracker tokens.
    [self->psiCash refreshState:purchaseClasses
                 withCompletion:^(PsiCashStatus status,
                                  NSArray * _Nullable validTokenTypes,
                                  BOOL isAccount,
                                  NSNumber * _Nullable balance,
                                  NSArray * _Nullable purchasePrices,
                                  NSError * _Nullable error)
     {
         XCTAssertNil(error);
         XCTAssertEqual(status, PsiCashStatus_Success);

         NSDictionary *preAuthTokens = [TestHelpers getAuthTokens:self->psiCash];
         XCTAssertGreaterThan(preAuthTokens.count, 0);

         // Add a request mutator that will cause no response.
         [TestHelpers setRequestMutators:self->psiCash
                                mutators:@[@"Response:code=666"]];  // RefreshState

         [self->psiCash refreshState:purchaseClasses
                      withCompletion:^(PsiCashStatus status,
                                       NSArray * _Nullable validTokenTypes,
                                       BOOL isAccount,
                                       NSNumber * _Nullable balance,
                                       NSArray * _Nullable purchasePrices,
                                       NSError * _Nullable error)
          {
              // Getting valid tokens failed utterly. Should be an error.
              XCTAssertNotNil(error);
              XCTAssertEqual(status, PsiCashStatus_Invalid);

              [exp fulfill];
          }];
     }];

    [self waitForExpectationsWithTimeout:100 handler:nil];
}

@end
