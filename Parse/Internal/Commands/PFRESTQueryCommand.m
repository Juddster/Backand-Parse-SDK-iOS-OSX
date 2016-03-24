/**
 * Copyright (c) 2015-present, Parse, LLC.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "PFRESTQueryCommand.h"

#import "PFAssert.h"
#import "PFEncoder.h"
#import "PFHTTPRequest.h"
#import "PFQueryPrivate.h"
#import "PFQueryState.h"
#import "Parse.h"
#import "BackandHelpers.h"
#import "Parse_Private.h"
#import "PFRelation.h"

@implementation PFRESTQueryCommand

///--------------------------------------
#pragma mark - Find
///--------------------------------------

+ (instancetype)findCommandForQueryState:(PFQueryState *)queryState withSessionToken:(NSString *)sessionToken {
    NSDictionary *parameters = [self findCommandParametersForQueryState:queryState];
    return [self _findCommandForClassWithName:queryState.parseClassName
                                   parameters:parameters
                                 sessionToken:sessionToken];
}

+ (instancetype)findCommandForClassWithName:(NSString *)className
                                      order:(NSString *)order
                                 conditions:(NSDictionary *)conditions
                               selectedKeys:(NSSet *)selectedKeys
                               includedKeys:(NSSet *)includedKeys
                                      limit:(NSInteger)limit
                                       skip:(NSInteger)skip
                               extraOptions:(NSDictionary *)extraOptions
                             tracingEnabled:(BOOL)trace
                               sessionToken:(NSString *)sessionToken {
    NSDictionary *parameters = [self findCommandParametersWithOrder:order
                                                         conditions:conditions
                                                       selectedKeys:selectedKeys
                                                       includedKeys:includedKeys
                                                              limit:limit
                                                               skip:skip
                                                       extraOptions:extraOptions
                                                     tracingEnabled:trace
                                                        nestedQuery:NO];
    return [self _findCommandForClassWithName:className
                                   parameters:parameters
                                 sessionToken:sessionToken];
}

+ (NSString *)apiPath
{
    return ([Parse usingBackand] ? @"objects" : @"classes");
}

+ (instancetype)_findCommandForClassWithName:(NSString *)className
                                  parameters:(NSDictionary *)parameters
                                sessionToken:(NSString *)sessionToken
{
    NSString *httpPath = [NSString stringWithFormat:@"%@/%@?relatedObjects=true", [self apiPath], className];

    NSString *query = nil;

    if ([Parse usingBackand] && parameters)
    {
        if (parameters.count > 0)
        {
            query = [BackandHelpers queryStringFromParams:parameters];
        }
        parameters = nil; // A non nil parameters (even if empty) truns the GET into a POST. Backand only responds to a GET in this case.
    }

    PFRESTQueryCommand *command = [self ba_commandWithHTTPPath:httpPath
                                                     httpQuery:query
                                                    httpMethod:PFHTTPRequestMethodGET
                                                    parameters:parameters
                                              operationSetUUID:nil
                                                  sessionToken:sessionToken];
    return command;
}

///--------------------------------------
#pragma mark - Count
///--------------------------------------

+ (instancetype)countCommandFromFindCommand:(PFRESTQueryCommand *)findCommand {
    NSMutableDictionary *parameters = [findCommand.parameters mutableCopy];
    parameters[@"count"] = @"1";
    parameters[@"limit"] = @"0"; // Set the limit to 0, as we are not interested in results at all.
    [parameters removeObjectForKey:@"skip"];

    return [self commandWithHTTPPath:findCommand.httpPath
                          httpMethod:findCommand.httpMethod
                          parameters:[parameters copy]
                        sessionToken:findCommand.sessionToken];
}

///--------------------------------------
#pragma mark - Parameters
///--------------------------------------

+ (NSDictionary *)findCommandParametersForQueryState:(PFQueryState *)queryState {
    return [self findCommandParametersWithOrder:queryState.sortOrderString
                                     conditions:queryState.conditions
                                   selectedKeys:queryState.selectedKeys
                                   includedKeys:queryState.includedKeys
                                          limit:queryState.limit
                                           skip:queryState.skip
                                   extraOptions:queryState.extraOptions
                                 tracingEnabled:queryState.trace
                                    nestedQuery:NO];
}

#define BACKAND_QUERY_UNSUPPORTED [PFRESTQueryCommand assertOnBackand]

+ (void) assertOnBackand
{
    PFParameterAssert(![Parse usingBackand], @"Backand doesn't support this type of query yet");
}

+ (NSDictionary *)findCommandParametersWithOrder:(NSString *)order
                                      conditions:(NSDictionary *)conditions
                                    selectedKeys:(NSSet *)selectedKeys
                                    includedKeys:(NSSet *)includedKeys
                                           limit:(NSInteger)limit
                                            skip:(NSInteger)skip
                                    extraOptions:(NSDictionary *)extraOptions
                                  tracingEnabled:(BOOL)trace
                                     nestedQuery:(BOOL)nestedQuery
{
    NSMutableDictionary *parameters = [NSMutableDictionary dictionary];

    BOOL usingBackand = [Parse usingBackand];

    if (order.length)
    {
        if (usingBackand)
        {
            // order comes in as something like: -destination,id,-jobs
            // for Backand we need to convert it to an array like: [ {"fieldName": "destination", "order": "desc"  }, ...]

            NSArray *orderParts = [order componentsSeparatedByString:@","];
            orderParts = [BackandHelpers mapArray:orderParts usingBlock:^id(id obj) {
                NSString *part = (NSString *)obj;

                BOOL isDecending = [part hasPrefix:@"-"];
                if (isDecending)
                {
                    part = [part substringFromIndex:1];
                }

                NSString *backandPart = [NSString stringWithFormat:@"{\"fieldName\":\"%@\",\"order\":\"%@\"}", part, (isDecending?@"desc":@"asc")];

                return backandPart;
            }];

            NSString *orderParam = [NSString stringWithFormat:@"[%@]", [orderParts componentsJoinedByString:@","]];

            parameters[@"sort"] = orderParam;
        }
        else
        {
            parameters[@"order"] = order;
        }

    }
    if (selectedKeys)
    {
        BACKAND_QUERY_UNSUPPORTED;
        NSArray *sortDescriptors = @[ [NSSortDescriptor sortDescriptorWithKey:@"self" ascending:YES selector:@selector(compare:)] ];
        NSArray *keysArray = [selectedKeys sortedArrayUsingDescriptors:sortDescriptors];
        NSString *parametersKey = (usingBackand ? @"fields" : @"keys");
        parameters[parametersKey] = [keysArray componentsJoinedByString:@","];
    }
    if (includedKeys.count > 0)
    {
        // ignore this. For now we unconditionally call the REST API with &relatedObjects=true

        //        NSArray *sortDescriptors = @[ [NSSortDescriptor sortDescriptorWithKey:@"self" ascending:YES selector:@selector(compare:)] ];
        //        NSArray *keysArray = [includedKeys sortedArrayUsingDescriptors:sortDescriptors];
        //        parameters[@"include"] = [keysArray componentsJoinedByString:@","];
    }
    if (limit >= 0)
    {
        BACKAND_QUERY_UNSUPPORTED;
        parameters[@"limit"] = [NSString stringWithFormat:@"%d", (int)limit];
    }
    if (skip > 0)
    {
        BACKAND_QUERY_UNSUPPORTED;
        parameters[@"skip"] = [NSString stringWithFormat:@"%d", (int)skip];
    }
    if (trace)
    {
        BACKAND_QUERY_UNSUPPORTED;
        // TODO: (nlutsenko) Double check that tracing still works. Maybe create test for it.
        parameters[@"trace"] = @"1";
    }

    if (extraOptions.count > 0)
    {
        BACKAND_QUERY_UNSUPPORTED;
        [extraOptions enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
            parameters[key] = obj;
        }];
    }

    if (conditions.count > 0)
    {
        NSMutableDictionary *whereData = [[NSMutableDictionary alloc] init];

        [conditions enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
            if ([key isEqualToString:@"$or"])
            {
                NSArray *array = (NSArray *)obj;
                NSMutableArray *newArray = [NSMutableArray array];
                for (PFQuery *subquery in array)
                {
                    // TODO: (nlutsenko) Move this validation into PFQuery/PFQueryState.
                    PFParameterAssert(subquery.state.limit < 0, @"OR queries do not support sub queries with limits");
                    PFParameterAssert(subquery.state.skip == 0, @"OR queries do not support sub queries with skip");
                    PFParameterAssert(subquery.state.sortKeys.count == 0, @"OR queries do not support sub queries with order");
                    PFParameterAssert(subquery.state.includedKeys.count == 0, @"OR queries do not support sub-queries with includes");
                    PFParameterAssert(subquery.state.selectedKeys == nil, @"OR queries do not support sub-queries with selectKeys");

                    NSDictionary *queryDict = [self findCommandParametersWithOrder:subquery.state.sortOrderString
                                                                        conditions:subquery.state.conditions
                                                                      selectedKeys:subquery.state.selectedKeys
                                                                      includedKeys:subquery.state.includedKeys
                                                                             limit:subquery.state.limit
                                                                              skip:subquery.state.skip
                                                                      extraOptions:nil
                                                                    tracingEnabled:NO
                                                                       nestedQuery:YES];

                    queryDict = queryDict[@"where"];

                    if (queryDict.count > 0) {
                        [newArray addObject:queryDict];
                    } else {
                        [newArray addObject:@{}];
                    }
                }
                whereData[key] = newArray;
            }
            if (usingBackand && [key isEqualToString:@"$relatedTo"])
            {
                PFObject *pfObject = obj[@"object"];
                NSString *relationField = obj[@"key"];
                PFRelation *pfRelation = pfObject[relationField];
                NSString *viaField = pfRelation.viaField;

                PFParameterAssert(viaField, @"Missing viaField on the PFRelation object");

                whereData[viaField] = pfObject.objectId;
            }
            else
            {
                id object = [self _encodeSubqueryIfNeeded:obj];
                whereData[key] = [[PFPointerObjectEncoder objectEncoder] encodeObject:object];
            }
        }];

        if (usingBackand && !nestedQuery)
        {
            id patchedWhereData = [BackandHelpers patchOutGoingParamsForBackand:whereData];
            parameters[@"filter"] = [BackandHelpers jsonStringFromParams:@{@"q":patchedWhereData}];
        }
        else
        {
            parameters[@"where"] = whereData;
        }
    }

    return parameters;
}

+ (id)_encodeSubqueryIfNeeded:(id)object
{
    if (![object isKindOfClass:[NSDictionary class]])
    {
        return object;
    }

    NSMutableDictionary *parameters = [NSMutableDictionary dictionaryWithCapacity:[object count]];

    [object enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {

        if ([obj isKindOfClass:[PFQuery class]])
        {

            BACKAND_QUERY_UNSUPPORTED;

            PFQuery *subquery = (PFQuery *)obj;
            NSMutableDictionary *subqueryParameters = [[self findCommandParametersWithOrder:subquery.state.sortOrderString
                                                                                 conditions:subquery.state.conditions
                                                                               selectedKeys:subquery.state.selectedKeys
                                                                               includedKeys:subquery.state.includedKeys
                                                                                      limit:subquery.state.limit
                                                                                       skip:subquery.state.skip
                                                                               extraOptions:subquery.state.extraOptions
                                                                             tracingEnabled:NO
                                                                                nestedQuery:NO] mutableCopy];
            subqueryParameters[@"className"] = subquery.parseClassName;
            obj = subqueryParameters;
        }
        else if ([obj isKindOfClass:[NSDictionary class]])
        {
            obj = [self _encodeSubqueryIfNeeded:obj];
        }
        
        parameters[key] = obj;
    }];
    
    return parameters;
}

@end
