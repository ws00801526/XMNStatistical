//
//  XMNStatistic.m
//  XMNStatisticExample
//
//  Created by XMFraker on 16/1/20.
//  Copyright © 2016年 XMFraker. All rights reserved.
//

#import "XMNStatistic.h"

#import <UIKit/UIApplication.h>
#import <sqlite3.h>
#import "zlib.h"
#import <sqlite3.h>
#import <execinfo.h>
#import <CommonCrypto/CommonDigest.h>

#import "XMNDevice.h"

#import "NSData+GZIP.h"


//创建activity活动记录表sql
static const char* createActivityTableSql = "create table if not exists activities(\
    id integer not null primary key autoincrement,\
    name varchar(255),\
    start_at integer unsigned not null,\
    end_at integer unsigned not null\
    )";
//创建异常崩溃表sql
static const char *createExceptionTableSql = "create table if not exists exceptions(\
    id integer not null primary key autoincrement,\
    md5 char(32) unique,\
    exception text,\
    created_at integer unsigned not null\
    )";
//创建事件表sql
static const char *createEventTableSql = "create table if not exists events(\
    id integer not null primary key autoincrement,\
    name varchar(255),\
    param text,\
    value varchar(255),\
    version varchar(255),\
    created_at integer unsigned not null\
    )";

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
};

@interface XMNStatistic ()

{
    /** 存储记录数据的db */
    sqlite3 *_db;
    NSTimeInterval _activityStart;
}

- (void)_setupExceptionHandler:(BOOL)install;
- (void)_eventException:(NSString *)exception;
- (void)_eventActivity:(NSString *)activityName;
- (void)_deleteExceptions;
- (void)_deleteActivitiesBeforeID:(NSUInteger)ID;
- (void)_deleteEventsBeforeID:(NSUInteger)ID;

/** 上传log的服务器地址 */
@property (nonatomic, copy)   NSString *serverURLString;
/** channel 类型 */
@property (nonatomic, copy)   NSString *channel;

@end

static void XMNStatisticUncaughtExceptionHandler(NSException *exception) {
    [[XMNStatistic shareStatistic] _eventException:[NSString stringWithFormat:@"\n--------Log Exception---------\n\nexception name      :%@\nexception reason    :%@\nexception userInfo  :%@\ncallStackSymbols    :%@\n\n--------End Log Exception-----",exception.name, exception.reason,exception.userInfo ? : @"no user info", [exception callStackSymbols]]];
    [[XMNStatistic shareStatistic] _setupExceptionHandler:NO];
}

static void XMNStatisticSignalHandler(int signal){
    //捕获signal事件处理
    void* callstack[128];
    int frames = backtrace(callstack, 128);
    char **strs = backtrace_symbols(callstack, frames);
    
    NSMutableString* callback = [NSMutableString string];
    for (int i=0; i < frames; i++){
        [callback appendFormat:@"%s\n", strs[i]];
    }
    free(strs);
    
    NSString* description = nil;
    switch (signal) {
        case SIGABRT:
            description = [NSString stringWithFormat:@"Signal SIGABRT was raised!\n%@", callback];
            break;
        case SIGILL:
            description = [NSString stringWithFormat:@"Signal SIGILL was raised!\n%@", callback];
            break;
        case SIGSEGV:
            description = [NSString stringWithFormat:@"Signal SIGSEGV was raised!\n%@", callback];
            break;
        case SIGFPE:
            description = [NSString stringWithFormat:@"Signal SIGFPE was raised!\n%@", callback];
            break;
        case SIGBUS:
            description = [NSString stringWithFormat:@"Signal SIGBUS was raised!\n%@", callback];
            break;
        case SIGPIPE:
            description = [NSString stringWithFormat:@"Signal SIGPIPE was raised!\n%@", callback];
            break;
    }
    
    [[XMNStatistic shareStatistic] _eventException:callback];
    [[XMNStatistic shareStatistic] _setupExceptionHandler:NO];
    kill(getpid(), signal);
}


@implementation XMNStatistic

#pragma mark - Life Cycle

