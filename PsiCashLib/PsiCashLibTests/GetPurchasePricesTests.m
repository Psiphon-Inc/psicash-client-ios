//
//  GetPurchasePricesTests.m
//  PsiCashLibTests
//

#import <XCTest/XCTest.h>
#import <PsiCashLib/PsiCashLib.h>

@interface GetPurchasePricesTests : XCTestCase

@property PsiCash *psiCash;

@end

@implementation GetPurchasePricesTests

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
    
    NSArray *purchaseClasses =  @[@"speed-boost"];
    [psiCash getPurchasePricesForClasses:purchaseClasses
                       completionHandler:^(PsiCashRequestStatus status,
                                           NSArray * _Nullable purchasePrices,
                                           NSError * _Nullable error)
     {
         XCTAssertNil(error);
         XCTAssertEqual(status, kSuccess);
         
         XCTAssertGreaterThanOrEqual(purchasePrices.count, 2);
         
         [exp fulfill];
     }];
    
    [self waitForExpectationsWithTimeout:5 handler:nil];
}

- (void)testNoResults {
    XCTestExpectation *exp = [self expectationWithDescription:@"Success: no results (invalid class)"];
    
    NSArray *purchaseClasses =  @[@"invalid"];
    [psiCash getPurchasePricesForClasses:purchaseClasses
                       completionHandler:^(PsiCashRequestStatus status,
                                           NSArray * _Nullable purchasePrices,
                                           NSError * _Nullable error)
     {
         XCTAssertNil(error);
         XCTAssertEqual(status, kSuccess);
         
         XCTAssertEqual(purchasePrices.count, 0);
         
         [exp fulfill];
     }];
    
    [self waitForExpectationsWithTimeout:5 handler:nil];
}


@end


