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
//  MiscTests.m
//  PsiCashLibTests
//

#import <XCTest/XCTest.h>
#import "TestHelpers.h"
#import "SecretTestValues.h"
#import "RequestBuilder.h"

// Expose some private methods to help with testing
@interface PsiCash (Testing)
- (RequestBuilder*_Nonnull)createRequestBuilderFor:(NSString*_Nonnull)path
                                        withMethod:(NSString*_Nonnull)method
                                    withQueryItems:(NSArray<NSURLQueryItem*>*_Nullable)queryItems
                                 includeAuthTokens:(BOOL)includeAuthTokens;
@end


@interface MiscTests : XCTestCase

@property PsiCash *psiCash;

@end


@implementation MiscTests

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

- (void)testCreateRequestBuilder {
    // Reset the persisted request metadata, as it will affect the test results.
    [TestHelpers userInfo:self->psiCash].requestMetadata = @{};

    NSString *expectedMetadata = @"{\"attempt\":null}";

    // Start simple
    RequestBuilder *rb = [self->psiCash createRequestBuilderFor:@"/path1/path2"
                                                     withMethod:@"PATCH"
                                                 withQueryItems:nil
                                              includeAuthTokens:NO];
    NSMutableURLRequest *req = [rb request];

    XCTAssertEqualObjects(req.HTTPMethod, @"PATCH");
    XCTAssert([req.URL.absoluteString hasSuffix:@"/path1/path2"]);
    XCTAssertNil([req.URL query]);
    XCTAssertEqualObjects([req valueForHTTPHeaderField:@"User-Agent"], @"Psiphon-PsiCash-iOS");
    XCTAssertEqualObjects([req valueForHTTPHeaderField:@"X-PsiCash-Metadata"], expectedMetadata);
    XCTAssertNil([req valueForHTTPHeaderField:@"X-PsiCash-Auth"]);

    [rb setAttempt:2];

    expectedMetadata = @"{\"attempt\":2}";
    req = [rb request];
    XCTAssertEqualObjects([req valueForHTTPHeaderField:@"X-PsiCash-Metadata"], expectedMetadata);

    // Set properties in PsiCash that will end up in metadata
    [self->psiCash setRequestMetadataAtKey:@"client_region" withValue:@"CA"];
    [self->psiCash setRequestMetadataAtKey:@"client_version" withValue:@"1000000"];
    [self->psiCash setRequestMetadataAtKey:@"sponsor_id" withValue:@"mysponsor"];
    [self->psiCash setRequestMetadataAtKey:@"propagation_channel_id" withValue:@"myprop"];

    rb = [self->psiCash createRequestBuilderFor:@"/path1/path2"
                                     withMethod:@"PATCH"
                                 withQueryItems:nil
                              includeAuthTokens:NO];
    [rb setAttempt:3];
    req = [rb request];

    expectedMetadata = @"{\"attempt\":3,\"client_region\":\"CA\",\"client_version\":\"1000000\",\"propagation_channel_id\":\"myprop\",\"sponsor_id\":\"mysponsor\"}";

    XCTAssertEqualObjects([req valueForHTTPHeaderField:@"X-PsiCash-Metadata"], expectedMetadata);

    // Add query items

    NSMutableArray<NSURLQueryItem*> *queryItems = [[NSMutableArray alloc] init];
    [queryItems addObject:[NSURLQueryItem queryItemWithName:@"qp1"
                                                      value:@"qp1val"]];
    [queryItems addObject:[NSURLQueryItem queryItemWithName:@"qp2"
                                                      value:@"qp2val"]];

    rb = [self->psiCash createRequestBuilderFor:@"/path1/path2"
                                     withMethod:@"PATCH"
                                 withQueryItems:queryItems
                              includeAuthTokens:NO];
    req = [rb request];

    XCTAssertEqualObjects([req.URL query], @"qp1=qp1val&qp2=qp2val");

    // Add auth tokens

    rb = [self->psiCash createRequestBuilderFor:@"/path1/path2"
                                     withMethod:@"PATCH"
                                 withQueryItems:queryItems
                              includeAuthTokens:YES];
    req = [rb request];
    XCTAssertNotNil([req valueForHTTPHeaderField:@"X-PsiCash-Auth"]);
    XCTAssertGreaterThan([[req valueForHTTPHeaderField:@"X-PsiCash-Auth"] length], 0);
}

@end
