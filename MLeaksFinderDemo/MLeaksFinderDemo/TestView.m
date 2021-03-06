//
//  TestView.m
//  MLeaksFinderDemo
//
//  Created by suyoulong on 2021/2/7.
//  Copyright © 2021 suyoulong. All rights reserved.
//

#import "TestView.h"

typedef void(^MyBlock)(void);

@interface TestView ()

@property (nonatomic, copy) NSString *string;

@property (nonatomic, copy) MyBlock block;

@end

@implementation TestView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.string = @"123";
        self.backgroundColor = [UIColor orangeColor];
    }
    return self;
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    self.block = ^{
        NSLog(@"string:%@",_string);
    };
    self.block();
}

- (void)dealloc {
    NSLog(@"%s", __func__);
}

@end
