//
//  GetBalance.m
//  PsiCashLibTests
//

#import <XCTest/XCTest.h>
#import "TestHelpers.h"


@interface GetBalanceTests : XCTestCase

@property PsiCash *psiCash;

@end

@implementation GetBalanceTests

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
    
    [psiCash getBalance:^(PsiCashRequestStatus status,
                          NSNumber* balance,
                          NSError *error) {
        XCTAssertNil(error);
        XCTAssertEqual(status, kSuccess);
        
        XCTAssertGreaterThanOrEqual(balance, @0);
        
        [exp fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:5 handler:nil];
}

- (void)testWithNonzero {
    XCTestExpectation *exp = [self expectationWithDescription:@"Success: reward then check"];
    
    [psiCash getBalance:^(PsiCashRequestStatus status,
                          NSNumber* originalBalance,
                          NSError *error) {
        XCTAssertNil(error);
        XCTAssertEqual(status, kSuccess);
        XCTAssertGreaterThanOrEqual(originalBalance, @0);
        
        // Make a reward request so that we can test a nonzero balance.
        [TestHelpers make1TRewardRequest:psiCash
                              completion:^(BOOL success)
         {
             XCTAssert(success);
             
             [psiCash getBalance:^(PsiCashRequestStatus status,
                                   NSNumber* newBalance,
                                   NSError *error) {
                 XCTAssertNil(error);
                 XCTAssertEqual(status, kSuccess);
                 
                 // Is the balance bigger?
                 XCTAssertEqual(newBalance.integerValue,
                                originalBalance.integerValue + 1000000000000);
                 
                 [exp fulfill];
             }];
         }];
    }];
    
    [self waitForExpectationsWithTimeout:5 handler:nil];
}


@end

