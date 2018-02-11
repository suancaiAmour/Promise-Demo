//
//  YYPromise.m
//  Promise Demo
//
//  Created by zhanghong on 2018/2/9.
//  Copyright © 2018年 YY. All rights reserved.
//

#import "YYPromise.h"

// Promise 的状态
typedef NS_ENUM(NSUInteger, PromiseState) {
    PromiseStatePending = 0, // 进行中
    PromiseStateFulfilled, // 已成功
    PromiseStateRejected, // 已失败
};

#pragma mark - HandleObject
@interface HandleObject : NSObject

@property (nonatomic, copy) resolveBlock onFulfilled; // 外部未出错时执行的 block
@property (nonatomic, copy) resolveBlock resolve; // then/catchError Promise 的 resolve
@property (nonatomic, copy) rejectBlock onRejected; // 外部出错时执行的 block
@property (nonatomic, copy) rejectBlock reject; // then/catchError Promise 的 reject

@end
@implementation HandleObject
@end

#pragma mark - YYPromise
@interface YYPromise ()

@property (nonatomic, copy) resolveBlock resolve;
@property (nonatomic, copy) rejectBlock  reject;

// promise 所处的状态
@property (nonatomic, assign) PromiseState state;

// promise resolve 接收到数据
@property (nonatomic, strong) id data;

@property (nonatomic, strong) NSMutableArray<__kindof HandleObject *> *deferreds;

// 用于调试
@property (nonatomic, copy) NSString *name;


@end

@implementation YYPromise

/*
// Promise 的数据流动链为(注意 -> 表示多条分支，不止表示一条分支，当然也可能只有一条分支)：
//        第一个 Promise 的 resolve/reject -> then/catchError 中的 Promise 的 resolve/reject -> then/catchError 中的 Promise 的 resolve/reject ......
//
*/

#pragma mark - init
+ (instancetype)createPromise:(void (^)(resolveBlock resolve, rejectBlock reject))subscribe  state:(PromiseState)state name:(NSString *)name  {
    YYPromise *promise = [[YYPromise alloc] init];
    promise.name = name;
    promise.state = state;
    subscribe(promise.resolve, promise.reject);
    static NSUInteger num = 0;
    num++;
    NSLog(@"%@ : %@", promise, [NSString stringWithFormat:@"Promise create %ld", num]);
    return promise;
}

+ (instancetype)createPromise:(void (^)(resolveBlock resolve, rejectBlock reject))subscribe name:(NSString *)name {
    return [self createPromise:subscribe state:PromiseStatePending name:name];
}

+ (instancetype)createPromise:(void (^)(resolveBlock resolve, rejectBlock reject))subscribe {
    return [self createPromise:subscribe state:PromiseStatePending name:@"Promise from create"];
}

+ (instancetype)resolve:(id)data {
    return [self createPromise:^(resolveBlock resolve, rejectBlock reject) {
        resolve(data);
    } name:@"Promise from resolve"];
}

+ (instancetype)reject:(NSError *)error {
    return [self createPromise:^(resolveBlock resolve, rejectBlock reject) {
        reject(error);
    } name:@"Promise from reject"];
}

+ (instancetype)all:(NSArray *)array {
    return [self createPromise:^(resolveBlock resolve, rejectBlock reject) {
        // 不知为何使用 NSPointArray 弱引用 Promise 没有释放  既然如此 我只能 removeAllObjects 来手动释放
        NSMutableArray *promiseArray = [[self arrayContent2Promise:array] mutableCopy];
        NSMutableArray *resultArray = [NSMutableArray arrayWithCapacity:promiseArray.count];
        // 释放所有的 Promise
        void (^releaseAllPromise)(NSMutableArray *array) = ^(NSMutableArray *array){
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
                [array removeAllObjects];
            });
        };
        for (YYPromise *obj in promiseArray) {
            [resultArray addObject:[NSNull null]];
            __weak typeof(resolve) weakResolve = resolve;
            __weak typeof(obj) weakObj = obj;
            [obj then:^id(id data) {
                __strong typeof(weakResolve) resolve = weakResolve;
                __strong typeof(weakObj) obj = weakObj;
                if (resolve) {
                    [resultArray replaceObjectAtIndex:[promiseArray indexOfObject:obj] withObject:data];
                    for (id object in resultArray) {
                        if ([object isKindOfClass:[NSNull class]]) {
                            return NULL;
                        }
                    }
                    resolve([resultArray copy]);
                    releaseAllPromise(promiseArray);
                }
                return NULL;
            }];
            __weak typeof(reject) weakReject = reject;
            [obj catchError:^(NSError *error) {
                __strong typeof(weakReject) reject = weakReject;
                // 这里不事先判断 reject 是否还存在 是因为上面的 resolve 触发后就不可能再触发这个 reject
                reject(error);
                releaseAllPromise(promiseArray);
            }];
        }
    } name:@"Promise from all"];
}

+ (instancetype)race:(NSArray *)array {
    return [YYPromise createPromise:^(resolveBlock resolve, rejectBlock reject) {
        NSMutableArray *promiseArray = [[self arrayContent2Promise:array] mutableCopy];
        // 释放所有的 Promise
        void (^releaseAllPromise)(NSMutableArray *array) = ^(NSMutableArray *array){
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
                [array removeAllObjects];
            });
        };
        for (YYPromise *obj in promiseArray) {
            __weak typeof(resolve) weakResolve = resolve;
            [obj then:^id(id data) {
                __strong typeof(weakResolve) resolve = weakResolve;
                // resolve 不存在 说明前面已经 resolve/reject 了 Promise 已经被释放了
                if (resolve) {
                    resolve(data);
                    releaseAllPromise(promiseArray);
                }
                return NULL;
            }];
            __weak typeof(reject) weakReject = reject;
            [obj catchError:^(NSError *error) {
                __strong typeof(weakReject) reject = weakReject;
                // reject 不存在 说明前面已经 resolve/reject 了 Promise 已经被释放了
                if (reject) {
                    reject(error);
                    releaseAllPromise(promiseArray);
                }
            }];
        }
    } name:@"Promise from race"];
}

