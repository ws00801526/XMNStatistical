//
//  XMNDevice.m
//  XMNStatisticExample
//
//  Created by XMFraker on 16/1/20.
//  Copyright © 2016年 XMFraker. All rights reserved.
//

#import "XMNDevice.h"

#import <sys/utsname.h>
#import "zlib.h"
#import <execinfo.h>
#import <UIKit/UIKit.h>
#import <CommonCrypto/CommonCrypto.h>
#import <netdb.h>

@import CoreTelephony;
@import SystemConfiguration;

static NSString *MD5(NSString *originString) {
    const char* callStackSymbolsStr = [originString UTF8String];
    unsigned char result[16];
    CC_MD5( callStackSymbolsStr, (int)strlen(callStackSymbolsStr), result); // This is the md5 call
    return [NSString stringWithFormat:
            @"%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x",
            result[0], result[1], result[2], result[3],
            result[4], result[5], result[6], result[7],
            result[8], result[9], result[10], result[11],
            result[12], result[13], result[14], result[15]
            ];
}

static NSString * const kXMNStatisticUdidKey = @"XMNStatistic_UDID";
static NSString * const kXMNStatisticUdidPastboardKey = @"XMNStatistic_UDID_PASTBOARD";

@implementation XMNDevice


+ (NSString*)_generateFreshOpenUDID {
    // 先按照 identifierForVendor 的方式去取 UDID，如果不成功再生成一个随机的 UUID
    UIDevice* device = [UIDevice currentDevice];
    if ([device respondsToSelector:@selector(identifierForVendor)]){
        NSString* uniqueIdentifier = [[device performSelector:@selector(identifierForVendor)] UUIDString];
        if (uniqueIdentifier && [uniqueIdentifier isKindOfClass:NSString.class]){
            return MD5(uniqueIdentifier);
        }
    }
    
    CFUUIDRef uuid = CFUUIDCreate(kCFAllocatorDefault);
    CFStringRef cfstring = CFUUIDCreateString(kCFAllocatorDefault, uuid);
    const char *cStr = CFStringGetCStringPtr(cfstring,CFStringGetFastestEncoding(cfstring));
    return MD5([NSString stringWithCString:cStr encoding:NSUTF8StringEncoding]);
    
}

+ (NSString*)_readUDIDFromPastboard{
    UIPasteboard* pastboard = [UIPasteboard pasteboardWithName:kXMNStatisticUdidPastboardKey create:NO];
    if(pastboard && pastboard.string){
        return pastboard.string;
    }
    return nil;
}

+ (void)_writeUDIDToPastboard:(NSString*)udid{
    UIPasteboard* pastboard = [UIPasteboard pasteboardWithName:kXMNStatisticUdidPastboardKey create:YES];
    pastboard.string = udid;
}

+ (NSString*) getUDID{
    static NSString* udid = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        udid = (NSString *) [defaults objectForKey:kXMNStatisticUdidKey];
        if(udid == nil){
            udid = [self _readUDIDFromPastboard];
            if(!udid){
                udid = [self _generateFreshOpenUDID];
                [self _writeUDIDToPastboard:udid];
            }
            [defaults setObject:udid forKey:kXMNStatisticUdidKey];
        }else{
            [self _writeUDIDToPastboard:udid];
        }
    });
    return udid;
}

+ (NSString*) getModel{
    
    NSLog(@"%@",[[UIDevice currentDevice] model]);
    
    struct utsname u;
    uname(&u);
    return [NSString stringWithCString: u.machine encoding: NSUTF8StringEncoding];
}

+ (NSString*) getCarrier{
    CTTelephonyNetworkInfo *info = [[CTTelephonyNetworkInfo alloc] init];
    NSString* carrier = [info.subscriberCellularProvider carrierName];
    return carrier ? carrier : @"";
}

+ (NSString*) getResolution{
    CGSize size = [UIScreen instancesRespondToSelector:@selector(currentMode)] ?
    [[UIScreen mainScreen] currentMode].size : [UIScreen mainScreen].bounds.size;
    return [NSString stringWithFormat:@"%.0fx%.0f", size.width, size.height];
}

+ (NSString*) getNetwork{
    struct sockaddr_in zeroAddress;
    bzero(&zeroAddress, sizeof(zeroAddress));
    zeroAddress.sin_len = sizeof(zeroAddress);
    zeroAddress.sin_family = AF_INET;
    zeroAddress.sin_addr.s_addr = htonl(IN_LINKLOCALNETNUM);
    SCNetworkReachabilityRef ref = SCNetworkReachabilityCreateWithAddress(kCFAllocatorDefault,
                                                                          (const struct sockaddr*)&zeroAddress);
    SCNetworkReachabilityFlags flags = 0;
    SCNetworkReachabilityGetFlags(ref, &flags);
    CFRelease(ref);
    
    if (flags & kSCNetworkReachabilityFlagsTransientConnection) return @"wifi";
    if (flags & kSCNetworkReachabilityFlagsConnectionRequired) return @"wifi";
    if (flags & kSCNetworkReachabilityFlagsIsDirect) return @"wifi";
    if (flags & kSCNetworkReachabilityFlagsIsWWAN) return @"cellnetwork";
    return @"unknow";
}

+ (NSString*) getAppVersion{
    return [[[NSBundle mainBundle] infoDictionary]
            objectForKey:@"CFBundleShortVersionString"];
}

+ (NSString*) getOsVersion{
    return [NSString stringWithFormat:@"%@ %@",[[UIDevice currentDevice] systemName],[[UIDevice currentDevice] systemVersion]];
}

+ (bool) isJailbroken{
    static bool isChecked = NO;
    static bool isJailbroken = NO;
    if(!isChecked){
        if ([[NSFileManager defaultManager] fileExistsAtPath:@"/Applications/Cydia.app"]) {
            isJailbroken = YES;
        }else if([[NSFileManager defaultManager] fileExistsAtPath:@"/private/var/lib/apt"]){
            isJailbroken = YES;
        }
    }
    return isJailbroken;
}


+ (NSDictionary *)deviceInfoDict {
    return @{@"udid":[self getUDID],
             @"mode":[self getModel],
             @"systemVersion":[self getOsVersion],
             @"appVersion":[self getAppVersion],
             @"carrier":[self getCarrier],
             @"network":[self getNetwork],
             @"resolution":[self getResolution],
             @"isBroken":@([self isJailbroken])};
}

+ (NSString *)deviceInfoDesctirtion {
    NSError *error;
    NSData *data = [NSJSONSerialization dataWithJSONObject:[self deviceInfoDict] options:NSJSONWritingPrettyPrinted error:&error];
    NSLog(@"this is desc :%@",error ? [error localizedDescription] : [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
    return error ? [error localizedDescription] : [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}

@end
