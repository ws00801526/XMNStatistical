//
//  XMNDevice.h
//  XMNStatisticExample
//
//  Created by XMFraker on 16/1/20.
//  Copyright © 2016年 XMFraker. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "XMNStatistic.h"


@interface XMNDevice : NSObject

/**
 *  获取UDID,如果无则生成一个
 *
 *  @return UDID
 */
+ (NSString*) getUDID;

/**
 *  获取机型model
 *
 *  @return []
 */
+ (NSString*) getModel;

/**
 *  获取手机运营商信息
 *
 *  @return 手机运营商名称
 */
+ (NSString*) getCarrier;

/**
 *  获取屏幕分辨率
 *
 *  @return 屏幕分辨率
 */
+ (NSString*) getResolution;

/**
 *  获取网络连接状况
 *
 *  @return 网络连接状况
 */
+ (NSString*) getNetwork;

/**
 *  获取App版本,不是build版本
 *
 *  @return app版本号
 */
+ (NSString*) getAppVersion;

/**
 *  获取操作系统版本
 *
 *  @return 操作系统名称 + 操作系统版本号
 */
+ (NSString*) getOsVersion;

/**
 *  判断是否越狱机型
 *
 *  @return 是否越狱
 */
+ (bool) isJailbroken;


+ (NSDictionary *)deviceInfoDict;

+ (NSString *)deviceInfoDesctirtion;

@end
