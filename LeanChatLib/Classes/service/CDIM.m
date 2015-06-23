//
//  CDIMClient.m
//  LeanChat
//
//  Created by lzw on 15/1/21.
//  Copyright (c) 2015年 AVOS. All rights reserved.
//

#import "CDIM.h"
#import "CDRoom.h"
#import "CDStorage.h"
#import "CDNotify.h"
#import "CDMacros.h"
#import "CDEmotionUtils.h"
#import "CDIMConfig.h"

static CDIM *instance;

@interface CDIMConfig ()

@property (nonatomic, readwrite) NSString *selfId;

@end

@interface CDIM () <AVIMClientDelegate, AVIMSignatureDataSource>

@property CDStorage *storage;

@property CDIMConfig *imConfig;

@property CDNotify *notify;

@property (nonatomic, strong) NSMutableDictionary *cachedConvs;

@end

@implementation CDIM

#pragma mark - lifecycle

+ (instancetype)sharedInstance {
    if (instance == nil) {
        instance = [[CDIM alloc] init];
    }
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _imClient = [[AVIMClient alloc] init];
        _imClient.delegate = self;
        /* 取消下面的注释，将对 im的 open ，start(create conv),kick,invite 操作签名，更安全
         可以从你的服务器获得签名，这里从云代码获取，需要部署云代码，https://github.com/leancloud/leanchat-cloudcode
         */
        //        _imClient.signatureDataSource=self;
        _storage = [CDStorage sharedInstance];
        _notify = [CDNotify sharedInstance];
        _imConfig = [CDIMConfig config];
        _cachedConvs = [NSMutableDictionary dictionary];
        [self updateConnectStatus];
    }
    return self;
}

- (void)dealloc {
    [_imClient removeObserver:self forKeyPath:@"status"];
}

- (void)openWithClientId:(NSString *)clientId callback:(AVIMBooleanResultBlock)callback {
    _selfId = clientId;
    _selfUser = [self.imConfig.userDelegate getUserById:clientId];
    [self.storage setupWithUserId:clientId];
    [_imClient openWithClientId:clientId callback:^(BOOL succeeded, NSError *error) {
        [self updateConnectStatus];
        if (callback) {
            callback(succeeded, error);
        }
    }];
}

- (void)closeWithCallback:(AVBooleanResultBlock)callback {
    [_imClient closeWithCallback:callback];
}

#pragma mark - conversation

- (void)fecthConvWithId:(NSString *)convid callback:(AVIMConversationResultBlock)callback {
    AVIMConversationQuery *q = [_imClient conversationQuery];
    [q whereKey:@"objectId" equalTo:convid];
    [q findConversationsWithCallback: ^(NSArray *objects, NSError *error) {
        if (error) {
            callback(nil, error);
        }
        else {
            callback([objects objectAtIndex:0], error);
        }
    }];
}

- (void)fetchConvWithMembers:(NSArray *)members type:(CDConvType)type callback:(AVIMConversationResultBlock)callback {
    AVIMConversationQuery *q = [_imClient conversationQuery];
    [q whereKey:AVIMAttr(CONV_TYPE) equalTo:@(type)];
    [q whereKey:CONV_MEMBERS_KEY containsAllObjectsInArray:members];
    [q findConversationsWithCallback: ^(NSArray *objects, NSError *error) {
        if (error) {
            callback(nil, error);
        }
        else {
            if (objects.count > 0) {
                AVIMConversation *conv = [objects objectAtIndex:0];
                callback(conv, nil);
            }
            else {
                [self createConvWithMembers:members type:type callback:callback];
            }
        }
    }];
}

- (void)fetchConvWithMembers:(NSArray *)members callback:(AVIMConversationResultBlock)callback {
    [self fetchConvWithMembers:members type:CDConvTypeGroup callback:callback];
}

- (void)fetchConvWithOtherId:(NSString *)otherId callback:(AVIMConversationResultBlock)callback {
    NSMutableArray *array = [[NSMutableArray alloc] init];
    [array addObject:_imClient.clientId];
    [array addObject:otherId];
    [self fetchConvWithMembers:array type:CDConvTypeSingle callback:callback];
}

- (void)createConvWithMembers:(NSArray *)members type:(CDConvType)type callback:(AVIMConversationResultBlock)callback {
    NSString *name = nil;
    if (type == CDConvTypeGroup) {
        name = [AVIMConversation nameOfUserIds:members];
    }
    [_imClient createConversationWithName:name clientIds:members attributes:@{ CONV_TYPE:@(type) } options:AVIMConversationOptionNone callback:callback];
}

