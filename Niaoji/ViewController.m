//
//  ViewController.m
//  Niaoji
//
//  Created by IOS App on 17/1/6.
//  Copyright © 2017年 nova. All rights reserved.
//

#import "ViewController.h"
#import "JusaBluetouth.h"

@interface ViewController ()<JusaBluetoothManagerDelegate>
@property (strong, nonatomic) JusaBluetouth *bluetoothManager;
@property (weak, nonatomic) IBOutlet UITextField *textfield;
@property (weak, nonatomic) IBOutlet UIButton *sendBtn;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.bluetoothManager = [[JusaBluetouth alloc] init];
    
}

- (IBAction)pressSendButton:(id)sender {
    if (self.textfield.text) {
        [self.bluetoothManager writeToPeripheral:@"423404ffff0204"];
    }
}

- (void)didGetDataForString:(NSString *)dataString {
    [self.textfield setText:[NSString stringWithFormat:@"Receive:%@",dataString]];
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
