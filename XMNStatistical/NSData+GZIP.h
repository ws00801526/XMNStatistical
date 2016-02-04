//
//  NSData+GZIP.h
//  XMNStatisticExample
//
//  Created by XMFraker on 16/1/21.
//  Copyright © 2016年 XMFraker. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSData (GZIP)

/**
 *  使用GZIP方式压缩数据
 *
 *  @param unCompressData 未压缩的数据
 *
 *  @return GZIP压缩后数据 或者 nil
 */
+ (NSData *)compressDataWithGZIP:(NSData *)unCompressData;


/**
 *  使用GZIP方式解压缩数据
 *
 *  @param compressData 被GZIP压缩的数据
 *
 *  @return 解压缩后的数据 或者 nil
 */
+ (NSData *)unCompressDataWithGZIP:(NSData *)compressData;

@end
