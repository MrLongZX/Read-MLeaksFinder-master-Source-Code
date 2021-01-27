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

#import "UIViewController+MemoryLeak.h"
#import "NSObject+MemoryLeak.h"
#import <objc/runtime.h>

#if _INTERNAL_MLF_ENABLED

const void *const kHasBeenPoppedKey = &kHasBeenPoppedKey;

@implementation UIViewController (MemoryLeak)

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        // 对象方法交换
        [self swizzleSEL:@selector(viewDidDisappear:) withSEL:@selector(swizzled_viewDidDisappear:)];
        [self swizzleSEL:@selector(viewWillAppear:) withSEL:@selector(swizzled_viewWillAppear:)];
        [self swizzleSEL:@selector(dismissViewControllerAnimated:completion:) withSEL:@selector(swizzled_dismissViewControllerAnimated:completion:)];
    });
}

- (void)swizzled_viewDidDisappear:(BOOL)animated {
    // 调用原方法
    [self swizzled_viewDidDisappear:animated];
    
    // VC关联kHasBeenPoppedKey的值为YES
    if ([objc_getAssociatedObject(self, kHasBeenPoppedKey) boolValue]) {
        // 调用将要释放对象
        [self willDealloc];
    }
}

- (void)swizzled_viewWillAppear:(BOOL)animated {
    // 调用原方法
    [self swizzled_viewWillAppear:animated];
    
    // 给VC关联kHasBeenPoppedKey，值为NO
    objc_setAssociatedObject(self, kHasBeenPoppedKey, @(NO), OBJC_ASSOCIATION_RETAIN);
}

- (void)swizzled_dismissViewControllerAnimated:(BOOL)flag completion:(void (^)(void))completion {
    // 调用原方法
    [self swizzled_dismissViewControllerAnimated:flag completion:completion];
    
    UIViewController *dismissedViewController = self.presentedViewController;
    if (!dismissedViewController && self.presentingViewController) {
        dismissedViewController = self;
    }
    
    if (!dismissedViewController) return;
    
    // dismissVC执行将要释放方法
    [dismissedViewController willDealloc];
}

- (BOOL)willDealloc {
    // 沿继承者链调用将要释放方法
    if (![super willDealloc]) {
        return NO;
    }
    
    // 将要释放多个子孩子
    [self willReleaseChildren:self.childViewControllers];
    // 将要释放某个子孩子
    [self willReleaseChild:self.presentedViewController];
    
    if (self.isViewLoaded) {
        // view已经加载到内存，将要释放view
        [self willReleaseChild:self.view];
    }
    
    return YES;
}

- (UIViewController *)syl_visibleViewControllerIfExist {
    
    if (self.presentedViewController) {
        return [self.presentedViewController syl_visibleViewControllerIfExist];
    }
    
    if ([self isKindOfClass:[UINavigationController class]]) {
        return [((UINavigationController *)self).visibleViewController syl_visibleViewControllerIfExist];
    }
    
    if ([self isKindOfClass:[UITabBarController class]]) {
        return [((UITabBarController *)self).selectedViewController syl_visibleViewControllerIfExist];
    }
    
    if ([self syl_isViewLoadedAndVisible]) {
        return self;
    } else {
        NSLog(@"UIViewController visibleViewControllerIfExist:，找不到可见的viewController。self = %@, self.view = %@, self.view.window = %@", self, [self isViewLoaded] ? self.view : nil, [self isViewLoaded] ? self.view.window : nil);
        return nil;
    }
}

- (BOOL)syl_isViewLoadedAndVisible {
    return self.isViewLoaded;
}

@end

#endif