+ (instancetype)shareStatistic {
    static id statistic;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        statistic = [[[self class] alloc] init];
    });
    return statistic;
}

- (instancetype)init {
    if ([super init]) {
        [self _setupSqliteDB];
        [self _setupExceptionHandler:YES];
        [self _setupApplicationHandlers];
    }
    return self;
}

#pragma mark - Methods

- (void)_setupApplicationHandlers {
    __weak typeof(*&self) wSelf = self;
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification object:nil queue:[NSOperationQueue currentQueue] usingBlock:^(NSNotification * _Nonnull note) {
        _activityStart = [[NSDate date] timeIntervalSince1970];
    }];
    
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationWillResignActiveNotification object:nil queue:[NSOperationQueue currentQueue] usingBlock:^(NSNotification * _Nonnull note) {
        __weak typeof(*&self) self = wSelf;
        [self _eventActivity:@"ResignActive"];
    }];
    
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationWillEnterForegroundNotification object:nil queue:[NSOperationQueue currentQueue] usingBlock:^(NSNotification * _Nonnull note) {
        _activityStart = [[NSDate date] timeIntervalSince1970];
    }];
    
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidEnterBackgroundNotification object:nil queue:[NSOperationQueue currentQueue] usingBlock:^(NSNotification * _Nonnull note) {
        __weak typeof(*&self) self = wSelf;
        [self _eventActivity:@"EnterBackground"];
    }];
}

/// ========================================
/// @name   Private Methods
/// ========================================

/**
 *  注册,或者取消注册捕获系统异常
 *
 *  @param install 是否注册捕获时间
 */
- (void)_setupExceptionHandler:(BOOL)install {
    NSSetUncaughtExceptionHandler(install ? &XMNStatisticUncaughtExceptionHandler : NULL);
    signal(SIGABRT, install ? XMNStatisticSignalHandler : SIG_DFL);
    signal(SIGILL, install ? XMNStatisticSignalHandler : SIG_DFL);
    signal(SIGSEGV, install ? XMNStatisticSignalHandler : SIG_DFL);
    signal(SIGFPE, install ? XMNStatisticSignalHandler : SIG_DFL);
    signal(SIGBUS, install ? XMNStatisticSignalHandler : SIG_DFL);
    signal(SIGPIPE, install ? XMNStatisticSignalHandler : SIG_DFL);
}

/**
 *  初始化数据库
 *  打开数据库,创建不存在的表
 */
- (void)_setupSqliteDB {
    if (sqlite3_open([[self _sqliteDBPath] UTF8String], &_db) == SQLITE_OK) {
        sqlite3_exec(_db, createActivityTableSql, NULL, NULL, NULL) == SQLITE_OK ? NSLog(@"创建activity表成功") : NSLog(@"创建activity表失败");
        sqlite3_exec(_db, createExceptionTableSql, NULL, NULL, NULL)== SQLITE_OK ? NSLog(@"创建exception表成功") : NSLog(@"创建exception表失败");
        sqlite3_exec(_db, createEventTableSql, NULL, NULL, NULL)== SQLITE_OK ? NSLog(@"创建event表成功") : NSLog(@"创建event表失败");
    }
}

- (NSString *)_sqliteDBPath {
    static NSString *filePath = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *directionary = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject] stringByAppendingPathComponent:@"com.XMFraker.statistic"];
        NSError *error;
        if (![[NSFileManager defaultManager] fileExistsAtPath:directionary]) {
            [[NSFileManager defaultManager] createDirectoryAtPath:directionary withIntermediateDirectories:YES attributes:nil error:&error];
        }
        filePath = [directionary stringByAppendingPathComponent:@"statistic.db"];
        
    });
    return filePath;
}


/**
 *  执行插入,删除,修改数据库操作
 *  使用sql的事务操作,防止写入出错
 *  @param sql    执行的sql语言
 *  @param params sql附带的参数
 */
