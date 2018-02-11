//
//  ViewController.m
//  Promise Demo
//
//  Created by zhanghong on 2018/2/11.
//  Copyright © 2018年 zhanghong. All rights reserved.
//

#import "ViewController.h"
#import "YYPromise.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self test2];
}

- (void)test0 {
    [[[[YYPromise createPromise:^(resolveBlock resolve, rejectBlock reject) {
        // 先来个同步的
        resolve(@1);
//        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
//            reject([NSError errorWithDomain:@"123" code:2 userInfo:@{}]);
//        });
    }] then:^id(id data) {
        NSLog(@"%@", data);
        return [YYPromise createPromise:^(resolveBlock resolve, rejectBlock reject) {
            // 再来个异步的
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(4 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                resolve(@2);
            });
        }];
    }] then:^id(id data) {
        NSLog(@"%@", data);
        // 不返回一个 Promise 就变成同步的啦
        return @3;
    }] catchError:^(NSError *error) {
        NSLog(@"error %@", error);
    }];
}

- (void)test1 {
    YYPromise *promise0 = [YYPromise createPromise:^(resolveBlock resolve, rejectBlock reject) {
        // 先来个同步的
//                resolve(@1);
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            reject([NSError errorWithDomain:@"123" code:2 userInfo:@{}]);
        });
    }];
    
    // 多处监听
    [promise0 then:^id(id data) {
        NSLog(@"%@", data);
        return NULL;
    }];
    
    [promise0 then:^id(id data) {
        NSLog(@"%@", data);
        return NULL;
    }];
    
    [promise0 catchError:^(NSError *error) {
        NSLog(@"error %@", error);
    }];
    
    [promise0 catchError:^(NSError *error) {
        NSLog(@"error %@", error);
    }];
}

- (void)test2 {
    YYPromise *promise0 = [YYPromise createPromise:^(resolveBlock resolve, rejectBlock reject) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(4 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
//            resolve(@1);
            reject([NSError errorWithDomain:@"233" code:2 userInfo:@{}]);
        });
    }];
    
    YYPromise *promise1 = [YYPromise createPromise:^(resolveBlock resolve, rejectBlock reject) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(6 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            resolve(@2);
        });
    }];
    
    YYPromise *promise2 = [YYPromise createPromise:^(resolveBlock resolve, rejectBlock reject) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            resolve(@3);
        });
    }];
    
    [[[YYPromise race:@[promise0, promise1, promise2]] then:^id(id data) {
        NSLog(@"%@", data);
        return NULL;
    }] catchError:^(NSError *error) {
        NSLog(@"error %@", error);
    }];
}

@end
