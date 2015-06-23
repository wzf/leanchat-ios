//
//  AVIMConversation+CustomAttributes.h
//  LeanChatLib
//
//  Created by lzw on 15/4/8.
//  Copyright (c) 2015年 avoscloud. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVOSCloudIM/AVOSCloudIM.h>
#import "CDIMConfig.h"

#define CONV_TYPE @"type"
#define CONV_MEMBERS_KEY @"m"

typedef enum : NSUInteger {
    CDConvTypeSingle = 0,
    CDConvTypeGroup,
} CDConvType;

@interface AVIMConversation (Custom)

- (CDConvType)type;

- (NSString *)otherId;

- (NSString *)displayName;

+ (NSString *)nameOfUserIds:(NSArray *)userIds;

- (NSString *)title;

- (UIImage *)icon;


@end