- (void)_excuteSql:(NSString *)sql params:(NSDictionary *)params {
    if (!sql) {
        return;
    }
    
    char *errorMsg;
    @try{
        if (sqlite3_exec(_db, "BEGIN", NULL, NULL, &errorMsg)==SQLITE_OK)
        {
            sqlite3_stmt *stmt;
            const char *sqlString = [sql UTF8String];
            if(sqlite3_prepare(_db, sqlString, (int)strlen(sqlString), &stmt, NULL) == SQLITE_OK){
                params ? [params enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
                    int index = sqlite3_bind_parameter_index(stmt, [key UTF8String]);
                    if ([obj isKindOfClass:[NSString class]]) {
                        const char *cStr = [obj UTF8String];
                        sqlite3_bind_text(stmt, index, cStr, (int)strlen(cStr), SQLITE_TRANSIENT);
                    }else if ([obj isKindOfClass:[NSNumber class]]) {
                        sqlite3_bind_int(stmt, index, (int)[obj integerValue]);
                    }
                }] : nil;
                sqlite3_step(stmt);
                sqlite3_finalize(stmt);
            }
            //确认提交事务
            sqlite3_exec(_db, "COMMIT", NULL, NULL, &errorMsg);
        }
    }
    @catch(NSException *e)
    {
        //回滚事务
        char *errorMsg;
        sqlite3_exec(_db, "ROLLBACK", NULL, NULL, &errorMsg);
    }
    @finally{
        errorMsg ? NSLog(@"excute sql :%@ wrong \n :%s",sql,errorMsg) : nil;
        sqlite3_free(errorMsg);
    }
}

- (NSArray *)_excuteSelectSql:(NSString *)sql keys:(NSArray *)keys {
    NSMutableArray *infos = [NSMutableArray array];
    sqlite3_stmt *stmt;
    NSArray *objValue = @[@"id",@"start_at",@"end_at",@"created_at"];
    if(sqlite3_prepare(_db, [sql UTF8String], (int)strlen([sql UTF8String]), &stmt, NULL) == SQLITE_OK){
        while (sqlite3_step(stmt) == SQLITE_ROW) {
            NSMutableDictionary *info = [NSMutableDictionary dictionary];
            [keys enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                if (![objValue containsObject:obj]) {
                    info[obj] = [NSString stringWithCString:(const char*)sqlite3_column_text(stmt, (int)idx) encoding:NSUTF8StringEncoding];
                }else {
                    info[obj] = @(sqlite3_column_int(stmt, (int)idx));
                }
            }];
            [infos addObject:info];
        }
        sqlite3_finalize(stmt);
    }
    return [NSArray arrayWithArray:infos];
}

- (void)_eventException:(NSString *)exception {
    NSString *md5 = MD5(exception);
    NSString *sql = @"insert into exceptions (md5, exception, created_at) values (:md5, :exception, :created_at)";
    NSDictionary *params = @{@":md5":md5,@":exception":exception,@":created_at":@([[NSDate date] timeIntervalSince1970])};
    [self _excuteSql:sql params:params];
}

- (void)_eventActivity:(NSString *)activityName {
    NSString *sql = @"insert into activities (name,start_at,end_at) values (:name,:start_at,:end_at)";
    NSDictionary *params = @{@":name":activityName,@":start_at":@(_activityStart),@":end_at":@([[NSDate date] timeIntervalSince1970])};
    [self _excuteSql:sql params:params];
}

- (void)_event:(NSString *)name value:(NSString *)value params:(NSDictionary *)params {
    if (!name) {
        NSLog(@"event name must not be nil");
        return;
    }
    NSString *sql = @"insert into events(name, param, value, version, created_at) values (:name, :param, :value, :version, :created_at)";
    NSDictionary *sqlParams;
    if (params) {
        NSError *jsonError;
        NSData *paramData = [NSJSONSerialization dataWithJSONObject:params options:NSJSONWritingPrettyPrinted error:&jsonError];
        if (jsonError) {
            NSLog(@"wrong during NSDictionary to JSON :%@\
                  wont save params:%@",[jsonError description],params);
            sqlParams = @{@":name":name,@":value":value ? : name,@":param":@"",@":version":[XMNDevice getAppVersion],@":created_at":@([[NSDate date] timeIntervalSinceNow])};
        }else {
            sqlParams = @{@":name":name,@":value":value ? : name,@":param":[[NSString alloc] initWithData:paramData encoding:NSUTF8StringEncoding],@":version":[XMNDevice getAppVersion],@":created_at":@([[NSDate date] timeIntervalSinceNow])};
        }
    }else {
        sqlParams = @{@":name":name,@":value":value ? : name,@":param":@"",@":version":[XMNDevice getAppVersion],@":created_at":@([[NSDate date] timeIntervalSinceNow])};
    }
    [self _excuteSql:sql params:sqlParams];
}

