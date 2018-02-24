//
//  YYGenerator.m
//  Promise Demo
//
//  Created by zhanghong on 2018/2/13.
//  Copyright © 2018年 zhanghong. All rights reserved.
//

#import "YYGenerator.h"
#include <stdlib.h>
#include <pthread.h>
#include <memory.h>
#include <setjmp.h>

// 协程结构体 内部包含了协程所需要的栈等数据
typedef struct CoroutineUnit
{
    int *regEnv; // 存储寄存器内容的缓冲区 大小为 48*sizeof(int)byte (int在32位还是64位CPU都是4个字节)
    void *stack; // 栈
    long stackSize; // 栈的大小
    int isSwitch:1; // 切换位标志
    struct CoroutineUnit *next;
}*pCoroutineUnit, coroutineUnit;

extern void *getSP(void);
extern void *getFP(void);

@interface YYGenerator () {
    // 需要释放
    pthread_key_t _coroutineKey;
    void *_fp;
    void *_sp;
    id _data;
}

@property (nonatomic, copy) id(^genratorBlock)(id data);
@property (nonatomic, assign) pthread_t currentPthread;
// yield 所处的协程
@property (nonatomic, assign) pCoroutineUnit yieldCoroutineUnit;
// next 所处的协程
@property (nonatomic, assign) pCoroutineUnit nextCoroutineUnit;

@end

@implementation YYGenerator

static YYGenerator *__genrator;
pthread_mutex_t genratorMutex = PTHREAD_MUTEX_INITIALIZER;
pthread_mutex_t stackMutex = PTHREAD_MUTEX_INITIALIZER;

#pragma mark - init
+ (instancetype)createGenrator:(id(^)(id data))genratorBlock {
    
    YYGenerator *genrator = [[YYGenerator alloc] init];
    genrator.genratorBlock = genratorBlock;
    
    genrator->_fp = getFP();
    genrator->_sp = getSP();
    
    pCoroutineUnit yieldCoroutineUnit = (pCoroutineUnit)calloc(1, sizeof(coroutineUnit));
    // 初始化任务的 CPU 寄存器
    (*yieldCoroutineUnit).regEnv = (int *)calloc(48, sizeof(int));
    (*yieldCoroutineUnit).regEnv[22] = (int)(long)startCoroutine;
    (*yieldCoroutineUnit).regEnv[23] = (int)(long)((long)startCoroutine >> 32);
    genrator.yieldCoroutineUnit = yieldCoroutineUnit;
    
    pCoroutineUnit nextCoroutineUnit = (pCoroutineUnit)calloc(1, sizeof(coroutineUnit));
    (*nextCoroutineUnit).regEnv = (int *)calloc(48, sizeof(int));
    genrator.nextCoroutineUnit = nextCoroutineUnit;
    // 双向链表 让他们可以循环切换
    genrator.nextCoroutineUnit->next = genrator.yieldCoroutineUnit;
    genrator.yieldCoroutineUnit->next = genrator.nextCoroutineUnit;
    
    
    genrator.yieldCoroutineUnit->regEnv[24] = (int)(long)genrator->_fp;
    genrator.yieldCoroutineUnit->regEnv[25] = (int)(long)((long)genrator->_fp >> 32);
    genrator.yieldCoroutineUnit->regEnv[26] = (int)(long)genrator->_sp;
    genrator.yieldCoroutineUnit->regEnv[27] = (int)(long)((long)genrator->_sp >> 32);
    genrator.nextCoroutineUnit->regEnv[24] = (int)(long)genrator->_fp;
    genrator.nextCoroutineUnit->regEnv[25] = (int)(long)((long)genrator->_fp >> 32);
    genrator.nextCoroutineUnit->regEnv[26] = (int)(long)genrator->_sp;
    genrator.nextCoroutineUnit->regEnv[27] = (int)(long)((long)genrator->_sp >> 32);
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        // 互斥锁
        pthread_mutex_init(&genratorMutex, NULL);
        pthread_mutex_init(&stackMutex, NULL);
    });
    
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
id yield(id data)
{
    // __genrator 必须有数据才能运行
    assert(__genrator);
    YYGenerator *self = __genrator;
    self->_data = data;
    [self swtichCoroutine];
    return self->_data;
}


- (id)next:(id)data {
    NSAssert(self.currentPthread == pthread_self(), @"不在同一线程内，暂时无法进行协程切换");
    if (self.currentPthread != pthread_self()) {
        // TODO: 后期可以尝试实现这一功能
        return [NSError errorWithDomain:@"YYGenerator" code:0 userInfo:@{NSLocalizedDescriptionKey:@"不在同一线程切换协程"}];
    }
    
    pthread_mutex_lock(&genratorMutex);
    __genrator = self;
    self->_data = data;
    pthread_setspecific(self->_coroutineKey, self.nextCoroutineUnit);
    [self swtichCoroutine];
    pthread_mutex_unlock(&genratorMutex);
    return self->_data;
}

#pragma mark - private method
- (void)swtichCoroutine {
    void *__sp = self->_sp;
    long stackSize = (long)__sp - (long)getSP();
    
    pCoroutineUnit pTaskUnit = (pCoroutineUnit)pthread_getspecific(self->_coroutineKey);
    (*pTaskUnit).stackSize = stackSize;
    if (pTaskUnit->stack) {
        free(pTaskUnit->stack);
        pTaskUnit->stack = NULL;
    }
    (*pTaskUnit).stack = calloc(1, stackSize);
    memcpy((*pTaskUnit).stack, getSP(), (*pTaskUnit).stackSize);
    setjmp((*pTaskUnit).regEnv);
    
    pTaskUnit = (pCoroutineUnit)pthread_getspecific(self->_coroutineKey);
    if ((*pTaskUnit).isSwitch) {
        (*pTaskUnit).isSwitch = 0; // 取消任务的切换状态
        return;
    }
    
    pCoroutineUnit pNextTaskUnit = (*pTaskUnit).next;
    pthread_setspecific(self->_coroutineKey, pNextTaskUnit);
    if ((*pNextTaskUnit).stack) {
        (*pNextTaskUnit).isSwitch = 1; //下一个是切换过来
        pthread_mutex_lock(&stackMutex);
        memcpy2stack((void *)((long)__sp - (*pNextTaskUnit).stackSize),(*pNextTaskUnit).stack, (*pNextTaskUnit).stackSize);
        pthread_mutex_unlock(&stackMutex);
        // __genrator 必须有数据才能运行
        assert(__genrator);
        pNextTaskUnit = (pCoroutineUnit)pthread_getspecific(__genrator->_coroutineKey);
    }
    longjmp((*pNextTaskUnit).regEnv, 1);
}

static inline void memcpy2stack(void *dest, void *src, long count)
{
    static char *tmp = NULL;
    static char *s = NULL;
    static long repeatCount = 0;
    tmp = (char *)dest;
    s   = (char *)src;
    repeatCount = count;
    
    while (repeatCount--) {
        *tmp++ = *s++;
    }
}

void startCoroutine(void)
{
    // __genrator 必须有数据才能运行
    assert(__genrator);
    YYGenerator *self = __genrator;
    id data = self.genratorBlock(self->_data);
    self->_data = data;
    [self swtichCoroutine];
}

#pragma mark - dealloc
- (void)dealloc {
    NSLog(@"哈哈哈");
    // TODO: 释放资源
}

@end

