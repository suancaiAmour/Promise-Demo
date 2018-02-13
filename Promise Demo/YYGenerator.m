//
//  YYGenerator.m
//  Promise Demo
//
//  Created by zhanghong on 2018/2/13.
//  Copyright © 2018年 zhanghong. All rights reserved.
//

#import "YYGenerator.h"
#import <pthread.h>
#import <setjmp.h>

// 协程结构体 内部包含了协程所需要的栈等数据
typedef struct CoroutineUnit
{
    int *regEnv; // 存储寄存器内容的缓冲区 大小为 52*sizeof(int)byte (int在32位还是64位CPU都是4个字节)
    void *stack; // 栈
    long stackSize; // 栈的大小
    int isSwitch:1; // 切换位标志
    struct CoroutineUnit *next;
}*pCoroutineUnit, coroutineUnit;

extern void pushCoroutineEnv(int *regEnv);
extern void popCoroutineEnv(int *regEnv);
extern void *getSP(void);
extern void *getFP(void);

#define JMPFLAG 2

@interface YYGenerator () {
    // 需要释放
    pthread_key_t _coroutineKey;
 
}

@property (nonatomic, copy) void(^genratorBlock)(YYGenerator *genrator);
@property (nonatomic, assign) pthread_t currentPthread;

// yield 所处的协程
@property (nonatomic, assign) pCoroutineUnit yieldCoroutineUnit;
// next 所处的协程
@property (nonatomic, assign) pCoroutineUnit nextCoroutineUnit;

@property (nonatomic, assign) void *fp;
@property (nonatomic, assign) void *sp;




@end

@implementation YYGenerator

static YYGenerator *__genrator;;
pthread_mutex_t mutex = PTHREAD_MUTEX_INITIALIZER;

#pragma mark - init
+ (instancetype)createGenrator:(void(^)(YYGenerator *genrator))genratorBlock {
    
    YYGenerator *genrator = [[YYGenerator alloc] init];
   
    
//    genrator.fp = getFP();
//    genrator.fp = getSP();

    pCoroutineUnit yieldCoroutineUnit = (pCoroutineUnit)calloc(1, sizeof(coroutineUnit));
    // 初始化任务的 CPU 寄存器
    (*yieldCoroutineUnit).regEnv = (int *)calloc(52, sizeof(int));
//    (*yieldCoroutineUnit).regEnv[24] = (int)(long)genrator.fp;
//    (*yieldCoroutineUnit).regEnv[25] = (int)(long)((long)genrator.fp >> 32);
//    (*yieldCoroutineUnit).regEnv[22] = (int)(long)yield;
//    (*yieldCoroutineUnit).regEnv[23] = (int)(long)((long)yield >> 32);
//    (*yieldCoroutineUnit).regEnv[26] = (int)(long)genrator.sp;
//    (*yieldCoroutineUnit).regEnv[27] = (int)(long)((long)genrator.sp >> 32);
    genrator.yieldCoroutineUnit = yieldCoroutineUnit;
    
    pCoroutineUnit nextCoroutineUnit = (pCoroutineUnit)calloc(1, sizeof(coroutineUnit));
    // 初始化任务的 CPU 寄存器
    (*nextCoroutineUnit).regEnv = (int *)calloc(52, sizeof(int));
//    (*nextCoroutineUnit).regEnv[24] = (int)(long)genrator.fp;
//    (*nextCoroutineUnit).regEnv[25] = (int)(long)((long)genrator.fp >> 32);
//    (*nextCoroutineUnit).regEnv[22] = (int)(long)yield;
//    (*nextCoroutineUnit).regEnv[23] = (int)(long)((long)yield >> 32);
//    (*nextCoroutineUnit).regEnv[26] = (int)(long)genrator.sp;
//    (*nextCoroutineUnit).regEnv[27] = (int)(long)((long)genrator.sp >> 32);
    genrator.nextCoroutineUnit = nextCoroutineUnit;
    
    // 双向链表 让他们可以循环切换
    genrator.nextCoroutineUnit->next = genrator.yieldCoroutineUnit;
    genrator.yieldCoroutineUnit->next = genrator.nextCoroutineUnit;
    
    return genrator;
}

- (instancetype)init {
    if (self = [super init]) {
        pthread_key_create(&_coroutineKey, NULL);
        self.currentPthread = pthread_self();
    }
    return self;
}

#pragma mark - public method
id yield(void(^yieldBlock)(void))
{
    // __genrator 必须有数据才能运行
    assert(__genrator);
    YYGenerator *self = __genrator;
    pthread_mutex_unlock(&mutex);
    
    return NULL;
}

- (id)next:(id)data {
    NSAssert(self.currentPthread == pthread_self(), @"不在同一线程内，暂时无法进行协程切换");
    if (self.currentPthread != pthread_self()) {
        // TODO: 后期可以尝试实现这一功能
        return [NSError errorWithDomain:@"YYGenerator" code:0 userInfo:@{NSLocalizedDescriptionKey:@"不在同一线程切换协程"}];
    }
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        // 互斥锁
        pthread_mutex_init(&mutex,NULL);
    });
    pthread_mutex_lock(&mutex);
    __genrator = self;
    // 赋值到 X0 寄存器上
    self.yieldCoroutineUnit->regEnv[44] = (int)(long)(data);
    self.yieldCoroutineUnit->regEnv[45] = (int)(long)((long)data >> 32);
    
   
    
    return NULL;
}

#pragma mark - private method


@end

