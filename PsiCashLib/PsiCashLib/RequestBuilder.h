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
//  RequestBuilder.h
//  PsiCashLib
//

#ifndef RequestBuilder_h
#define RequestBuilder_h

@interface RequestBuilder : NSObject

- (id)initWithPath:(NSString*_Nonnull)path
            method:(NSString*_Nonnull)method
            scheme:(NSString*_Nonnull)scheme
          hostname:(NSString*_Nonnull)hostname
              port:(NSNumber*_Nonnull)port
        queryItems:(NSArray<NSURLQueryItem*>*_Nullable)queryItems
           headers:(NSDictionary<NSString*,NSString*>*_Nullable)headers
           metadata:(NSDictionary*_Nonnull)metadata
           timeout:(NSTimeInterval)timeout;

- (void)setAttempt:(NSUInteger)attempt; // one-based

- (void)addHeaders:(NSDictionary<NSString*,NSString*>*_Nullable)headers;

- (NSMutableURLRequest*_Nonnull)request;

@end

#endif /* RequestBuilder_h */
