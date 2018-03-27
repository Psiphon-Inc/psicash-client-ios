//
//  RefreshClientState.m
//  PsiCashLibTests
//

#import <XCTest/XCTest.h>
#import "TestHelpers.h"


@interface RefreshClientStateTests : XCTestCase

@property PsiCash *psiCash;

@end

@implementation RefreshClientStateTests

@synthesize psiCash;

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.

    psiCash = [[PsiCash alloc] init];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testNewTracker {
    XCTestExpectation *exp = [self expectationWithDescription:@"Success: new tracker"];

    // Blow away any existing tokens.
    [TestHelpers clearUserID:psiCash];

    NSArray *purchaseClasses =  @[@"speed-boost"];

    [psiCash refreshState:purchaseClasses
           withCompletion:^(PsiCashRequestStatus status,
                            NSArray * _Nullable validTokenTypes,
                            BOOL isAccount,
                            NSNumber * _Nullable balance,
                            NSArray * _Nullable purchasePrices,
                            NSError * _Nullable error)
     {
         XCTAssertNil(error);
         XCTAssertEqual(status, kSuccess);

         XCTAssertFalse(isAccount);

         XCTAssertNotNil(validTokenTypes);
         XCTAssertGreaterThanOrEqual(validTokenTypes.count, 3);

         XCTAssertNotNil(balance);
         XCTAssertEqual([balance integerValue], 0);

         XCTAssertNotNil(purchasePrices);
         XCTAssertGreaterThanOrEqual(purchasePrices.count, 2);

         [exp fulfill];
     }];

    [self waitForExpectationsWithTimeout:5 handler:nil];
}

- (void)testExistingTracker {
    XCTestExpectation *exp = [self expectationWithDescription:@"Success: existing tracker"];

    NSArray *purchaseClasses =  @[@"speed-boost"];

    // Make the request twice, to ensure the tokens exist for the second call.

    [psiCash refreshState:purchaseClasses
           withCompletion:^(PsiCashRequestStatus status,
                            NSArray * _Nullable validTokenTypes,
                            BOOL isAccount,
                            NSNumber * _Nullable balance,
                            NSArray * _Nullable purchasePrices,
                            NSError * _Nullable error)
     {
         XCTAssertNil(error);
         XCTAssertEqual(status, kSuccess);

         XCTAssertFalse(isAccount);

         XCTAssertNotNil(validTokenTypes);
         XCTAssertGreaterThanOrEqual(validTokenTypes.count, 3);

         XCTAssertNotNil(balance);
         XCTAssertGreaterThanOrEqual([balance integerValue], 0);

         XCTAssertNotNil(purchasePrices);
         XCTAssertGreaterThanOrEqual(purchasePrices.count, 2);

         [psiCash refreshState:purchaseClasses
                withCompletion:^(PsiCashRequestStatus status,
                                 NSArray * _Nullable validTokenTypes,
                                 BOOL isAccount,
                                 NSNumber * _Nullable balance,
                                 NSArray * _Nullable purchasePrices,
                                 NSError * _Nullable error)
          {
              XCTAssertNil(error);
              XCTAssertEqual(status, kSuccess);

              XCTAssertFalse(isAccount);

              XCTAssertNotNil(validTokenTypes);
              XCTAssertGreaterThanOrEqual(validTokenTypes.count, 3);

              XCTAssertNotNil(balance);
              XCTAssertGreaterThanOrEqual([balance integerValue], 0);

              XCTAssertNotNil(purchasePrices);
              XCTAssertGreaterThanOrEqual(purchasePrices.count, 2);

              [exp fulfill];
          }];
     }];

    [self waitForExpectationsWithTimeout:5 handler:nil];
}

- (void)testNoPurchases {
    XCTestExpectation *exp = [self expectationWithDescription:@"Success: no purchase classes"];

    NSArray *purchaseClasses =  @[];

    [psiCash refreshState:purchaseClasses
           withCompletion:^(PsiCashRequestStatus status,
                            NSArray * _Nullable validTokenTypes,
                            BOOL isAccount,
                            NSNumber * _Nullable balance,
                            NSArray * _Nullable purchasePrices,
                            NSError * _Nullable error)
     {
         XCTAssertNil(error);
         XCTAssertEqual(status, kSuccess);

         XCTAssertFalse(isAccount);

         XCTAssertNotNil(validTokenTypes);
         XCTAssertGreaterThanOrEqual(validTokenTypes.count, 3);

         XCTAssertNotNil(balance);
         XCTAssertGreaterThanOrEqual([balance integerValue], 0);

         XCTAssertNotNil(purchasePrices);
         XCTAssertEqual(purchasePrices.count, 0);

         [exp fulfill];
     }];

    [self waitForExpectationsWithTimeout:5 handler:nil];
}

