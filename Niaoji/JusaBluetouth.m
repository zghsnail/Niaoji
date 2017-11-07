//
//  JusaBluetouth.m
//  Niaoji
//
//  Created by IOS App on 17/1/6.
//  Copyright © 2017年 nova. All rights reserved.
//


#define kServiceUUID @"0000fff0-0000-1000-8000-00805f9b34fb"
#define kCharacteristicWriteUUID @"0000fff1-0000-1000-8000-00805f9b34fb"
#define kCharacteristicNotifyUUID @"0000fff4-0000-1000-8000-00805f9b34fb"

#import "JusaBluetouth.h"

@interface JusaBluetouth()

@property (strong,nonatomic) NSMutableArray *peripherals;   //连接的外围设备
@property (nonatomic, strong) CBCharacteristic *writeCharacteristic;

@end

@implementation JusaBluetouth
@synthesize delegate=delegate;

- (void)writeToPeripheral:(NSString *)dataString {
    if(_writeCharacteristic == nil){
        NSLog(@"writeCharacteristic 为空");
        return;
    }
    NSData *value = [self dataWithHexstring:dataString];
    
    [_peripheral writeValue:value forCharacteristic:_writeCharacteristic type:CBCharacteristicWriteWithResponse];
    
    NSLog(@"已经向外设%@写入数据%@",_peripheral.name,dataString);
}

- (instancetype)init{
    self = [super init];
    if (self) {
        manager = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
        manager.delegate = self;
        _isConnected = NO;
        
    }
    return self;
}

#pragma mark - CBPeripheral Delegate

// 发现外设后
- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral
     advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI {
    
    if ([peripheral.name isEqualToString:@"NOVAUR_LE"]) {
        [manager stopScan];
        [manager connectPeripheral:peripheral options:nil];
        NSLog(@"连接外设:%@",peripheral.description);
        self.peripheral = peripheral;
    }
}

// 连接到外设后
- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral{
    NSLog(@"已经连接到:%@", peripheral.description);
    peripheral.delegate = self;
    [central stopScan];
    [peripheral discoverServices:nil];
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error {
    if (error) {
        NSLog(@"搜索服务%@时发生错误:%@", peripheral.name, [error localizedDescription]);
        return;
    }
    for (CBService *service in peripheral.services) {
        //发现服务   kCharacteristicWriteUUID
        if ([service.UUID isEqual:[CBUUID UUIDWithString:kServiceUUID]]) {
            [peripheral discoverCharacteristics:nil forService:service];
            break;
        }
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error {
    if (error) {
        NSLog(@"搜索特征%@时发生错误:%@", service.UUID, [error localizedDescription]);
        return;
    }
    NSLog(@"%lu个特征",service.characteristics.count);
    
    
    for (CBCharacteristic *characteristic in service.characteristics) {
        NSLog(@"特征:%@,%@",characteristic.UUID,characteristic.UUID.UUIDString);
        //发现特征
        if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:@"FFF1"]]) {
            
            _writeCharacteristic = characteristic;
            NSLog(@"_writeCharacteristic%@",_writeCharacteristic.UUID);
        }
        
        if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:@"FFF4"]]) {
            NSLog(@"监听特征:%@",characteristic.UUID);//监听特征
            [self.peripheral setNotifyValue:YES forCharacteristic:characteristic];
            _isConnected = YES;
        }
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error{
    if (error){
        NSLog(@"更新特征值%@时发生错误:%@", characteristic.UUID, [error localizedDescription]);
        return;
    }
    // 收到数据
    NSData *data = characteristic.value;
    NSString *hexStr = [self hexStrWithData:data];
    
    [delegate didGetDataForString:hexStr];
    NSLog(@"%@ value is :%@",characteristic.UUID,hexStr);
    
    niaojice(hexStr);//解析
    // 80个字段 一次不能发送 分了几次 ...没处理
}

#pragma mark - CBCentralManager Delegate

- (void)centralManagerDidUpdateState:(CBCentralManager *)central{
    NSString * state = nil;
    
    switch ([central state]){
        case CBManagerStateUnsupported:
            state = @"StateUnsupported";
            break;
        case CBManagerStateUnauthorized:
            state = @"StateUnauthorized";
            break;
        case CBManagerStatePoweredOff:
            state = @"PoweredOff";
            break;
        case CBManagerStatePoweredOn:
            [manager scanForPeripheralsWithServices:nil options:@{CBCentralManagerRestoredStateScanOptionsKey:@(YES)}];
            state = @"PoweredOn";
            break;
        case CBManagerStateUnknown:
            state = @"unknown";
            break;
        default:
            break;
    }
    NSLog(@"手机状态:%@", state);
}



// 连接失败后
- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    NSLog(@"连接外设%@失败",peripheral);
}

// 断开外设
- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    NSLog(@"与%@断开连接",peripheral);
}

#pragma mark - NSData and NSString

- (NSData*)dataWithHexstring:(NSString *)hexstring{
    NSMutableData* data = [NSMutableData data];
    int idx;
    for(idx = 0; idx + 2 <= hexstring.length; idx += 2){
        NSRange range = NSMakeRange(idx, 2);
        NSString* hexStr = [hexstring substringWithRange:range];
        NSScanner* scanner = [NSScanner scannerWithString:hexStr];
        unsigned int intValue;
        [scanner scanHexInt:&intValue];
        [data appendBytes:&intValue length:1];
    }
    return data;
}

