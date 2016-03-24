/**
 * Copyright (c) 2015-present, Parse, LLC.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "PFRESTCloudCommand.h"

#import "PFAssert.h"
#import "PFHTTPRequest.h"
#import "Parse.h"
#import "BackandHelpers.h"

@implementation PFRESTCloudCommand

+ (instancetype)commandForFunction:(NSString *)function
                    withParameters:(NSDictionary *)parameters
                      sessionToken:(NSString *)sessionToken {

    if ([Parse usingBackand])
    {
        NSString *httpPath = [NSString stringWithFormat:@"objects/action/__CloudCode?name=%@", function];

        NSString *query = nil;

        if (parameters.count > 0)
        {
            NSDictionary *func_parameters = @{@"parameters":[BackandHelpers jsonStringFromParams:parameters]};
            query = [BackandHelpers queryStringFromParams:func_parameters];
        }
        parameters = nil; // A non nil parameters (even if empty) truns the GET into a POST. Backand only responds to a GET in this case.

        PFRESTCloudCommand *command = [self ba_commandWithHTTPPath:httpPath
                                                         httpQuery:query
                                                        httpMethod:PFHTTPRequestMethodGET
                                                        parameters:parameters
                                                  operationSetUUID:nil
                                                      sessionToken:sessionToken];
        return command;
    }
    else
    {
        NSString *path = [NSString stringWithFormat:@"functions/%@", function];
        return [self commandWithHTTPPath:path
                              httpMethod:PFHTTPRequestMethodPOST
                              parameters:parameters
                            sessionToken:sessionToken];
    }
}

@end
