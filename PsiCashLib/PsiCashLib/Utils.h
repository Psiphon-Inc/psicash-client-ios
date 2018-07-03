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
//  Utils.h
//  PsiCashLib
//

#ifndef Utils_h
#define Utils_h

@interface Utils : NSObject

+ (NSDate*_Nullable)dateFromISO8601String:(NSString*_Nonnull)dateString;
+ (NSString*_Nonnull)iso8601StringFromDate:(NSDate*_Nonnull)date;

+ (NSString*_Nonnull)encodeURIComponent:(NSString*_Nonnull)string;

@end

#endif /* Utils_h */
