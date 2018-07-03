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
//  Utils.m
//  PsiCashLib
//

#import <Foundation/Foundation.h>
#import "Utils.h"

@implementation Utils

+ (NSDate*_Nullable)dateFromISO8601String:(NSString*_Nonnull)dateString
{
    // NOTE: NSISO8601DateFormatter totally fails when the date has milliseconds,
    // so we're not using it. http://www.openradar.me/29609526

    // From https://stackoverflow.com/a/17559601/729729
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    // Always use this locale when parsing fixed format date strings
    NSLocale *posix = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
    [formatter setLocale:posix];
    [formatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ"];
    NSDate *date = [formatter dateFromString:dateString];

    return date;
}

+ (NSString*_Nonnull)iso8601StringFromDate:(NSDate*_Nonnull)date
{
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    // Always use this locale when parsing fixed format date strings
    NSLocale *posix = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
    [formatter setLocale:posix];
    formatter.timeZone = [NSTimeZone timeZoneWithAbbreviation: @"UTC"];
    [formatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ"];
    return [formatter stringFromDate:date];
}

+ (NSString*_Nonnull)encodeURIComponent:(NSString*_Nonnull)string
{
    // We're being overly restrictive on allowed characters, but that should be
    // fine and safe for both query params and fragments/anchors.
    NSCharacterSet *allowedChars = [NSCharacterSet alphanumericCharacterSet];
    NSString *encoded = [string stringByAddingPercentEncodingWithAllowedCharacters:allowedChars];
    return encoded;
}

@end
