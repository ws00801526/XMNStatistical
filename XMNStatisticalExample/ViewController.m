//
//  ViewController.m
//  XMNStatisticExample
//
//  Created by XMFraker on 16/1/20.
//  Copyright © 2016年 XMFraker. All rights reserved.
//

#import "ViewController.h"

#import "XMNStatistic.h"

@interface ViewController ()
@property (weak, nonatomic) IBOutlet UISegmentedControl *sengmentControl;


- (void)maskCrash;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    NSLog(@"test line_info marco :%@",LINE_INFO(@"test"));
    // Do any additional setup after loading the view, typically from a nib.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Methods

- (IBAction)addEvent {
    
    NSDate *date = [NSDate date];
    for (int i = 0 ; i < 10000; i++) {
        if (i%2 ==0) {
            [XMNStatistic event:@"button click" value:NSStringFromClass([self class])];
        }else {
            [XMNStatistic event:@"button click" value:NSStringFromClass([self class]) params:@{@"detail info":LINE_INFO(@"this is detail info")}];
        }
    }
    NSDate *endDate = [NSDate date];
    
    NSLog(@"insert 10000 logs cost seconds :%.3f",[endDate timeIntervalSinceDate:date]);
    
}

- (IBAction)addParamEvent {
    
    [XMNStatistic event:@"button click" value:NSStringFromClass([self class]) params:@{@"detail info":LINE_INFO(@"this is detail info")}];
}

- (IBAction)showEvents {
    NSDate *date = [NSDate date];
    NSArray *array = @[];
    NSString *logTitles = @"unknown log";
    switch (self.sengmentControl.selectedSegmentIndex) {
        case 0:
            array = [XMNStatistic getStatisticWithType:XMNStatisticEvent withCondition:@"order by id desc"];
            logTitles = @"events";
            break;
        case 1:
            array = [XMNStatistic getStatisticWithType:XMNStatisticActivity withCondition:@"order by id"];
            logTitles = @"activities";
            break;
        case 2:
            array = [XMNStatistic getStatisticWithType:XMNStatisticException withCondition:@"order by id"];
            logTitles = @"exceptions";
            break;
        default:
            break;
    }
    NSDate *endDate = [NSDate date];
    NSLog(@"show %ld :%@ cost :%.3f",array.count,logTitles,[endDate timeIntervalSinceDate:date]);
}

- (IBAction)insertException {
    [self maskCrash];
}

- (IBAction)uploadLogs {
    [XMNStatistic uploadStatisticWithType:XMNStatisticAll UsingGZIP:YES];
}


@end
