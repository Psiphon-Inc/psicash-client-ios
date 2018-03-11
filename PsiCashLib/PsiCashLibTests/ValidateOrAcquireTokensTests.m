//
//  ValidateOrAcquireTokensTests.m
//  PsiCashLibTests
//

#import <XCTest/XCTest.h>
#import <PsiCashLib/PsiCashLib.h>

@interface ValidateOrAcquireTokensTests : XCTestCase

@property PsiCash *psiCash;

@end

@implementation ValidateOrAcquireTokensTests

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

- (void)testBasic {
    XCTestExpectation *exp = [self expectationWithDescription:@"Success: simple"];
    
    [psiCash validateOrAcquireTokens:^(PsiCashRequestStatus status,
                                       NSArray *validTokenTypes,
                                       BOOL isAccount,
                                       NSError *error) {
        XCTAssertNil(error);
        XCTAssertEqual(status, kSuccess);
        
        XCTAssertNotNil(validTokenTypes);
        XCTAssertGreaterThanOrEqual(validTokenTypes.count, 3);
        
        [exp fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:5 handler:nil];
}

- (void)testWithGetBalance {
    
    XCTestExpectation *exp = [self expectationWithDescription:@"Do following GetBalance to ensure Tokens exist"];
    
    [psiCash validateOrAcquireTokens:^(PsiCashRequestStatus status,
                                       NSArray *validTokenTypes,
                                       BOOL isAccount,
                                       NSError *error) {
        XCTAssertNil(error);
        XCTAssertEqual(status, kSuccess);
        
        [psiCash getBalance:^(PsiCashRequestStatus status,
                              NSNumber* balance,
                              NSError *error) {
            XCTAssertNil(error);
            XCTAssertEqual(status, kSuccess);
            XCTAssertGreaterThanOrEqual(balance, @0);
            
            [exp fulfill];
        }];
    }];
    
    [self waitForExpectationsWithTimeout:5 handler:nil];
}


@end