- (void)findGroupedConvsWithBlock:(AVIMArrayResultBlock)block {
    AVIMConversationQuery *q = [_imClient conversationQuery];
    [q whereKey:AVIMAttr(CONV_TYPE) equalTo:@(CDConvTypeGroup)];
    [q whereKey:CONV_MEMBERS_KEY containedIn:@[self.selfId]];
    q.limit = 1000;
    [q findConversationsWithCallback:block];
}

- (void)updateConv:(AVIMConversation *)conv name:(NSString *)name attrs:(NSDictionary *)attrs callback:(AVIMBooleanResultBlock)callback {
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    if (name) {
        [dict setObject:name forKey:@"name"];
    }
    if (attrs) {
        [dict setObject:attrs forKey:@"attrs"];
    }
    [conv update:dict callback:callback];
}

- (void)fetchConvsWithConvids:(NSSet *)convids callback:(AVIMArrayResultBlock)callback {
    if (convids.count > 0) {
        AVIMConversationQuery *q = [_imClient conversationQuery];
        [q whereKey:@"objectId" containedIn:[convids allObjects]];
        q.limit = 1000;  // default limit:10
        [q findConversationsWithCallback:callback];
    }
    else {
        callback([NSMutableArray array], nil);
    }
}

#pragma mark - query msgs

- (NSArray *)queryMsgsWithConv:(AVIMConversation *)conv msgId:(NSString *)msgId maxTime:(int64_t)time limit:(int)limit error:(NSError **)theError {
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);
    __block NSArray *result;
    __block NSError *blockError = nil;
    [conv queryMessagesBeforeId:msgId timestamp:time limit:limit callback: ^(NSArray *objects, NSError *error) {
        result = objects;
        blockError = error;
        dispatch_semaphore_signal(sema);
    }];
    dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
    *theError = blockError;
    if (blockError == nil) {
    }
    return result;
}

#pragma mark - send or receive message

- (void)receiveMsg:(AVIMTypedMessage *)msg conv:(AVIMConversation *)conv {
    [_storage insertRoomWithConvid:conv.conversationId];
    [_storage insertMsg:msg];
    [_storage incrementUnreadWithConvid:conv.conversationId];
    [_notify postMsgNotify:msg];
}

#pragma mark - AVIMClientDelegate

- (void)imClientPaused:(AVIMClient *)imClient {
    [self updateConnectStatus];
}

- (void)imClientResuming:(AVIMClient *)imClient {
    [self updateConnectStatus];
}

- (void)imClientResumed:(AVIMClient *)imClient {
    [self updateConnectStatus];
}

#pragma mark - status

- (void)updateConnectStatus {
    self.connect = self.imClient.status == AVIMClientStatusOpened;
}

#pragma mark - AVIMMessageDelegate

- (void)conversation:(AVIMConversation *)conversation didReceiveCommonMessage:(AVIMMessage *)message {
    DLog();
}

- (void)conversation:(AVIMConversation *)conversation didReceiveTypedMessage:(AVIMTypedMessage *)message {
    DLog();
    if (message.messageId) {
        [self receiveMsg:message conv:conversation];
    }
    else {
        DLog(@"Receive Message , but MessageId is nil");
    }
}

- (void)conversation:(AVIMConversation *)conversation messageDelivered:(AVIMMessage *)message {
    DLog();
    if (message != nil) {
        [_storage updateStatus:AVIMMessageStatusDelivered byMsgId:message.messageId];
        [_notify postMsgNotify:(AVIMTypedMessage *)message];
    }
}

- (void)conversation:(AVIMConversation *)conversation membersAdded:(NSArray *)clientIds byClientId:(NSString *)clientId {
    DLog();
}

- (void)conversation:(AVIMConversation *)conversation membersRemoved:(NSArray *)clientIds byClientId:(NSString *)clientId {
    DLog();
}

- (void)conversation:(AVIMConversation *)conversation invitedByClientId:(NSString *)clientId {
    DLog();
}

- (void)conversation:(AVIMConversation *)conversation kickedByClientId:(NSString *)clientId {
    DLog();
}

- (id)convSignWithSelfId:(NSString *)selfId convid:(NSString *)convid targetIds:(NSArray *)targetIds action:(NSString *)action {
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    [dict setObject:selfId forKey:@"self_id"];
    if (convid) {
        [dict setObject:convid forKey:@"convid"];
    }
    if (targetIds) {
        [dict setObject:targetIds forKey:@"targetIds"];
    }
    if (action) {
        [dict setObject:action forKey:@"action"];
    }
    return [AVCloud callFunction:@"conv_sign" withParameters:dict];
}

