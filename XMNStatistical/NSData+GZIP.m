//
//  NSData+GZIP.m
//  XMNStatisticExample
//
//  Created by XMFraker on 16/1/21.
//  Copyright © 2016年 XMFraker. All rights reserved.
//

#import "NSData+GZIP.h"

#import <zlib.h>

@implementation NSData (GZIP)



/**
 *  使用GZIP方式压缩数据
 *
 *  @param unCompressData 未压缩的数据
 *
 *  @return GZIP压缩后数据 或者 nil
 */
+ (NSData *)compressDataWithGZIP:(NSData *)unCompressData {
    if (!unCompressData || [unCompressData length ] == 0 )  {
        NSLog ( @"%s: Error: Can't compress an empty or null NSData object." , __func__);
        return nil ;
    }
    //创建压缩流
    z_stream zlibStreamStruct;
    zlibStreamStruct. zalloc     = Z_NULL ; // Set zalloc, zfree, and opaque to Z_NULL so
    zlibStreamStruct. zfree     = Z_NULL ; // that when we call deflateInit2 they will be
    zlibStreamStruct. opaque     = Z_NULL ; // updated to use default allocation functions.
    zlibStreamStruct. total_out = 0 ; // Total number of output bytes produced so far
    zlibStreamStruct. next_in   = (Bytef*)[unCompressData bytes]; // Pointer to input bytes
    zlibStreamStruct. avail_in   = (uInt)[unCompressData length ]; // Number of input bytes left to process
    int initError = deflateInit2 (&zlibStreamStruct, Z_DEFAULT_COMPRESSION , Z_DEFLATED , ( 15 + 16 ), 8 , Z_DEFAULT_STRATEGY );
    if (initError != Z_OK ) {
        NSString *errorMsg = nil ;
        switch (initError)
        {
            case Z_STREAM_ERROR :
                errorMsg = @"Invalid parameter passed in to function." ;
                break ;
            case Z_MEM_ERROR :
                errorMsg = @"Insufficient memory." ;
                break ;
            case Z_VERSION_ERROR :
                errorMsg = @"The version of zlib.h and the version of the library linked do not match." ;
                break ;
            default :
                errorMsg = @"Unknown error code." ;
                break ;
        }
        NSLog ( @"%s: deflateInit2() Error: \"%@\" Message: \"%s\"" , __func__, errorMsg, zlibStreamStruct. msg );
        return nil ;
    }
    //创建压缩后的data数据buffer,防止数据大小不够,创建压缩data buffer大小是原大小的1.1倍
    NSMutableData *compressedData = [NSMutableData dataWithLength :[unCompressData length ] * 1.01 + 12 ];
    int deflateStatus;
    do {
        //存储当前位置,作为下一段数据的起始
        zlibStreamStruct.next_out = [compressedData mutableBytes] + zlibStreamStruct. total_out ;
        //计算剩余的可用存储数据内存
        zlibStreamStruct. avail_out = (uInt)[compressedData length] - (uInt)zlibStreamStruct. total_out;
        //压缩数据
        deflateStatus = deflate (&zlibStreamStruct, Z_FINISH );
    } while ( deflateStatus == Z_OK );
    
    // Check for zlib error and convert code to usable error message if appropriate
    
    if (deflateStatus != Z_STREAM_END ) {
        NSString *errorMsg = nil ;
        switch (deflateStatus)
        {
            case Z_ERRNO :
                errorMsg = @"Error occured while reading file." ;
                break ;
            case Z_STREAM_ERROR :
                errorMsg = @"The stream state was inconsistent (e.g., next_in or next_out was NULL)." ;
                break ;
            case Z_DATA_ERROR :
                errorMsg = @"The deflate data was invalid or incomplete." ;
                break ;
            case Z_MEM_ERROR :
                errorMsg = @"Memory could not be allocated for processing." ;
                break ;
            case Z_BUF_ERROR :
                errorMsg = @"Ran out of output buffer for writing compressed bytes." ;
                break ;
            case Z_VERSION_ERROR :
                errorMsg = @"The version of zlib.h and the version of the library linked do not match." ;
                break ;
            default :
                errorMsg = @"Unknown error code." ;
                break ;
        }
        NSLog ( @"%s: zlib error while attempting compression: \"%@\" Message: \"%s\"" , __func__, errorMsg, zlibStreamStruct. msg );
        // 是否数据
        deflateEnd (&zlibStreamStruct);
        return nil ;
    }
    //释放数据
    deflateEnd (&zlibStreamStruct);
    [compressedData setLength : zlibStreamStruct.total_out];
    return compressedData;
}


/**
 *  使用GZIP方式解压缩数据
 *
 *  @param compressData 被GZIP压缩的数据
 *
 *  @return 解压缩后的数据 或者 nil
 */
+ (NSData *)unCompressDataWithGZIP:(NSData *)compressData {
    if (!compressData || compressData.length == 0) {
        NSLog(@"compressData must not be nil");
        return nil;
    }
    unsigned full_length = (unsigned)[compressData length];
    unsigned half_length = (unsigned)[compressData length] / 2;
    NSMutableData *decompressed = [NSMutableData dataWithLength: full_length +     half_length];
    BOOL done = NO;
    int status;
    z_stream strm;
    strm.next_in = (Bytef *)[compressData bytes];
    strm.avail_in = (uInt)[compressData length];
    strm.total_out = 0;
    strm.zalloc = Z_NULL;
    strm.zfree = Z_NULL;
    
    if (inflateInit2(&strm, (15+32)) != Z_OK) return nil;
    while (!done){
        if (strm.total_out >= [decompressed length])
            [decompressed increaseLengthBy: half_length];
        strm.next_out = [decompressed mutableBytes] + strm.total_out;
        strm.avail_out = (uInt)((uLong)[decompressed length] - strm.total_out);
        // Inflate another chunk.
        status = inflate (&strm, Z_SYNC_FLUSH);
        if (status == Z_STREAM_END) done = YES;
        else if (status != Z_OK) break;
    }
    if (inflateEnd (&strm) != Z_OK) return nil;
        // Set real length.
    if (done){
        [decompressed setLength: strm.total_out];
        return [NSData dataWithData: decompressed];
    }
    return nil;
}

@end
