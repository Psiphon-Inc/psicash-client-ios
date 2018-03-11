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

@implementation NewTransactionTests

@synthesize psiCash;

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
    
    psiCash = [[PsiCash alloc] init];
    
    XCTestExpectation *exp = [self expectationWithDescription:@"Init tokens"];
    
    [psiCash validateOrAcquireTokens:^(PsiCashRequestStatus status,
                                       NSArray *validTokenTypes,
                                       BOOL isAccount,
                                       NSError *error) {
        XCTAssertNil(error);
        XCTAssertEqual(status, kSuccess);
        
        [exp fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:5 handler:nil];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
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
         [psiCash getBalance:^(PsiCashRequestStatus status,
                               NSNumber* prePurchaseBalance,
                               NSError *error) {
             XCTAssertNil(error);
             XCTAssertEqual(status, kSuccess);
             XCTAssertGreaterThanOrEqual(prePurchaseBalance.integerValue, ONE_TRILLION);
             
             // Now make the transaction
             [psiCash newExpiringPurchaseTransactionForClass:@TEST_DEBIT_TRANSACTION_CLASS
                                           withDistinguisher:@"1trillion-1second"
                                           withExpectedPrice:@ONE_TRILLION
                                              withCompletion:^(PsiCashRequestStatus status,
                                                               NSNumber*_Nullable price,
                                                               NSNumber*_Nullable balance,
                                                               NSDate*_Nullable expiry,
                                                               NSString*_Nullable authorization,
                                                               NSError*_Nullable error)
              {
                  XCTAssertNil(error);
                  XCTAssertEqual(status, kSuccess);
                  XCTAssertEqual(price.integerValue, ONE_TRILLION);
                  XCTAssertEqual(balance, @(prePurchaseBalance.integerValue - ONE_TRILLION));
                  XCTAssertNotNil(expiry);

                  NSDate *now = [NSDate dateWithTimeIntervalSinceNow:0];
                  // Check that the expiry is within 2 seconds of now.
                  XCTAssertLessThan(fabs([expiry timeIntervalSinceDate:now]), 2.0);

                  // Our test class doesn't produce an authorization
                  XCTAssertNil(authorization);
                  
                  [exp fulfill];
              }];
             
         }];
     }];
    
    [self waitForExpectationsWithTimeout:5 handler:nil];
}

- (void)testInsufficientBalance {
    XCTestExpectation *exp = [self expectationWithDescription:@"Failure: insufficient balance"];
    
    // Check our balance to compare against later.
    [psiCash getBalance:^(PsiCashRequestStatus status,
                          NSNumber* prePurchaseBalance,
                          NSError *error) {
        XCTAssertNil(error);
        XCTAssertEqual(status, kSuccess);
        XCTAssertGreaterThanOrEqual(prePurchaseBalance, @0);
        
        [psiCash newExpiringPurchaseTransactionForClass:@TEST_DEBIT_TRANSACTION_CLASS
                                      withDistinguisher:@"int64max"
                                      withExpectedPrice:@TEST_INT64_MAX
                                         withCompletion:^(PsiCashRequestStatus status,
                                                          NSNumber*_Nullable price,
                                                          NSNumber*_Nullable balance,
                                                          NSDate*_Nullable expiry,
                                                          NSString*_Nullable authorization,
                                                          NSError*_Nullable error)
         {
             XCTAssertNil(error);
             XCTAssertEqual(status, kInsufficientBalance);
             XCTAssertEqual(price.integerValue, TEST_INT64_MAX);
             XCTAssertEqual(balance, prePurchaseBalance);
             XCTAssertNil(expiry);
             XCTAssertNil(authorization);
             
             [exp fulfill];
         }];
    }];
    
    [self waitForExpectationsWithTimeout:5 handler:nil];
}

