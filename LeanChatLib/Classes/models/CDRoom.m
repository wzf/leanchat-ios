//
//  ChatRoom.m
//  AVOSChatDemo
//
//  Created by lzw on 14/10/27.
//  Copyright (c) 2014年 AVOS. All rights reserved.
//

#import "CDRoom.h"

#define CD_SEL_STR(sel) (NSStringFromSelector(@selector(sel)))

@implementation CDRoom

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    if (self) {
        self.convid = [coder decodeObjectForKey:CD_SEL_STR(convid)];
        self.unreadCount = [[coder decodeObjectForKey:CD_SEL_STR(unreadCount)] intValue];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeObject:self.convid forKey:CD_SEL_STR(convid)];
    [aCoder encodeObject:@(self.unreadCount) forKey:CD_SEL_STR(unreadCount)];
}

@end
