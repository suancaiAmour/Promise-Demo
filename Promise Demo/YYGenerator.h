//
//  YYGenerator.h
//  Promise Demo
//
//  Created by zhanghong on 2018/2/13.
//  Copyright © 2018年 zhanghong. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface YYGenerator : NSObject

+ (instancetype)createGenrator:(id(^)(id data))genratorBlock;
- (id)next:(id)data;

id yield(id data);


@end
