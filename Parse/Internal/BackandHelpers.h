//
//  BackandHelpers.h
//  Parse
//
//  Created by Judd (Yehuda) Feuerstein on 2/22/16.
//  Copyright © 2016 Parse Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <PFConstants.h>

@interface BackandHelpers : NSObject

typedef id (^AnArrayMappingBlock)(id obj);

+ (id) patchOutGoingParamsForBackand:(id)params;
+ (id) patchIncomingResponseDataFromBackand:(id)data;

+ (NSString*) queryStringFromParams:(NSDictionary *)params;
+ (NSString *) jsonStringFromParams:(NSDictionary *)params;
//+ (NSString *) urlEncode:(NSString *)input;
+ (NSArray *) mapArray:(NSArray *)arrayIn usingBlock:(AnArrayMappingBlock)mappingBlock;

@end
