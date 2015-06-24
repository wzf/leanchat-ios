//
//  CDStorage.m
//  LeanChat
//
//  Created by lzw on 15/1/29.
//  Copyright (c) 2015年 AVOS. All rights reserved.
//

#import "CDStorage.h"
#import "CDMacros.h"

static CDStorage *storageInstance;

@interface CDStorage ()

@property (nonatomic, strong) NSString *plistPath;

@property (nonatomic, strong) NSMutableArray *rooms;

@end

@implementation CDStorage

+ (instancetype)storage {
    static dispatch_once_t token;
    dispatch_once(&token, ^{
        storageInstance = [[CDStorage alloc] init];
    });
    return storageInstance;
}

- (NSString *)plistPathWithUserId:(NSString *)userId{
    NSString *libPath = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    return [libPath stringByAppendingPathComponent:[NSString stringWithFormat:@"chat_%@.plist", userId]];
}

- (void)saveData {
    if (self.plistPath) {
        [NSKeyedArchiver archiveRootObject:self.rooms toFile:self.plistPath];
    }
}

- (void)setupWithUserId:(NSString *)userId {
    if (self.rooms.count > 0) {
        [self saveData];
    }
    self.plistPath = [self plistPathWithUserId:userId];
    DLog(@"plistPath = %@", self.plistPath);
    if (![[NSFileManager defaultManager] fileExistsAtPath:self.plistPath]) {
        self.rooms = [NSMutableArray array];
        [self saveData];
    } else {
        self.rooms = [[NSKeyedUnarchiver unarchiveObjectWithFile:self.plistPath] mutableCopy];
    }
}

#pragma mark - rooms table

- (NSArray *)getRooms {
    return self.rooms;
}

- (NSInteger)countUnread {
    __block NSInteger unreadCount = 0;
    for (CDRoom *room in self.rooms) {
        unreadCount += room.unreadCount;
    }
    return unreadCount;
}

- (CDRoom *)findRoomWithConvid:(NSString *)convid {
    for (CDRoom *room in self.rooms) {
        if ([room.convid isEqualToString:convid]) {
            return room;
        }
    }
    return nil;
}

- (void)insertRoomWithConvid:(NSString *)convid {
    CDRoom *room = [self findRoomWithConvid:convid];
    if (room == nil) {
        CDRoom *room = [[CDRoom alloc] init];
        room.convid = convid;
        room.unreadCount = 0;
        [self.rooms addObject:room];
        [self saveData];
    }
}

- (void)deleteRoomByConvid:(NSString *)convid {
    CDRoom *room = [self findRoomWithConvid:convid];
    [self.rooms removeObject:room];
    [self saveData];
}

- (void)incrementUnreadWithConvid:(NSString *)convid {
    CDRoom *room = [self findRoomWithConvid:convid];
    if (room) {
        room.unreadCount ++;
        [self saveData];
    }
}

- (void)clearUnreadWithConvid:(NSString *)convid {
    CDRoom *room = [self findRoomWithConvid:convid];
    room.unreadCount = 0;
    [self saveData];
}

@end