- (AVIMSignature *)getAVSignatureWithParams:(NSDictionary *)fields peerIds:(NSArray *)peerIds {
    AVIMSignature *avSignature = [[AVIMSignature alloc] init];
    NSNumber *timestampNum = [fields objectForKey:@"timestamp"];
    long timestamp = [timestampNum longValue];
    NSString *nonce = [fields objectForKey:@"nonce"];
    NSString *signature = [fields objectForKey:@"signature"];
    
    [avSignature setTimestamp:timestamp];
    [avSignature setNonce:nonce];
    [avSignature setSignature:signature];
    return avSignature;
}

- (AVIMSignature *)signatureWithClientId:(NSString *)clientId
                          conversationId:(NSString *)conversationId
                                  action:(NSString *)action
                       actionOnClientIds:(NSArray *)clientIds {
    if ([action isEqualToString:@"open"] || [action isEqualToString:@"start"]) {
        action = nil;
    }
    if ([action isEqualToString:@"remove"]) {
        action = @"kick";
    }
    if ([action isEqualToString:@"add"]) {
        action = @"invite";
    }
    NSDictionary *dict = [self convSignWithSelfId:clientId convid:conversationId targetIds:clientIds action:action];
    if (dict != nil) {
        return [self getAVSignatureWithParams:dict peerIds:clientIds];
    }
    else {
        return nil;
    }
}

#pragma mark - File Utils

- (NSString *)getFilesPath {
    NSString *appPath = [NSSearchPathForDirectoriesInDomains(NSDocumentationDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    NSString *filesPath = [appPath stringByAppendingString:@"/files/"];
    NSFileManager *fileMan = [NSFileManager defaultManager];
    NSError *error;
    BOOL isDir = YES;
    if ([fileMan fileExistsAtPath:filesPath isDirectory:&isDir] == NO) {
        [fileMan createDirectoryAtPath:filesPath withIntermediateDirectories:YES attributes:nil error:&error];
        if (error) {
            [NSException raise:@"error when create dir" format:@"error"];
        }
    }
    return filesPath;
}

- (NSString *)getPathByObjectId:(NSString *)objectId {
    return [[self getFilesPath] stringByAppendingFormat:@"%@", objectId];
}

- (NSString *)tmpPath {
    return [[self getFilesPath] stringByAppendingFormat:@"tmp"];
}

- (NSString *)uuid {
    NSString *chars = @"abcdefghijklmnopgrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
    assert(chars.length == 62);
    int len = (int)chars.length;
    NSMutableString *result = [[NSMutableString alloc] init];
    for (int i = 0; i < 24; i++) {
        int p = arc4random_uniform(len);
        NSRange range = NSMakeRange(p, 1);
        [result appendString:[chars substringWithRange:range]];
    }
    return result;
}

#pragma mark - conv cache
- (AVIMConversation *)lookupConvById:(NSString *)convid {
    return [self.cachedConvs valueForKey:convid];
}

- (void)registerConvs:(NSArray *)convs {
    for (AVIMConversation *conv in convs) {
        [self.cachedConvs setValue:conv forKey:conv.conversationId];
    }
}

- (void)cacheConvsWithIds:(NSMutableSet *)convids callback:(AVArrayResultBlock)callback {
    NSMutableSet *uncacheConvids = [[NSMutableSet alloc] init];
    for (NSString *convid in convids) {
        if ([self lookupConvById:convid] == nil) {
            [uncacheConvids addObject:convid];
        }
    }
    [self fetchConvsWithConvids:uncacheConvids callback: ^(NSArray *objects, NSError *error) {
        if (error) {
            callback(nil, error);
        }
        else {
            [self registerConvs:objects];
            callback(objects, error);
        }
    }];
}

- (void)findRecentRoomsWithBlock:(AVArrayResultBlock)block {
    NSMutableArray *rooms = [[self.storage getRooms] mutableCopy];
    NSMutableSet *convids = [NSMutableSet set];
    for (CDRoom *room in rooms) {
        [convids addObject:room.convid];
    }
    WEAKSELF
    [self cacheConvsWithIds : convids callback : ^(NSArray *objects, NSError *error) {
        if (error) {
            block(nil, error);
        }
        else {
            NSMutableArray *filterRooms = [NSMutableArray array];
            for (CDRoom *room in rooms) {
                room.conv = [self lookupConvById:room.convid];
                if (room.conv) {
                    [filterRooms addObject:room];
                }
                else {
//                    [NSException raise:@"IM" format:@"conv is nil"];
                }
            }
            NSMutableSet *userIds = [NSMutableSet set];
            for (CDRoom *room in filterRooms) {
                if (room.conv.type == CDConvTypeSingle) {
                    [userIds addObject:room.conv.otherId];
                }
            }
            [[weakSelf imConfig].userDelegate cacheUserByIds:userIds block: ^(BOOL succeeded, NSError *error) {
                if (error) {
                    block(nil, error);
                }
                else {
                    block(filterRooms, error);
                }
            }];
        }
    }];
}

@end
