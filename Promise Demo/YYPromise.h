//
//  YYPromise.h
//  yyoutdoorslive
//
//  Created by zhanghong on 2018/2/9.
//  Copyright © 2018年 YY. All rights reserved.
//

#import <Foundation/Foundation.h>


@class YYPromise;
typedef id (^resolveBlock)(id data);
typedef void (^rejectBlock)(NSError *error);

@interface YYPromise : NSObject

+ (instancetype)createPromise:(void(^)(resolveBlock resolve, rejectBlock reject))subscribe;
+ (instancetype)resolve:(id)data;
+ (instancetype)reject:(NSError *)error;
+ (instancetype)all:(NSArray *)array;
+ (instancetype)race:(NSArray *)array;
- (instancetype)then:(resolveBlock)onFulfilled;
- (instancetype)catchError:(rejectBlock)onRejected;

@end
