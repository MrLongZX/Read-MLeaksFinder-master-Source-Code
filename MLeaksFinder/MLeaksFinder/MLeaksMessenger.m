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

#import "MLeaksMessenger.h"
#import "UIViewController+MemoryLeak.h"

static __weak UIAlertController *alertView;

@implementation MLeaksMessenger

+ (void)alertWithTitle:(NSString *)title message:(NSString *)message {
    [self alertWithTitle:title message:message delegate:nil additionalButtonTitle:nil];
}

+ (void)alertWithTitle:(NSString *)title
               message:(NSString *)message
              delegate:(MLeakedObjectProxy *)objectProxy
 additionalButtonTitle:(NSString *)additionalButtonTitle {
    [alertView dismissViewControllerAnimated:NO completion:nil];
    
    UIAlertController *alertViewTemp = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {}];

    [alertViewTemp addAction:cancelAction];
    
    if (additionalButtonTitle && objectProxy) {
        UIAlertAction *otherAction = [UIAlertAction actionWithTitle:additionalButtonTitle style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [objectProxy clickFindRetainCyclesAction];
        }];
        
        [alertViewTemp addAction:otherAction];
    }

    [[self visibleViewController] presentViewController:alertViewTemp animated:YES completion:nil];
    alertView = alertViewTemp;
    
    NSLog(@"%@: %@", title, message);
}

+ (nullable UIViewController *)visibleViewController {
    UIViewController *rootViewController = [UIApplication sharedApplication].delegate.window.rootViewController;
    UIViewController *visibleViewController = [rootViewController syl_visibleViewControllerIfExist];
    return visibleViewController;
}

@end