- (void)testExistingTransaction {
    XCTestExpectation *exp = [self expectationWithDescription:@"Failure: existing transaction"];

    // Start by ensuring we have sufficient balance
    [TestHelpers make1TRewardRequest:psiCash
                          completion:^(BOOL success)
     {
         XCTAssert(success);

         // Successfully purchase the long-lived item
         [psiCash newExpiringPurchaseTransactionForClass:@TEST_DEBIT_TRANSACTION_CLASS
                                       withDistinguisher:@"1trillion-1minute"
                                       withExpectedPrice:@ONE_TRILLION
                                          withCompletion:^(PsiCashRequestStatus status,
                                                           NSNumber*_Nullable price,
                                                           NSNumber*_Nullable balance,
                                                           NSDate*_Nullable successfulExpiry,
                                                           NSString*_Nullable authorization,
                                                           NSError*_Nullable error)
          {
              XCTAssertNil(error);
              XCTAssertEqual(status, kSuccess); // IF THIS FAILS, WAIT ONE MINUTE AND TRY AGAIN
              XCTAssertEqual(price.integerValue, ONE_TRILLION);
              XCTAssertGreaterThanOrEqual(balance.integerValue, 0);
              XCTAssertNil(authorization);
              XCTAssertNotNil(successfulExpiry);

              NSDate *now = [NSDate dateWithTimeIntervalSinceNow:0];
              XCTAssertEqual([successfulExpiry earlierDate:now], now);

              // Try and fail to make the same purchase again
              [psiCash newExpiringPurchaseTransactionForClass:@TEST_DEBIT_TRANSACTION_CLASS
                                            withDistinguisher:@"1trillion-1minute"
                                            withExpectedPrice:@ONE_TRILLION
                                               withCompletion:^(PsiCashRequestStatus status,
                                                                NSNumber*_Nullable price,
                                                                NSNumber*_Nullable balance,
                                                                NSDate*_Nullable expiry,
                                                                NSString*_Nullable authorization,
                                                                NSError*_Nullable error)
               {
                   XCTAssertNil(error);
                   XCTAssertEqual(status, kExistingTransaction);
                   XCTAssertEqual(price.integerValue, ONE_TRILLION);
                   XCTAssertGreaterThanOrEqual(balance.integerValue, 0);
                   XCTAssertNil(authorization);

                   XCTAssert([expiry isEqualToDate:successfulExpiry]);

                   [exp fulfill];
               }];
          }];
     }];

    [self waitForExpectationsWithTimeout:5 handler:nil];
}

- (void)testTransactionAmountMismatch {
    XCTestExpectation *exp = [self expectationWithDescription:@"Failure: transaction amount mismatch"];

    [psiCash newExpiringPurchaseTransactionForClass:@TEST_DEBIT_TRANSACTION_CLASS
                                  withDistinguisher:@"int64max"
                                  withExpectedPrice:@(TEST_INT64_MAX-1) // MISMATCH!
                                     withCompletion:^(PsiCashRequestStatus status,
                                                      NSNumber*_Nullable price,
                                                      NSNumber*_Nullable balance,
                                                      NSDate*_Nullable expiry,
                                                      NSString*_Nullable authorization,
                                                      NSError*_Nullable error)
     {
         XCTAssertNil(error);
         XCTAssertEqual(status, kTransactionAmountMismatch);
         XCTAssertEqual(price.integerValue, TEST_INT64_MAX);
         XCTAssertGreaterThanOrEqual(balance.integerValue, 0);
         XCTAssertNil(expiry);
         XCTAssertNil(authorization);
         
         [exp fulfill];
     }];

    [self waitForExpectationsWithTimeout:5 handler:nil];
}

- (void)testTransactionTypeNotFound {
    XCTestExpectation *exp = [self expectationWithDescription:@"Failure: transaction type not found"];

    [psiCash newExpiringPurchaseTransactionForClass:@TEST_DEBIT_TRANSACTION_CLASS
                                  withDistinguisher:@"INVALID"
                                  withExpectedPrice:@(TEST_INT64_MAX)
                                     withCompletion:^(PsiCashRequestStatus status,
                                                      NSNumber*_Nullable price,
                                                      NSNumber*_Nullable balance,
                                                      NSDate*_Nullable expiry,
                                                      NSString*_Nullable authorization,
                                                      NSError*_Nullable error)
     {
         XCTAssertNil(error);
         XCTAssertEqual(status, kTransactionTypeNotFound);
         XCTAssertNil(price);
         XCTAssertNil(balance);
         XCTAssertNil(expiry);
         XCTAssertNil(authorization);

         [exp fulfill];
     }];

    [self waitForExpectationsWithTimeout:5 handler:nil];
}


@end


