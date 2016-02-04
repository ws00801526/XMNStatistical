//
//  XMNStatistic.h
//  XMNStatisticExample
//  简单的日志统计插件
//  功能:
//  1.统计event,崩溃日志
//  2.存放到数据库中
//  3.指定服务器地址,上传至服务器中
//  Created by XMFraker on 16/1/20.
//  Copyright © 2016年 XMFraker. All rights reserved.
//
//  0120 - 完成基本功能
//  TODO 定时或者定量上传


#import <Foundation/Foundation.h>

/**
 *  返回当前文件,行号,方法名
 *
 *  @param FORMAT 自定义拼接参数
 *  @param ...    多参数
 *
 *  @return 拼接好的字符串
 */
#define LINE_INFO(FORMAT, ...) [NSString stringWithFormat:@"\n[--%@--]\n[--%s--]\n[--%s--]\n[--%d--]\n[--%s--]\n",[NSDateFormatter localizedStringFromDate:[NSDate date] dateStyle:NSDateFormatterLongStyle timeStyle:NSDateFormatterLongStyle],[[[NSString stringWithUTF8String:__FILE__] lastPathComponent] UTF8String],__FUNCTION__,__LINE__,[[NSString stringWithFormat:FORMAT, ##__VA_ARGS__] UTF8String]]

typedef NS_ENUM(NSUInteger, XMNStatisticType) {
    XMNStatisticAll,
    XMNStatisticActivity,
    XMNStatisticException,
    XMNStatisticEvent,
    XMNStatisticUnknown
};

@interface XMNStatistic : NSObject

/// ========================================
/// @name   Properties
/// ========================================

/** 上传log的服务器地址 */
@property (nonatomic, copy, readonly)   NSString *serverURLString;
/** channel 类型 */
@property (nonatomic, copy, readonly)   NSString *channel;


/// ========================================
/// @name   Methods
/// ========================================

+ (instancetype)shareStatistic;


/// ========================================
/// @name   Class Methods
/// ========================================

+ (void)setupServerURLString:(NSString *)serverURLString channel:(NSString *)channel;

/**
 *  记录一个事件
 *  @code
 *  [self event:@"eventName"];
 *  @endcode
 *  @param name 事件名称
 */
+ (void)event:(NSString *)name;

/**
 *  记录一个事件
 *  @code
 *  [self event:@"eventName" value:@"event appear view"];
 *  @endcode
 *  @param name  事件名称
 *  @param value 事件的value
 */
+ (void)event:(NSString *)name value:(NSString *)value;

/**
 *  记录一个事件
 *
 *  @param name   事件名称
 *  @param value  事件的value
 *  @param params 事件额外参数
 *  @code
 *  [self event:@"eventName" value:@"event appear view" params:@{@"user":@"testUser"}];
 *  @endcode
 */
+ (void)event:(NSString *)name value:(NSString *)value params:(NSDictionary *)params;

/**
 *  获取相应类型的记录数据
 *
 *  @param statisticType 记录类型
 *  @param condition       记录筛选条件
 *  @code
 *  查询所有id<500的所有记录
 *  [XMNStatistic getStatisticWithType:XMNStatisticAll withCondition:@"where id < 500"];
 *  @endcode
 *  @return 获取的记录数组
 */
+ (NSArray *)getStatisticWithType:(XMNStatisticType)statisticType withCondition:(NSString *)condition;

/**
 *  上传目前数据库内日记内容
 *      
 *  @param statisticType      上传的日志类型
 *  @param useGZIP              是否使用GZIP压缩 建议YES
 */
+ (void)uploadStatisticWithType:(XMNStatisticType)statisticType UsingGZIP:(BOOL)useGZIP;

@end
