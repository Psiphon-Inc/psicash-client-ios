//
//  HTTPStatusCodes.h
//  PsiCashLib
//
//  Created by Adam Pritchard on 2018-03-08.
//  Copyright © 2018 Adam Pritchard. All rights reserved.
//

#ifndef HTTPStatusCodes_h
#define HTTPStatusCodes_h

// Adapted from Golang's net/http/status.go

NSInteger const kHTTPStatusContinue           = 100; // RFC 7231, 6.2.1
NSInteger const kHTTPStatusSwitchingProtocols = 101; // RFC 7231, 6.2.2
NSInteger const kHTTPStatusProcessing         = 102; // RFC 2518, 10.1

NSInteger const kHTTPStatusOK                   = 200; // RFC 7231, 6.3.1
NSInteger const kHTTPStatusCreated              = 201; // RFC 7231, 6.3.2
NSInteger const kHTTPStatusAccepted             = 202; // RFC 7231, 6.3.3
NSInteger const kHTTPStatusNonAuthoritativeInfo = 203; // RFC 7231, 6.3.4
NSInteger const kHTTPStatusNoContent            = 204; // RFC 7231, 6.3.5
NSInteger const kHTTPStatusResetContent         = 205; // RFC 7231, 6.3.6
NSInteger const kHTTPStatusPartialContent       = 206; // RFC 7233, 4.1
NSInteger const kHTTPStatusMultiStatus          = 207; // RFC 4918, 11.1
NSInteger const kHTTPStatusAlreadyReported      = 208; // RFC 5842, 7.1
NSInteger const kHTTPStatusIMUsed               = 226; // RFC 3229, 10.4.1

NSInteger const kHTTPStatusMultipleChoices   = 300; // RFC 7231, 6.4.1
NSInteger const kHTTPStatusMovedPermanently  = 301; // RFC 7231, 6.4.2
NSInteger const kHTTPStatusFound             = 302; // RFC 7231, 6.4.3
NSInteger const kHTTPStatusSeeOther          = 303; // RFC 7231, 6.4.4
NSInteger const kHTTPStatusNotModified       = 304; // RFC 7232, 4.1
NSInteger const kHTTPStatusUseProxy          = 305; // RFC 7231, 6.4.5
NSInteger const kHTTPStatus306               = 306; // RFC 7231, 6.4.6 (Unused)
NSInteger const kHTTPStatusTemporaryRedirect = 307; // RFC 7231, 6.4.7
NSInteger const kHTTPStatusPermanentRedirect = 308; // RFC 7538, 3

NSInteger const kHTTPStatusBadRequest                   = 400; // RFC 7231, 6.5.1
NSInteger const kHTTPStatusUnauthorized                 = 401; // RFC 7235, 3.1
NSInteger const kHTTPStatusPaymentRequired              = 402; // RFC 7231, 6.5.2
NSInteger const kHTTPStatusForbidden                    = 403; // RFC 7231, 6.5.3
NSInteger const kHTTPStatusNotFound                     = 404; // RFC 7231, 6.5.4
NSInteger const kHTTPStatusMethodNotAllowed             = 405; // RFC 7231, 6.5.5
NSInteger const kHTTPStatusNotAcceptable                = 406; // RFC 7231, 6.5.6
NSInteger const kHTTPStatusProxyAuthRequired            = 407; // RFC 7235, 3.2
NSInteger const kHTTPStatusRequestTimeout               = 408; // RFC 7231, 6.5.7
NSInteger const kHTTPStatusConflict                     = 409; // RFC 7231, 6.5.8
NSInteger const kHTTPStatusGone                         = 410; // RFC 7231, 6.5.9
NSInteger const kHTTPStatusLengthRequired               = 411; // RFC 7231, 6.5.10
NSInteger const kHTTPStatusPreconditionFailed           = 412; // RFC 7232, 4.2
NSInteger const kHTTPStatusRequestEntityTooLarge        = 413; // RFC 7231, 6.5.11
NSInteger const kHTTPStatusRequestURITooLong            = 414; // RFC 7231, 6.5.12
NSInteger const kHTTPStatusUnsupportedMediaType         = 415; // RFC 7231, 6.5.13
NSInteger const kHTTPStatusRequestedRangeNotSatisfiable = 416; // RFC 7233, 4.4
NSInteger const kHTTPStatusExpectationFailed            = 417; // RFC 7231, 6.5.14
NSInteger const kHTTPStatusTeapot                       = 418; // RFC 7168, 2.3.3
NSInteger const kHTTPStatusUnprocessableEntity          = 422; // RFC 4918, 11.2
NSInteger const kHTTPStatusLocked                       = 423; // RFC 4918, 11.3
NSInteger const kHTTPStatusFailedDependency             = 424; // RFC 4918, 11.4
NSInteger const kHTTPStatusUpgradeRequired              = 426; // RFC 7231, 6.5.15
NSInteger const kHTTPStatusPreconditionRequired         = 428; // RFC 6585, 3
NSInteger const kHTTPStatusTooManyRequests              = 429; // RFC 6585, 4
NSInteger const kHTTPStatusRequestHeaderFieldsTooLarge  = 431; // RFC 6585, 5
NSInteger const kHTTPStatusUnavailableForLegalReasons   = 451; // RFC 7725, 3

NSInteger const kHTTPStatusInternalServerError           = 500; // RFC 7231, 6.6.1
NSInteger const kHTTPStatusNotImplemented                = 501; // RFC 7231, 6.6.2
NSInteger const kHTTPStatusBadGateway                    = 502; // RFC 7231, 6.6.3
NSInteger const kHTTPStatusServiceUnavailable            = 503; // RFC 7231, 6.6.4
NSInteger const kHTTPStatusGatewayTimeout                = 504; // RFC 7231, 6.6.5
NSInteger const kHTTPStatusHTTPVersionNotSupported       = 505; // RFC 7231, 6.6.6
NSInteger const kHTTPStatusVariantAlsoNegotiates         = 506; // RFC 2295, 8.1
NSInteger const kHTTPStatusInsufficientStorage           = 507; // RFC 4918, 11.5
NSInteger const kHTTPStatusLoopDetected                  = 508; // RFC 5842, 7.2
NSInteger const kHTTPStatusNotExtended                   = 510; // RFC 2774, 7
NSInteger const kHTTPStatusNetworkAuthenticationRequired = 511; // RFC 6585, 6

#endif /* HTTPStatusCodes_h */

