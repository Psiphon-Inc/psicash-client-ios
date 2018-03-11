//
//  TestHelpers.m
//  PsiCashLibTests
//
//  Created by Adam Pritchard on 2018-03-10.
//  Copyright © 2018 Adam Pritchard. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "TestHelpers.h"
#import "SecretTestValues.h" // This file is in CipherShare

@implementation TestHelpers

+ (void)make1TRewardRequest:(PsiCash*_Nonnull)psiCash
                 completion:(void (^_Nonnull)(BOOL success))completionHandler
{
    NSMutableArray *queryItems = [NSMutableArray new];
    [queryItems addObject:[NSURLQueryItem queryItemWithName:@"class"
                                                      value:@TEST_CREDIT_TRANSACTION_CLASS]];
    [queryItems addObject:[NSURLQueryItem queryItemWithName:@"distinguisher"
                                                      value:@"1trillion-1second"]];
    
    NSMutableURLRequest *request = [psiCash createRequestFor:@"/new-transaction"
                                                  withMethod:@"POST"
                                              withQueryItems:queryItems
                                           includeAuthTokens:YES];
    
    NSURLSession *session = [NSURLSession sharedSession];
    
    NSURLSessionDataTask *task = [session dataTaskWithRequest:request
                                            completionHandler:
                                  ^(NSData *data, NSURLResponse *response, NSError *error)
                                  {
                                      if (error) {
                                          NSLog(@"make1TRewardRequest error: %@", error);
                                          completionHandler(NO);
                                          return;
                                      }
                                      
                                      NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse*)response;
                                      
                                      completionHandler(httpResponse.statusCode == kHTTPStatusOK);
                                  }];
    [task resume];
}


@end