- (void)_deleteExceptions {
    NSString *sql = @"delete from exceptions";
    [self _excuteSql:sql params:nil];
}

- (void)_deleteActivitiesBeforeID:(NSUInteger)ID {
    NSString *sql = ID == 0 ? @"delete from activities" : @"delete from activities where id < :id";
    [self _excuteSql:sql params:ID == 0 ? nil : @{@":id":@(ID)}];
}

- (void)_deleteEventsBeforeID:(NSUInteger)ID {
    NSString *sql = ID == 0 ? @"delete from events" : @"delete from events where id < :id";
    [self _excuteSql:sql params:ID == 0 ? nil : @{@":id":@(ID)}];
}

- (NSArray *)_getEventsWithCondition:(NSString *)condition {
    NSString *sql = condition ? [NSString stringWithFormat:@"select id, name, param, value, version, created_at from events %@",condition] : [NSString stringWithFormat:@"select id, name, param, value, version, created_at from events"];
    NSMutableArray *array = [NSMutableArray arrayWithArray:[self _excuteSelectSql:sql keys:@[@"id",@"name",@"param",@"value",@"version",@"created_at"]]];
    NSMutableDictionary *replaceDict = [NSMutableDictionary dictionary];
    [array enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if (obj[@"param"]) {
            NSDictionary *paramDict = [NSJSONSerialization JSONObjectWithData:[obj[@"param"] dataUsingEncoding:NSUTF8StringEncoding] options:NSJSONReadingAllowFragments error:nil];
            NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithDictionary:obj];
            dict[@"param"] = paramDict;
            replaceDict[@(idx)] = dict;
        }
    }];
    [replaceDict enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
        array[[key integerValue]] = obj;
    }];
    
    return array;
}

- (NSArray *)_getExceptionsWithCondition:(NSString *)condition {
    NSString *sql = condition ? [NSString stringWithFormat:@"select id, md5, exception, created_at from exceptions %@",condition] : @"select id, md5, exception, created_at from exceptions";
    return [self _excuteSelectSql:sql keys:@[@"id",@"md5",@"exception",@"created_at"]];
}

- (NSArray *)_getActiviesWithCondition:(NSString *)condition {
    NSString *sql = condition ? [NSString stringWithFormat:@"select id, name, start_at, end_at from activities %@",condition] : @"select id, name, start_at, end_at from activities";

    return [self _excuteSelectSql:sql keys:@[@"id",@"name",@"start_at",@"end_at"]];
}


/// ========================================
/// @name   Class Methods
/// ========================================

+ (void)setupServerURLString:(NSString *)serverURLString channel:(NSString *)channel {
    [XMNStatistic shareStatistic].channel = channel;
    [XMNStatistic shareStatistic].serverURLString = serverURLString;
}

/**
 *  记录一个事件
 *  @code
 *  [self event:@"eventName"];
 *  @endcode
 *  @param name 事件名称
 */
+ (void)event:(NSString *)name {
    [self event:name value:nil params:nil];
}

/**
 *  记录一个事件
 *  @code
 *  [self event:@"eventName" value:@"event appear view"];
 *  @endcode
 *  @param name  事件名称
 *  @param value 事件的value
 */
+ (void)event:(NSString *)name value:(NSString *)value {
    [self event:name value:value params:nil];
}

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
+ (void)event:(NSString *)name value:(NSString *)value params:(NSDictionary *)params {
    [[XMNStatistic shareStatistic] _event:name value:value params:params];
}

