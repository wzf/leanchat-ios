//
//  CDStorage.h
//  LeanChat
//
//  Created by lzw on 15/1/29.
//  Copyright (c) 2015年 AVOS. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "CDRoom.h"

@interface CDStorage : NSObject

+ (instancetype)storage;

- (void)setupWithUserId:(NSString *)userId;

- (NSArray *)getRooms;

- (NSInteger)countUnread;
- (void)insertRoomWithConvid:(NSString *)convid;
- (void)deleteRoomByConvid:(NSString *)convid;
- (void)incrementUnreadWithConvid:(NSString *)convid;
- (void)clearUnreadWithConvid:(NSString *)convid;

@end