#pragma mark - private method
+ (NSArray<__kindof YYPromise *> *)arrayContent2Promise:(NSArray *)array {
    NSMutableArray *promiseArray = [NSMutableArray arrayWithCapacity:array.count];
    [array enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if (![obj isKindOfClass:[YYPromise class]]) {
            obj = [YYPromise resolve:obj];
        }
        [promiseArray addObject:obj];
    }];
    return [promiseArray copy];
}

#pragma mark - public method
- (instancetype)then:(resolveBlock)onFulfilled {
    __weak typeof(self) weakSelf = self;
    // then/catchError Promise
    return [YYPromise createPromise:^(resolveBlock resolve, rejectBlock reject) {
        __strong typeof(weakSelf) self = weakSelf;
        HandleObject *handle = [[HandleObject alloc] init];
        handle.onFulfilled = onFulfilled;
        handle.resolve = resolve;
        handle.reject = reject;
        // 在同步状态下也能执行到 resolve
        [self handle:handle];
    } name:@"Promise from resolve mid"];
}

- (instancetype)catchError:(rejectBlock)onRejected {
    __weak typeof(self) weakSelf = self;
    // then/catchError Promise
    return [YYPromise createPromise:^(resolveBlock resolve, rejectBlock reject) {
        __strong typeof(weakSelf) self = weakSelf;
        HandleObject *handle = [[HandleObject alloc] init];
        handle.onRejected = onRejected;
        handle.resolve = resolve;
        handle.reject = reject;
        [self handle:handle];
    } name:@"promise from reject mid"];
}

#pragma mark - private method
- (void)handle:(HandleObject *)object {
    switch (self.state) {
        case PromiseStatePending:
        {
            [self.deferreds addObject:object];
            break;
        }

        case PromiseStateFulfilled:
        {
            // onFulfilled 为空的原因是 Promise 的 then 链中间有 catchError
            // 处理方案是通过 catchError 中的 Promise resolve 将数据传递到(后面岔开分支中)下一个 then 的 Promise 中
            id ret = (object.onFulfilled ? object.onFulfilled(self.data) : self.data);
            object.resolve(ret);
            break;
        }
        
        case PromiseStateRejected:
        {
            NSAssert([self.data isKindOfClass:[NSError class]], @"建议错误处理的时候传递 NSError 类型的数据。");
            if (object.onRejected) {
                object.onRejected(self.data);
            }
            object.reject(self.data);
            break;
        }
    }
}

#pragma mark - debug
- (NSString *)description {
    return [NSString stringWithFormat:@"%@ <YYPromise: %p>", self.name, self];
}

- (void)dealloc {
    static NSUInteger num = 0;
    num++;
    NSLog(@"%@  :  %@", self, [NSString stringWithFormat:@"promise release %ld", num]);
}

#pragma mark - getter
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-retain-cycles"
// 这里明显会出现循环引用 故意为之 是为了重新掌握 Promiss 内存管理
- (resolveBlock)resolve {
    if (_resolve == nil) {
        _resolve = ^id(id data) {
            [data isKindOfClass:[YYPromise class]] ? ({
                // promise 为外部 Promise
                YYPromise *promise = (YYPromise *)data;
                // data 为 Promise 表示 object resolve 需要等待到 data Promise PromiseStateFulfilled 才能执行
                // 这个 data Promise 也就是外部 Promise
                // 下一次执行 object.resolve 的时候 接收的数据是 promise resolve 出来的数据 从而改变 self then/catchError 的指向(原来 self then/catchError 是接收自己数据的 现在接收 promise 的数据)
                // 所以下面做法实现了两个作用：
                // 1. 延迟执行 self.resolve 到 promise resolve 时
                // 2. 重新决定 self.resolve 接收的数据链
                [promise then:self.resolve];
                [promise catchError:self.reject];
            }) : ({
                self.state = PromiseStateFulfilled;
                self.data = data;
                [self runDeferreds];
            });
            return @"接收到本字符串说明 Promise 相关代码有问题，请提出 issue";
        };
    }
    return _resolve;
}

- (rejectBlock)reject {
    if (_reject == nil) {
        _reject = ^(NSError *error) {
            self.state = PromiseStateRejected;
            self.data = error;
            [self runDeferreds];
        };
    }
    return _reject;
}

- (void)runDeferreds {
    // 这里面没有实现将 runDeferreds 在下一次事件循环才执行的功能
    // 因为 iOS 异步线程默认是没有 RunLoop 的 即使在这里面强行起一个 RunLoop  也没用
    // 因为外部 block 也会等 RunLoop 被销毁了才会执行
    // 顺便一提 我在尝试实现中 发觉到 Cocoa Touch 的 RunLoop 是有内存泄露的 在 Core Function 的 RunLoop 才没有内存泄露
    // 主要是停止 Cocoa Touch RunLoop 比较难
    // https://www.jianshu.com/p/0fb198ff0912  https://bestswifter.com/runloop-and-thread/ 可以看看这两篇文章
    [self.deferreds enumerateObjectsUsingBlock:^(HandleObject  *_Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [self handle:obj];
    }];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
        // 释放 Promise
        self.resolve = nil;
        self.reject = nil;
    });
}
#pragma clang diagnostic pop

#pragma mark - getter

- (NSMutableArray *)deferreds {
    if (_deferreds == nil) {
        _deferreds = [NSMutableArray array];
    }
    return _deferreds;
}

@end

