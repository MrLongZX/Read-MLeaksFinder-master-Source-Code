/**
 * Tencent is pleased to support the open source community by making MLeaksFinder available.
 *
 * Copyright (C) 2017 THL A29 Limited, a Tencent company. All rights reserved.
 *
 * Licensed under the BSD 3-Clause License (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at
 *
 * https://opensource.org/licenses/BSD-3-Clause
 *
 * Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.
 */

#import "NSObject+MemoryLeak.h"
#import "MLeakedObjectProxy.h"
#import "MLeaksFinder.h"
#import <objc/runtime.h>
#import <UIKit/UIKit.h>

#if _INTERNAL_MLF_RC_ENABLED
#import <FBRetainCycleDetector/FBRetainCycleDetector.h>
#endif

static const void *const kViewStackKey = &kViewStackKey;
static const void *const kParentPtrsKey = &kParentPtrsKey;
const void *const kLatestSenderKey = &kLatestSenderKey;

@implementation NSObject (MemoryLeak)

// 将要释放
- (BOOL)willDealloc {
    // 类名
    NSString *className = NSStringFromClass([self class]);
    // 在白名单内，返回NO
    if ([[NSObject classNamesWhitelist] containsObject:className])
        return NO;
    
    // 关联对象保存的响应发送者
    NSNumber *senderPtr = objc_getAssociatedObject([UIApplication sharedApplication], kLatestSenderKey);
    // 执行target-action的时候，目标对象不检测内存泄漏
    if ([senderPtr isEqualToNumber:@((uintptr_t)self)])
        // 自身是响应发送者，返回NO
        return NO;
    
    __weak id weakSelf = self;
    // 2秒钟后主线程执行
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        // 强引用，保证self暂时先不被销毁，顺利执行下面的逻辑
        __strong id strongSelf = weakSelf;
        [strongSelf assertNotDealloc];
    });
    
    return YES;
}

// 断言没有释放
- (void)assertNotDealloc {
    // 是否已经添加进泄漏对象名单
    if ([MLeakedObjectProxy isAnyObjectLeakedAtPtrs:[self parentPtrs]]) {
        // 有，返回
        return;
    }
    // 添加内存泄露对象self
    [MLeakedObjectProxy addLeakedObject:self];
    
    NSString *className = NSStringFromClass([self class]);
    // 打印内存泄露信息
    NSLog(@"Possibly Memory Leak.\nIn case that %@ should not be dealloced, override -willDealloc in %@ by returning NO.\nView-ViewController stack: %@", className, className, [self viewStack]);
}

- (void)willReleaseObject:(id)object relationship:(NSString *)relationship {
    if ([relationship hasPrefix:@"self"]) {
        relationship = [relationship stringByReplacingCharactersInRange:NSMakeRange(0, 4) withString:@""];
    }
    NSString *className = NSStringFromClass([object class]);
    className = [NSString stringWithFormat:@"%@(%@), ", relationship, className];
    
    [object setViewStack:[[self viewStack] arrayByAddingObject:className]];
    [object setParentPtrs:[[self parentPtrs] setByAddingObject:@((uintptr_t)object)]];
    [object willDealloc];
}

- (void)willReleaseChild:(id)child {
    if (!child) {
        return;
    }
    
    [self willReleaseChildren:@[ child ]];
}

- (void)willReleaseChildren:(NSArray *)children {
    // 视图栈
    NSArray *viewStack = [self viewStack];
    // 父类指针
    NSSet *parentPtrs = [self parentPtrs];
    for (id child in children) {
        // 类名
        NSString *className = NSStringFromClass([child class]);
        // 添加子视图类名，重新保存视图栈数组
        [child setViewStack:[viewStack arrayByAddingObject:className]];
        // 添加子视图指针，重新保存父类指针集合
        [child setParentPtrs:[parentPtrs setByAddingObject:@((uintptr_t)child)]];
        // 孩子对象调用将要释放
        [child willDealloc];
    }
}

// 获取视图栈
- (NSArray *)viewStack {
    // 视图栈
    NSArray *viewStack = objc_getAssociatedObject(self, kViewStackKey);
    if (viewStack) {
        // 存在就返回
        return viewStack;
    }
    
    // 类名
    NSString *className = NSStringFromClass([self class]);
    return @[ className ];
}

// 保存视图栈
- (void)setViewStack:(NSArray *)viewStack {
    objc_setAssociatedObject(self, kViewStackKey, viewStack, OBJC_ASSOCIATION_RETAIN);
}

// 获取父类指针
- (NSSet *)parentPtrs {
    // 通过kParentPtrsKey获取父类指针
    NSSet *parentPtrs = objc_getAssociatedObject(self, kParentPtrsKey);
    if (!parentPtrs) {
        // 以自身指针为数据，创建集合
        parentPtrs = [[NSSet alloc] initWithObjects:@((uintptr_t)self), nil];
    }
    return parentPtrs;
}

// 设置父类指针
- (void)setParentPtrs:(NSSet *)parentPtrs {
    // 给self关联kParentPtrsKey的集合数据
    objc_setAssociatedObject(self, kParentPtrsKey, parentPtrs, OBJC_ASSOCIATION_RETAIN);
}

// 类名白名单
+ (NSMutableSet *)classNamesWhitelist {
    static NSMutableSet *whitelist = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        // 白名单列表
        whitelist = [NSMutableSet setWithObjects:
                     @"UIFieldEditor", // UIAlertControllerTextField
                     @"UINavigationBar",
                     @"_UIAlertControllerActionView",
                     @"_UIVisualEffectBackdropView",
                     nil];
        
        // System's bug since iOS 10 and not fixed yet up to this ci.
        // 系统版本
        NSString *systemVersion = [UIDevice currentDevice].systemVersion;
        // 大于10.0
        if ([systemVersion compare:@"10.0" options:NSNumericSearch] != NSOrderedAscending) {
            // 添加UISwitch
            [whitelist addObject:@"UISwitch"];
        }
    });
    return whitelist;
}

// 添加类名到白名单
+ (void)addClassNamesToWhitelist:(NSArray *)classNames {
    [[self classNamesWhitelist] addObjectsFromArray:classNames];
}

+ (void)swizzleSEL:(SEL)originalSEL withSEL:(SEL)swizzledSEL {
#if _INTERNAL_MLF_ENABLED
    
#if _INTERNAL_MLF_RC_ENABLED
    // Just find a place to set up FBRetainCycleDetector.
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dispatch_async(dispatch_get_main_queue(), ^{
            [FBAssociationManager hook];
        });
    });
#endif
    
    // 类对象
    Class class = [self class];
    
    // 原对象方法
    Method originalMethod = class_getInstanceMethod(class, originalSEL);
    // 待交换对象方法
    Method swizzledMethod = class_getInstanceMethod(class, swizzledSEL);
    
    // 给原对象方法设置方法实现，判断原对象方法是否已经实现
    BOOL didAddMethod =
    class_addMethod(class,
                    originalSEL,
                    method_getImplementation(swizzledMethod),
                    method_getTypeEncoding(swizzledMethod));
    
    if (didAddMethod) {
        // 原对象方法没有实现
        // 代替待交换对象方法的实现为原方法实现
        class_replaceMethod(class,
                            swizzledSEL,
                            method_getImplementation(originalMethod),
                            method_getTypeEncoding(originalMethod));
    } else {
        // 原对象方法已经实现
        // 进行方法交换
        method_exchangeImplementations(originalMethod, swizzledMethod);
    }
#endif
}

@end
