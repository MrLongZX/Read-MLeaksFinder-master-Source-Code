//
//  TestViewController.m
//  Demo
//
//  Created by suyoulong on 2021/1/26.
//  Copyright © 2021 suyoulong. All rights reserved.
//

#import "TestViewController.h"
#import "TestView.h"

@interface TestViewController ()

@property (nonatomic, strong) TestView *testView;

@end

@implementation TestViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"点击橙色view，制造循环引用";
    self.view.backgroundColor = [UIColor lightGrayColor];
    
    self.testView = [[TestView alloc] init];
    self.testView.frame = CGRectMake(100, 100, 100, 100);
    [self.view addSubview:self.testView];
}

- (void)dealloc {
    NSLog(@"%s", __func__);
}

@end
