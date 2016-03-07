//
//  BackandHelpers.m
//  Parse
//
//  Created by Judd (Yehuda) Feuerstein on 2/22/16.
//  Copyright © 2016 Parse Inc. All rights reserved.
//

#import "BackandHelpers.h"
#import "PFAssert.h"
#import "PFLogging.h"


static NSString *const BackandRestKey_Id = @"id";
static NSString *const BackandRestKey_UserId = @"userId";
static NSString *const BackandRestKey_metadata = @"__metadata";
static NSString *const BackandRestKey_object = @"object";
static NSString *const BackandRestKey_collection = @"collection";

static NSString *const ParseRestKey_objectId = @"objectId";
static NSString *const ParseRestKey_type = @"__type";
static NSString *const ParseRestKey_op = @"__op";
static NSString *const ParseRestKey_className = @"className";
static NSString *const ParseRestKey_Object = @"Object";

@implementation BackandHelpers

+ (id) patchOutGoingParamsForBackand:(id)params
{
    if ([params isKindOfClass:[NSDictionary class]])
    {
        NSDictionary *paramsIn = params;

        NSString *objType = [paramsIn objectForKey:ParseRestKey_type];
        NSString *opType = [paramsIn objectForKey:ParseRestKey_op];

        if (objType)
        {
            id patchedObject;

            if ([objType isEqualToString:@"Date"])
            {
                patchedObject = [paramsIn objectForKey:@"iso"];
            }
            else if ([objType isEqualToString:@"Pointer"])
            {
                patchedObject = [paramsIn objectForKey:ParseRestKey_objectId];
            }
            else if ([objType isEqualToString:ParseRestKey_Object])
            {
                NSMutableDictionary *newObject = [paramsIn mutableCopy];
                [newObject removeObjectForKey:ParseRestKey_type];
                [newObject removeObjectForKey:ParseRestKey_className];
                patchedObject = [self patchOutGoingParamsForBackand:newObject];
            }
            else if ([objType isEqualToString:@"GeoPoint"])
            {
                patchedObject = @[paramsIn[@"latitude"],paramsIn[@"longitude"]];
            }
            else if ([objType isEqualToString:@"Relation"])
            {
                PFConsistencyAssert(NO, @"__type Relation is not yet supported for this scenario in Backand");
            }
            else if ([objType isEqualToString:@"File"])
            {
                PFConsistencyAssert(NO, @"__type File is not yet supported for Backand");
            }
            else
            {
                PFConsistencyAssert(NO, @"__type %@ is not yet supported for Backand", objType);
            }

            return patchedObject;
        }
        else if (opType)
        {
            if ([opType isEqualToString:@"AddRelation"])
            {
                NSArray *objects = [paramsIn objectForKey:@"objects"];

                return [BackandHelpers mapArray:objects usingBlock:^id(id obj) {

                    NSString *objType = [obj objectForKey:ParseRestKey_type];

                    if ([objType isEqualToString:@"Pointer"])
                    {
                        return @{BackandRestKey_metadata: @{BackandRestKey_Id: [obj objectForKey:ParseRestKey_objectId]}};
                    }
                    else if ([objType isEqualToString:ParseRestKey_Object])
                    {
                        NSMutableDictionary *newObject = [obj mutableCopy];
                        [newObject removeObjectForKey:ParseRestKey_type];
                        [newObject removeObjectForKey:ParseRestKey_className];
                        return [self patchOutGoingParamsForBackand:newObject];
                    }
                    else
                    {
                        PFConsistencyAssert(NO, @"unexpected __type %@ within __op AddRelation", objType);
                        return nil;
                    }
                }];
            }
            else
            {
                PFConsistencyAssert(NO, @"unexpected __op %@", opType);
                return nil;
            }
        }
        else
        {
            NSMutableDictionary *patchedParams = [NSMutableDictionary dictionaryWithCapacity:paramsIn.count];

            [paramsIn enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {

                NSString *newKey = key;

                if ([key isEqualToString:ParseRestKey_objectId])
                {
                    newKey = BackandRestKey_Id;
                }

                patchedParams[newKey] = [self patchOutGoingParamsForBackand:obj];
            }];

            PFConsistencyAssert(paramsIn.count == patchedParams.count, @"We must end-up with the same number of params");

            return [patchedParams copy];
        }
    }
    else if ([params isKindOfClass:[NSArray class]])
    {
        NSArray *arrayIn = params;
        return [BackandHelpers mapArray:arrayIn usingBlock:^id(id obj) {
            return [self patchOutGoingParamsForBackand:obj];
        }];
    }
    else
    {
        return params;
    }
}