- (NSString *)hexStrWithData:(NSData *)data {
    NSString *hexStr=@"";
    Byte *bytes = (Byte *)[data bytes];
    
    for(int i=0;i<data.length;i++){
        NSString *newHexStr = [NSString stringWithFormat:@"%x",bytes[i]&0xff]; //16进制数
        if([newHexStr length]==1)
            hexStr = [NSString stringWithFormat:@"%@0%@",hexStr,newHexStr];
        else
            hexStr = [NSString stringWithFormat:@"%@%@",hexStr,newHexStr];
    }
    return hexStr;
}

void niaojice(NSString *hexStr){
    //0B042EFFFF22140C090208330D040104020403030404090405050604070808010A010B002020202020202020202020209F
    if (hexStr.length < 80) {
        return;
    }

    
    // Year
    NSRange rangeyear1 = NSMakeRange(6*2 , 2);
    NSString *year1str = [hexStr substringWithRange:rangeyear1];
    NSInteger year1 = strtoul([year1str UTF8String], 0, 16);
    NSRange rangeyear2 = NSMakeRange(7*2 , 1*2);
    NSString *year2str = [hexStr substringWithRange:rangeyear2];
    NSInteger year2 = strtoul([year2str UTF8String], 0, 16);
    NSInteger year = year1 * 100 + year2;
    
    // Month
    NSRange rangemonth = NSMakeRange(8*2 , 1*2);
    NSString *monthstr = [hexStr substringWithRange:rangemonth];
    NSInteger month = strtoul([monthstr UTF8String], 0, 16);
    
    // Day
    NSRange rangeday = NSMakeRange(9*2 , 1*2);
    NSString *daystr = [hexStr substringWithRange:rangeday];
    NSInteger day = strtoul([daystr UTF8String], 0, 16);
    
    // Hour
    NSRange hourday = NSMakeRange(10*2 , 1*2);
    NSString *hourstr = [hexStr substringWithRange:hourday];
    NSInteger hour = strtoul([hourstr UTF8String], 0, 16);
    
    // Minutes
    NSRange rangeminute = NSMakeRange(11*2 , 1*2);
    NSString *minutestr = [hexStr substringWithRange:rangeminute];
    NSInteger minute = strtoul([minutestr UTF8String], 0, 16);
    
    // seconds
    NSRange rangesecond = NSMakeRange(12*2 , 1*2);
    NSString *rangesecondstr = [hexStr substringWithRange:rangesecond];
    NSInteger second = strtoul([rangesecondstr UTF8String], 0, 16);
    
    // project1 尿蛋白
    NSRange urorange = NSMakeRange(15*2 , 1*2);
    NSString *urostr = [hexStr substringWithRange:urorange];
    NSInteger uro = strtoul([urostr UTF8String], 0, 16);
    
    // project2 潜血
    NSRange bldrange = NSMakeRange(17*2 , 1*2);
    NSString *bldstr = [hexStr substringWithRange:bldrange];
    NSInteger bld = strtoul([bldstr UTF8String], 0, 16);
    
    // project3 胆红素
    NSRange bilrange = NSMakeRange(19*2 , 1*2);
    NSString *bilstr = [hexStr substringWithRange:bilrange];
    NSInteger bil = strtoul([bilstr UTF8String], 0, 16);
    
    // project4 胴体
    NSRange ketrange = NSMakeRange(21*2 , 1*2);
    NSString *ketstr = [hexStr substringWithRange:ketrange];
    NSInteger ket = strtoul([ketstr UTF8String], 0, 16);
    
    // project 9 白细胞
    NSRange leurange = NSMakeRange(23*2 , 1*2);
    NSString *leustr = [hexStr substringWithRange:leurange];
    NSInteger leu = strtoul([leustr UTF8String], 0, 16);
    
    // project 5 葡萄糖
    NSRange glurange = NSMakeRange(25*2 , 1*2);
    NSString *glustr = [hexStr substringWithRange:glurange];
    NSInteger glu = strtoul([glustr UTF8String], 0, 16);
    
    // project 6 蛋白质
    NSRange prorange = NSMakeRange(27*2 , 1*2);
    NSString *prostr = [hexStr substringWithRange:prorange];
    NSInteger pro = strtoul([prostr UTF8String], 0, 16);
    
    // project 7 酸碱度
    NSRange phrange = NSMakeRange(29*2 , 1*2);
    NSString *phstr = [hexStr substringWithRange:phrange];
    NSInteger ph = strtoul([phstr UTF8String], 0, 16);
    
    // project 8 亚硝酸盐
    NSRange nitrange = NSMakeRange(31*2 , 1*2);
    NSString *nitstr = [hexStr substringWithRange:nitrange];
    NSInteger nit = strtoul([nitstr UTF8String], 0, 16);
    
    // project 10 比重
    NSRange sgrange = NSMakeRange(33*2 , 1*2);
    NSString *sgstr = [hexStr substringWithRange:sgrange];
    NSInteger sg = strtoul([sgstr UTF8String], 0, 16);
    
    // project 11 维生素C
    NSRange vcrange = NSMakeRange(35*2 , 1*2);
    NSString *vcstr = [hexStr substringWithRange:vcrange];
    NSInteger vc = strtoul([vcstr UTF8String], 0, 16);
    
    NSLog(@"%@",[NSString stringWithFormat:@"%zd/%zd/%zd/%zd/%zd/%zd/%zd/%zd/%zd/%zd/%zd/%zd/%zd/%zd/%zd/%zd/%zd/",year,month,day,hour,minute,second,uro,bld,bil,ket,leu,glu,pro,ph,nit,sg,vc]);
}


@end
