/**
 * Copyright (c) 2015-present, Parse, LLC.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "PFRESTUserCommand.h"

#import "PFAssert.h"
#import "PFHTTPRequest.h"
#import "Parse.h"
#import "Parse_Private.h"
#import "ParseManager.h"
#import "PFHTTPURLRequestConstructor.h"

static NSString *const PFRESTUserCommandRevocableSessionHeader = @"X-Parse-Revocable-Session";
static NSString *const PFRESTUserCommandRevocableSessionHeaderEnabledValue = @"1";

@interface PFRESTUserCommand ()

@property (nonatomic, assign, readwrite) BOOL revocableSessionEnabled;

@end

@implementation PFRESTUserCommand

///--------------------------------------
#pragma mark - Init
///--------------------------------------

+ (instancetype)_commandWithHTTPPath:(NSString *)path
                          httpMethod:(NSString *)httpMethod
                          parameters:(NSDictionary *)parameters
                        sessionToken:(NSString *)sessionToken
                    revocableSession:(BOOL)revocableSessionEnabled {
    PFRESTUserCommand *command = [self commandWithHTTPPath:path
                                                httpMethod:httpMethod
                                                parameters:parameters
                                              sessionToken:sessionToken];
    if (revocableSessionEnabled) {
        command.additionalRequestHeaders = @{ PFRESTUserCommandRevocableSessionHeader :
                                                  PFRESTUserCommandRevocableSessionHeaderEnabledValue};
    }
    command.revocableSessionEnabled = revocableSessionEnabled;
    return command;
}

+ (instancetype)ba_commandWithHTTPPath:(NSString *)path
                             httpMethod:(NSString *)httpMethod
                             parameters:(NSDictionary *)parameters
                           sessionToken:(NSString *)sessionToken
                       revocableSession:(BOOL)revocableSessionEnabled {
    PFRESTUserCommand *command = [self ba_commandWithHTTPPath:path
                                                   httpMethod:httpMethod
                                                   parameters:parameters
                                                 sessionToken:sessionToken];

    if (revocableSessionEnabled) {
        command.additionalRequestHeaders = @{ PFRESTUserCommandRevocableSessionHeader :
                                                  PFRESTUserCommandRevocableSessionHeaderEnabledValue};
    }
    command.revocableSessionEnabled = revocableSessionEnabled;

    return command;
}

///--------------------------------------
#pragma mark - Log In
///--------------------------------------

+ (instancetype)logInUserCommandWithUsername:(NSString *)username
                                    password:(NSString *)password
                            revocableSession:(BOOL)revocableSessionEnabled {

    if ([Parse usingBackand])
    {
        NSDictionary *parameters = @{ @"username" : username,
                                      @"password" : password,
                                      @"grant_type" : @"password",
                                      @"appName" : [Parse getApplicationId]};

        NSString *baseUrl = [Parse _currentManager].configuration.server;
        
        if ([baseUrl hasSuffix:@"/1"])
        {
            baseUrl = [baseUrl substringToIndex:(baseUrl.length - 2)];
        }

        NSString *loginUrl = [NSString stringWithFormat:@"%@/token", baseUrl];

        PFRESTUserCommand *command = [self ba_commandWithHTTPPath:loginUrl
                                                        httpMethod:PFHTTPRequestMethodPOST
                                                        parameters:parameters
                                                      sessionToken:nil
                                                  revocableSession:revocableSessionEnabled];

        command.additionalRequestHeaders = @{ PFHTTPRequestHeaderNameContentType :
                                                  PFHTTPURLRequestContentTypeFormUrlEncoded};

        return command;
    }
    else
    {
        NSDictionary *parameters = @{ @"username" : username,
                                      @"password" : password };
        return [self ba_commandWithHTTPPath:@"login"
                                  httpMethod:PFHTTPRequestMethodGET
                                  parameters:parameters
                                sessionToken:nil
                            revocableSession:revocableSessionEnabled];
    }
}

+ (instancetype)serviceLoginUserCommandWithAuthenticationType:(NSString *)authenticationType
                                           authenticationData:(NSDictionary *)authenticationData
                                             revocableSession:(BOOL)revocableSessionEnabled {
    NSDictionary *parameters = @{ @"authData" : @{ authenticationType : authenticationData } };
    return [self serviceLoginUserCommandWithParameters:parameters
                                      revocableSession:revocableSessionEnabled
                                          sessionToken:nil];
}

+ (instancetype)serviceLoginUserCommandWithParameters:(NSDictionary *)parameters
                                     revocableSession:(BOOL)revocableSessionEnabled
                                         sessionToken:(NSString *)sessionToken {
    return [self _commandWithHTTPPath:@"users"
                           httpMethod:PFHTTPRequestMethodPOST
                           parameters:parameters
                         sessionToken:sessionToken
                     revocableSession:revocableSessionEnabled];
}

///--------------------------------------
#pragma mark - Sign Up
///--------------------------------------

+ (instancetype)signUpUserCommandWithParameters:(NSDictionary *)parameters
                               revocableSession:(BOOL)revocableSessionEnabled
                                   sessionToken:(NSString *)sessionToken {

    if ([Parse usingBackand])
    {
        NSDictionary *ba_parameters = @{ @"firstName" : parameters[@"username"],
                                         @"lastName": parameters[@"username"],
                                         @"email": parameters[@"email"],
                                         @"password" : parameters[@"password"],
                                         @"confirmPassword" : parameters[@"password"]};

        PFRESTUserCommand *command = [self ba_commandWithHTTPPath:@"user/signup"
                                                       httpMethod:PFHTTPRequestMethodPOST
                                                       parameters:ba_parameters
                                                     sessionToken:sessionToken
                                                 revocableSession:revocableSessionEnabled];

        command.additionalRequestHeaders = @{ @"SignUpToken" : [Parse getBackandSignupToken]};

        return command;
    }
    else
    {
        return [self ba_commandWithHTTPPath:@"users"
                                 httpMethod:PFHTTPRequestMethodPOST
                                 parameters:parameters
                               sessionToken:sessionToken
                           revocableSession:revocableSessionEnabled];
    }
}

///--------------------------------------
#pragma mark - Current User
///--------------------------------------

+ (instancetype)getCurrentUserCommandWithSessionToken:(NSString *)sessionToken {
    return [self commandWithHTTPPath:@"users/me"
                          httpMethod:PFHTTPRequestMethodGET
                          parameters:nil
                        sessionToken:sessionToken];
}

+ (instancetype)upgradeToRevocableSessionCommandWithSessionToken:(NSString *)sessionToken {
    return [self commandWithHTTPPath:@"upgradeToRevocableSession"
                          httpMethod:PFHTTPRequestMethodPOST
                          parameters:nil
                        sessionToken:sessionToken];
}

+ (instancetype)logOutUserCommandWithSessionToken:(NSString *)sessionToken {
    return [self commandWithHTTPPath:@"logout"
                          httpMethod:PFHTTPRequestMethodPOST
                          parameters:nil
                        sessionToken:sessionToken];
}

///--------------------------------------
#pragma mark - Additional User Commands
///--------------------------------------

+ (instancetype)resetPasswordCommandForUserWithEmail:(NSString *)email {
    return [self commandWithHTTPPath:@"requestPasswordReset"
                          httpMethod:PFHTTPRequestMethodPOST
                          parameters:@{ @"email" : email }
                        sessionToken:nil];
}

@end
