//
//  AVIMConversation+CustomAttributes.m
//  LeanChatLib
//
//  Created by lzw on 15/4/8.
//  Copyright (c) 2015年 avoscloud. All rights reserved.
//

#import "AVIMConversation+Custom.h"
#import "CDIM.h"
#import "UIImage+Icon.h"

@implementation AVIMConversation (Custom)

- (CDConvType)type {
    return [[self.attributes objectForKey:CONV_TYPE] intValue];
}

+ (NSString *)nameOfUserIds:(NSArray *)userIds {
    NSMutableArray *names = [NSMutableArray array];
    for (int i = 0; i < userIds.count; i++) {
        id <CDUserModel> user = [[CDIMConfig config].userDelegate getUserById:[userIds objectAtIndex:i]];
        [names addObject:user.username];
    }
    return [names componentsJoinedByString:@","];
}

- (NSString *)displayName {
    if ([self type] == CDConvTypeSingle) {
        NSString *otherId = [self otherId];
        id <CDUserModel> other = [[CDIMConfig config].userDelegate getUserById:otherId];
        return other.username;
    }
    else {
        return self.name;
    }
}

- (NSString *)otherId {
    NSArray *members = self.members;
    if (members.count != 2) {
        [NSException raise:@"invalid conv" format:nil];
    }
    CDIM *im = [CDIM sharedInstance];
    if ([members containsObject:im.selfId] == NO) {
        [NSException raise:@"invalid conv" format:nil];
    }
    NSString *otherId;
    if ([members[0] isEqualToString:im.selfId]) {
        otherId = members[1];
    }
    else {
        otherId = members[0];
    }
    return otherId;
}

- (NSString *)title {
    if (self.type == CDConvTypeSingle) {
        return self.displayName;
    }
    else {
        return [NSString stringWithFormat:@"%@(%ld)", self.displayName, (long)self.members.count];
    }
}

- (UIImage *)icon {
    return [UIImage imageWithHashString:self.conversationId displayString:[[self.name substringWithRange:NSMakeRange(0, 1)] capitalizedString]];
}

@end