+ (NSArray *)getStatisticWithType:(XMNStatisticType)statisticType withCondition:(NSString *)condition{
    @autoreleasepool {
        NSMutableArray *statisticArray = [NSMutableArray array];
        switch (statisticType) {
            case XMNStatisticActivity:
                [statisticArray addObjectsFromArray:[[XMNStatistic shareStatistic] _getActiviesWithCondition:condition]];
                break;
            case XMNStatisticEvent:
                [statisticArray addObjectsFromArray:[[XMNStatistic shareStatistic] _getEventsWithCondition:condition]];
                break;
            case XMNStatisticException:
                [statisticArray addObjectsFromArray:[[XMNStatistic shareStatistic] _getExceptionsWithCondition:condition]];
                break;
            default:
                [statisticArray addObjectsFromArray:[[XMNStatistic shareStatistic] _getExceptionsWithCondition:condition]];
                [statisticArray addObjectsFromArray:[[XMNStatistic shareStatistic] _getEventsWithCondition:condition]];
                [statisticArray addObjectsFromArray:[[XMNStatistic shareStatistic] _getActiviesWithCondition:condition]];
                break;
        }
        return [NSArray arrayWithArray:statisticArray];
    }
}

/**
 *  上传目前数据库内日记内容
 *
 *  @param useGZIP 是否使用GZIP压缩 默认YES
 */
+ (void)uploadStatisticWithType:(XMNStatisticType)statisticType UsingGZIP:(BOOL)useGZIP {
    @autoreleasepool {
        NSMutableDictionary *requestParmas = [NSMutableDictionary dictionary];
        
        NSMutableDictionary *deviceDict = [NSMutableDictionary dictionaryWithDictionary:[XMNDevice deviceInfoDict]];
        //configuration deviceInfo
        deviceDict[@"channel"] = [XMNStatistic shareStatistic].channel;
        requestParmas[@"deviceInfo"] = deviceDict;
        
        switch (statisticType) {
            case XMNStatisticActivity:
            {
                //configuration activities
                requestParmas[@"activies"] = [self getStatisticWithType:XMNStatisticActivity withCondition:nil];
            }
                break;
            case XMNStatisticEvent:
            {
                //configuration events
               requestParmas[@"events"] = [self getStatisticWithType:XMNStatisticEvent withCondition:nil];
            }
                break;
            case XMNStatisticException:
            {
                //configuration exceptions
                requestParmas[@"exceptions"] = [self getStatisticWithType:XMNStatisticException withCondition:nil];
            }
                break;
            case XMNStatisticUnknown:
                break;
            default:
            {
                //configuration exceptions
                requestParmas[@"exceptions"] = [self getStatisticWithType:XMNStatisticException withCondition:nil];
                //configuration events
                requestParmas[@"events"] = [self getStatisticWithType:XMNStatisticEvent withCondition:nil];
                //configuration activities
                requestParmas[@"activies"] = [self getStatisticWithType:XMNStatisticActivity withCondition:nil];
            }
                break;
        }
        
        
        

        NSData *data = [NSJSONSerialization dataWithJSONObject:requestParmas options:NSJSONWritingPrettyPrinted error:nil];
        NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:[XMNStatistic shareStatistic].serverURLString]];
        [request setHTTPMethod:@"POST"];
        [request setValue:useGZIP ? @"application/x-gzip" : @"application/json" forHTTPHeaderField:@"Content-Type"];
        [request setHTTPBody:useGZIP ? [NSData compressDataWithGZIP:data] : data];
        NSURLSessionDataTask *connection = [session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
            NSLog(@"upload statistic success ? :%@ ",error ? @"false" : @"true");
            NSLog(@"data :%@",[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
            if (!error) {
                //清空所有的log记录
//                [[XMNStatistic shareStatistic] _deleteExceptions];
//                [[XMNStatistic shareStatistic] _deleteActivitiesBeforeID:0];
//                [[XMNStatistic shareStatistic] _deleteEventsBeforeID:0];
            }
        }];
        [connection resume];
    }
}



@end
