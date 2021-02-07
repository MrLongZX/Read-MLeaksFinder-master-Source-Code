//
//  TestViewController.m
//  Demo
//
//  Created by suyoulong on 2021/1/26.
//  Copyright © 2021 suyoulong. All rights reserved.
//

#import "TestViewController.h"

typedef void(^MyBlock)(void);

@interface TestViewController ()

@property (nonatomic, copy) MyBlock block;

@end

@implementation TestViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.view.backgroundColor = [UIColor lightGrayColor];
    
}

-(void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    
    self.block = ^{
        NSLog(@"%p",self);
    };
    
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end
