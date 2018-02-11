//
//  YYPromise.h
//  Promise Demo
//
//  Created by zhanghong on 2018/2/9.
//  Copyright © 2018年 YY. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef id (^resolveBlock)(id data);
typedef void (^rejectBlock)(NSError *error);

// 数据流协议
@protocol dataStreamProtocol
@required
- (instancetype)then:(resolveBlock)onFulfilled;
- (instancetype)catchError:(rejectBlock)onRejected;
@end

@interface YYPromise : NSObject <dataStreamProtocol>

// 具体用法可以参考 ES6 中的解释(不完全相同)
+ (instancetype)createPromise:(void(^)(resolveBlock resolve, rejectBlock reject))subscribe;
+ (instancetype)resolve:(id)data;
+ (instancetype)reject:(NSError *)error;
+ (instancetype)all:(NSArray *)array;
+ (instancetype)race:(NSArray *)array;
- (instancetype)then:(resolveBlock)onFulfilled;
- (instancetype)catchError:(rejectBlock)onRejected;

@end