- (void)testMultiplePurchaseClasses {
    XCTestExpectation *exp = [self expectationWithDescription:@"Success: multiple purchase classes"];

    NSArray *purchaseClasses =  @[@"speed-boost", @TEST_DEBIT_TRANSACTION_CLASS];

    [psiCash refreshState:purchaseClasses
           withCompletion:^(PsiCashRequestStatus status,
                            NSArray * _Nullable validTokenTypes,
                            BOOL isAccount,
                            NSNumber * _Nullable balance,
                            NSArray * _Nullable purchasePrices,
                            NSError * _Nullable error)
     {
         XCTAssertNil(error);
         XCTAssertEqual(status, kSuccess);

         XCTAssertFalse(isAccount);

         XCTAssertNotNil(validTokenTypes);
         XCTAssertGreaterThanOrEqual(validTokenTypes.count, 3);

         XCTAssertNotNil(balance);
         XCTAssertGreaterThanOrEqual([balance integerValue], 0);

         XCTAssertNotNil(purchasePrices);
         XCTAssertGreaterThanOrEqual(purchasePrices.count, 3);

         [exp fulfill];
     }];

    [self waitForExpectationsWithTimeout:5 handler:nil];
}

- (void)testBalanceIncrease {
    XCTestExpectation *exp = [self expectationWithDescription:@"Success: balance increase"];

    NSArray *purchaseClasses =  @[@"speed-boost"];

    [psiCash refreshState:purchaseClasses
           withCompletion:^(PsiCashRequestStatus status,
                            NSArray * _Nullable validTokenTypes,
                            BOOL isAccount,
                            NSNumber * _Nullable originalBalance,
                            NSArray * _Nullable purchasePrices,
                            NSError * _Nullable error)
     {
         XCTAssertNil(error);
         XCTAssertEqual(status, kSuccess);

         XCTAssertFalse(isAccount);

         XCTAssertNotNil(validTokenTypes);
         XCTAssertGreaterThanOrEqual(validTokenTypes.count, 3);

         XCTAssertNotNil(originalBalance);
         XCTAssertGreaterThanOrEqual([originalBalance integerValue], 0);

         XCTAssertNotNil(purchasePrices);
         XCTAssertGreaterThanOrEqual(purchasePrices.count, 2);

         // Make a reward request so that we can test an increased balance.
         [TestHelpers make1TRewardRequest:psiCash
                               completion:^(BOOL success)
          {
              XCTAssert(success);

              // Refresh state again to check balance.
              [psiCash refreshState:purchaseClasses
                     withCompletion:^(PsiCashRequestStatus status,
                                      NSArray * _Nullable validTokenTypes,
                                      BOOL isAccount,
                                      NSNumber * _Nullable newBalance,
                                      NSArray * _Nullable purchasePrices,
                                      NSError * _Nullable error)
               {
                   XCTAssertNil(error);
                   XCTAssertEqual(status, kSuccess);

                   // Is the balance bigger?
                   XCTAssertEqual(newBalance.integerValue,
                                  originalBalance.integerValue + ONE_TRILLION);

                   [exp fulfill];
               }];
          }];
     }];

    [self waitForExpectationsWithTimeout:5 handler:nil];
}

- (void)testForceIsAccountInvalid {
    XCTestExpectation *exp = [self expectationWithDescription:@"Error: force is-account"];

    // We're setting "isAccount" with tracker tokens. This is not okay.
    [TestHelpers setIsAccount:psiCash];

    NSArray *purchaseClasses =  @[@"speed-boost"];

    [psiCash refreshState:purchaseClasses
           withCompletion:^(PsiCashRequestStatus status,
                            NSArray * _Nullable validTokenTypes,
                            BOOL isAccount,
                            NSNumber * _Nullable balance,
                            NSArray * _Nullable purchasePrices,
                            NSError * _Nullable error)
     {
         XCTAssertNotNil(error);
         XCTAssertEqual(status, kInvalid);

         [TestHelpers clearUserID:psiCash];

         [exp fulfill];
     }];

    [self waitForExpectationsWithTimeout:5 handler:nil];
}

- (void)testIsAccountNoTokens {
    XCTestExpectation *exp = [self expectationWithDescription:@"Success: account with no tokens"];

    // Blow away any existing tokens.
    [TestHelpers clearUserID:psiCash];
    // Force user state to is-account
    [TestHelpers setIsAccount:psiCash];

    NSArray *purchaseClasses =  @[@"speed-boost"];

    [psiCash refreshState:purchaseClasses
           withCompletion:^(PsiCashRequestStatus status,
                            NSArray * _Nullable validTokenTypes,
                            BOOL isAccount,
                            NSNumber * _Nullable balance,
                            NSArray * _Nullable purchasePrices,
                            NSError * _Nullable error)
     {
         XCTAssertNil(error);
         XCTAssertEqual(status, kSuccess);

         XCTAssertTrue(isAccount);

         XCTAssertNotNil(validTokenTypes);
         XCTAssertEqual(validTokenTypes.count, 0);

         XCTAssertNil(balance);

         XCTAssertNil(purchasePrices);

         [TestHelpers clearUserID:psiCash];

         [exp fulfill];
     }];

    [self waitForExpectationsWithTimeout:5 handler:nil];
}

@end
