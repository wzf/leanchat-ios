//
//  ChatRoom.h
//  AVOSChatDemo
//
//  Created by lzw on 14/10/27.
//  Copyright (c) 2014年 AVOS. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "CDAVOSHeaders.h"

@interface CDRoom : NSObject<NSCoding>

@property (nonatomic, strong) NSString *convid;

@property (nonatomic, strong) AVIMConversation *conv;

@property (nonatomic, strong) AVIMTypedMessage *lastMsg;

@property (nonatomic, assign) NSInteger unreadCount;

@end