+ (id) patchIncomingResponseDataFromBackand:(id)data
{
    PFLogBackandDebug(PFLoggingTagCommon, @"patchIncomingResponseDataFromBackand:\n%@", data);
    id retData = [self patchIncomingResponseDataFromBackand:data fieldInfo:nil relatedObjects:nil];
    PFLogBackandDebug(PFLoggingTagCommon, @"patched:\n%@", retData);

    return retData;
}

+ (id) patchIncomingResponseDataFromBackand:(id)data fieldInfo:(NSDictionary *)fieldInfo relatedObjects:(NSDictionary *)relatedObjects
{
    if (fieldInfo)
    {
        NSString *fieldType = fieldInfo[@"type"];

        if ([fieldType isEqualToString:@"datetime"])
        {
            return @{ParseRestKey_type:@"Date",@"iso":data};

        }

        if ([fieldType isEqualToString:@"point"])
        {
            NSArray *latLon = data;
            return @{ParseRestKey_type:@"GeoPoint",@"latitude": latLon[0],@"longitude":latLon[1]};
        }

        NSString *className = fieldInfo[BackandRestKey_object];
        if (className)
        {
            if ([data isKindOfClass:[NSNull class]] ||
                ([data isKindOfClass:[NSString class]] && ((NSString *)data).length == 0))
            {
                return [NSNull null];
            }

            if ([data isKindOfClass:[NSDictionary class]])
            {
                // must be the actual object...
                NSDictionary *patchedObj = [self patchIncomingResponseDataFromBackand:data fieldInfo:nil relatedObjects:relatedObjects];

                NSMutableDictionary *newDict = [patchedObj mutableCopy];

                newDict[ParseRestKey_type] = ParseRestKey_Object;
                newDict[ParseRestKey_className] = className;

                return [newDict copy];
            }

            if ([data isKindOfClass:[NSString class]] || [data isKindOfClass:[NSNumber class]])
            {
                // it's just the object id...
                NSString *objectId = [data description]; // if it came in as an NSNumber, description will give us a string

                NSDictionary *relatedObject = relatedObjects[className][objectId];

                if (relatedObject)
                {
                    NSDictionary *patchedObj = [self patchIncomingResponseDataFromBackand:relatedObject fieldInfo:nil relatedObjects:relatedObjects];

                    NSMutableDictionary *newDict = [patchedObj mutableCopy];

                    newDict[ParseRestKey_type] = ParseRestKey_Object;
                    newDict[ParseRestKey_className] = className;

                    return [newDict copy];
                }

                return @{ParseRestKey_type:@"Pointer",ParseRestKey_className:className,ParseRestKey_objectId:data};
            }

            PFConsistencyAssert(NO, @"Unknown object representation: %@", data);
        }

        className = fieldInfo[BackandRestKey_collection];
        if (className)
        {

            if ([data isKindOfClass:[NSNull class]] ||
                ([data isKindOfClass:[NSString class]] && ((NSString *)data).length == 0))
            {
                return @{ParseRestKey_type:@"Relation",ParseRestKey_className:className};
            }

            NSArray *objects = data;
            if (objects)
            {
                return [BackandHelpers mapArray:objects usingBlock:^id(id obj) {

                    NSDictionary *fieldInfo = @{BackandRestKey_object:className};

                    return [self patchIncomingResponseDataFromBackand:obj fieldInfo:fieldInfo relatedObjects:relatedObjects];
                }];
            }

        }

        // other field types don't need patching so data will be returned as is...
    }
    else if ([data isKindOfClass:[NSDictionary class]])
    {
        NSDictionary *dataDict = data;
        NSDictionary *metadataDict = dataDict[BackandRestKey_metadata];

        if (metadataDict)
        {
            NSMutableDictionary *patchedDict = [NSMutableDictionary dictionaryWithCapacity:dataDict.count];

            NSDictionary *fieldsDict = metadataDict[@"fields"];

            [dataDict enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {

                if (![key isEqualToString:BackandRestKey_metadata])
                {
                    if ([key isEqualToString:BackandRestKey_Id])
                    {
                        patchedDict[ParseRestKey_objectId] = [obj description];
                    }
                    else
                    {
                        NSDictionary *fieldInfo = fieldsDict[key];
                        patchedDict[key] = [self patchIncomingResponseDataFromBackand:obj fieldInfo:fieldInfo relatedObjects:relatedObjects];
                    }
                }
            }];

            PFConsistencyAssert((dataDict.count - 1) == patchedDict.count, @"We must end-up with the same number of fields (minus __metadata)");

            return [patchedDict copy];
        }
        else if (dataDict[@"data"])
        {
            // This is the top level of a query response...
            // Backand has it under "data" Parse has it under "results"

            id resultsArray = dataDict[@"data"];
            PFConsistencyAssert([resultsArray isKindOfClass:[NSArray class]], @"hmmm. expected an array of objects here...");

            relatedObjects = dataDict[@"relatedObjects"];
            PFConsistencyAssert(!relatedObjects || [relatedObjects isKindOfClass:[NSDictionary class]], @"hmmm. expected relatedObjects to be a dictionary...");

            return @{@"results":[self patchIncomingResponseDataFromBackand:resultsArray fieldInfo:nil relatedObjects:relatedObjects]};
        }
        else
        {
            // this is a response to something like login or signup...

            NSMutableDictionary *patchedDict = [dataDict mutableCopy];

            NSString *accessToken = patchedDict[@"access_token"];

            if (!accessToken)
            {
                accessToken = patchedDict[@"token"];
            }

            if (accessToken)
            {
                patchedDict[@"sessionToken"] = [NSString stringWithFormat:@"bearer %@", accessToken];
                [patchedDict removeObjectForKey:@"access_token"];
                [patchedDict removeObjectForKey:@"token_type"];
                [patchedDict removeObjectForKey:@"token"];
            }

            id userId = patchedDict[BackandRestKey_UserId];

            if (userId)
            {
                patchedDict[ParseRestKey_objectId] = [userId description];
                [patchedDict removeObjectForKey:BackandRestKey_UserId];
            }

            return [patchedDict copy];
        }
    }
    else if ([data isKindOfClass:[NSArray class]])
    {
        NSArray *arrayIn = data;
        return [BackandHelpers mapArray:arrayIn usingBlock:^id(id obj) {
            return [self patchIncomingResponseDataFromBackand:obj fieldInfo:nil relatedObjects:relatedObjects];
        }];
    }

    return data;
}

