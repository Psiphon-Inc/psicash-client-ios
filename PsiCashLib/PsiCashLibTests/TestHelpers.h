//
//  TestHelpers.h
//  PsiCashLib
//
//  Created by Adam Pritchard on 2018-03-10.
//  Copyright © 2018 Adam Pritchard. All rights reserved.
//

#ifndef TestHelpers_h
#define TestHelpers_h

#import <PsiCashLib/PsiCashLib.h>

@interface TestHelpers : NSObject

+ (void)make1TRewardRequest:(PsiCash*_Nonnull)psiCash
                 completion:(void (^_Nonnull)(BOOL success))completionHandler;

@end


#endif /* TestHelpers_h */