+ (NSString*) queryStringFromParams:(NSDictionary *)params
{
    NSMutableArray *paramsArray = [[NSMutableArray alloc] initWithCapacity:params.count];

    for (NSString *key in params.allKeys)
    {
        NSObject *val = params[key];

        NSString *valStr = [val description];

        [paramsArray addObject:[NSString stringWithFormat:@"%@=%@", key, valStr]];
    }

    NSString *paramsStr = [paramsArray componentsJoinedByString:@"&"];

    return paramsStr;
}

+ (NSString *) jsonStringFromParams:(NSDictionary *)params
{
    NSError *error = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:params
                                                       options:(NSJSONWritingOptions)0
                                                         error:&error];
    PFConsistencyAssert(error == nil, @"Failed to serialize JSON with error = %@", error);

    return [[NSString alloc]initWithData:jsonData encoding:NSUTF8StringEncoding];
}

//+ (NSString *) urlEncode:(NSString *)input
//{
//    NSMutableString *output = [NSMutableString string];
//    const unsigned char *source = (const unsigned char *)[input UTF8String];
//    NSUInteger sourceLen = strlen((const char *)source);
//    for (int i = 0; i < sourceLen; ++i) {
//        const unsigned char thisChar = source[i];
//        if (thisChar == ' '){
//            [output appendString:@"+"];
//        } else if (thisChar == '.' || thisChar == '-' || thisChar == '_' || thisChar == '~' ||
//                   (thisChar >= 'a' && thisChar <= 'z') ||
//                   (thisChar >= 'A' && thisChar <= 'Z') ||
//                   (thisChar >= '0' && thisChar <= '9')) {
//            [output appendFormat:@"%c", thisChar];
//        } else {
//            [output appendFormat:@"%%%02X", thisChar];
//        }
//    }
//    return output;
//}

+ (NSArray *) mapArray:(NSArray *)arrayIn usingBlock:(AnArrayMappingBlock)mappingBlock
{
    NSArray *retArray = arrayIn;
    
    if (mappingBlock)
    {
        NSMutableArray *newArray = [[NSMutableArray alloc] initWithCapacity:arrayIn.count];
        
        for (id obj in arrayIn)
        {
            id mappedObj = mappingBlock(obj);
            
            [newArray addObject:mappedObj];
        }
        
        retArray = newArray;
    }
    
    return retArray;
}

@end
