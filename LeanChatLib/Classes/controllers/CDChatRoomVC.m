//
//  CDChatRoomController.m
//  AVOSChatDemo
//
//  Created by Qihe Bian on 7/28/14.
//  Copyright (c) 2014 AVOS. All rights reserved.
//

#import "CDChatRoomVC.h"

#import "XHDisplayTextViewController.h"
#import "XHDisplayMediaViewController.h"
#import "XHDisplayLocationViewController.h"
#import "XHAudioPlayerHelper.h"

#import "LZStatusView.h"
#import "CDStorage.h"
#import "CDEmotionUtils.h"
#import "AVIMConversation+Custom.h"

static NSInteger const kOnePageSize = 20;

@interface CDChatRoomVC ()

@property (atomic, assign) BOOL isLoadingMsg;

@property (nonatomic, strong) XHMessageTableViewCell *currentSelectedCell;

@property (nonatomic, strong) NSArray *emotionManagers;

@property (nonatomic, strong) LZStatusView *clientStatusView;

@end

@implementation CDChatRoomVC

#pragma mark - life cycle

- (instancetype)init {
    self = [super init];
    if (self) {
        // 配置输入框UI的样式
        //self.allowsSendVoice = NO;
        //self.allowsSendFace = NO;
        //self.allowsSendMultiMedia = NO;
        _isLoadingMsg = NO;
    }
    return self;
}

- (instancetype)initWithConv:(AVIMConversation *)conv {
    self = [self init];
    self.conv = conv;
    return self;
}

- (void)initBarButton {
    UIBarButtonItem *backBtn = [[UIBarButtonItem alloc] initWithTitle:@"返回"
                                                                style:UIBarButtonItemStyleBordered
                                                               target:nil
                                                               action:nil];
    [[self navigationItem] setBackBarButtonItem:backBtn];
}

#pragma mark - Propertys 

- (LZStatusView *)clientStatusView {
    if (_clientStatusView == nil) {
        _clientStatusView = [[LZStatusView alloc] initWithFrame:CGRectMake(0, 64, self.messageTableView.frame.size.width, kLZStatusViewHight)];
    }
    return _clientStatusView;
}

- (void)initBottomMenuAndEmotionView {
    NSMutableArray *shareMenuItems = [NSMutableArray array];
    NSArray *plugIcons = @[@"sharemore_pic", @"sharemore_video"];
    NSArray *plugTitle = @[@"照片", @"拍摄"];
    for (NSString *plugIcon in plugIcons) {
        XHShareMenuItem *shareMenuItem = [[XHShareMenuItem alloc] initWithNormalIconImage:[UIImage imageNamed:plugIcon] title:[plugTitle objectAtIndex:[plugIcons indexOfObject:plugIcon]]];
        [shareMenuItems addObject:shareMenuItem];
    }
    self.shareMenuItems = shareMenuItems;
    [self.shareMenuView reloadData];
    
    _emotionManagers = [CDEmotionUtils emotionManagers];
    self.emotionManagerView.isShowEmotionStoreButton = YES;
    [self.emotionManagerView reloadData];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self initBarButton];
    [self initBottomMenuAndEmotionView];
    [self.view addSubview:self.clientStatusView];
    self.clientStatusView.hidden = YES;
    id <CDUserModel> curUser = [CDIM sharedInstance].selfUser;
    // 设置自身用户名
    self.messageSender = [curUser username];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(receiveMessage:) name:kCDNotificationMessageReceived object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onMessageDelivered:) name:kCDNotificationMessageDelivered object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refreshConv) name:kCDNotificationConversationUpdated object:nil];
    [[CDStorage storage] clearUnreadWithConvid:self.conv.conversationId];
    [self refreshConv];
    [self loadMessagesWhenInit];
    [[CDIM sharedInstance] addObserver:self forKeyPath:@"connect" options:NSKeyValueObservingOptionNew context:NULL];
    [self updateStatusView];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kCDNotificationMessageReceived object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kCDNotificationConversationUpdated object:nil];
    if (self.msgs.count > 0) {
        [[CDStorage storage] insertRoomWithConvid:self.conv.conversationId];
    }
    [[CDStorage storage] clearUnreadWithConvid:self.conv.conversationId];
    [[CDIM sharedInstance] removeObserver:self forKeyPath:@"connect"];
    [[XHAudioPlayerHelper shareInstance] stopAudio];
}

- (void)dealloc {
    [[XHAudioPlayerHelper shareInstance] setDelegate:nil];
}

#pragma mark - prev and next controller

- (void)backPressed:(id)sender {
    [self.navigationController popViewControllerAnimated:YES];
}

#pragma mark - message data

- (NSDate *)getTimestampDate:(int64_t)timestamp {
    return [NSDate dateWithTimeIntervalSince1970:timestamp / 1000];
}

- (XHMessage *)getXHMessageByMsg:(AVIMTypedMessage *)msg {
    id <CDUserModel> fromUser = [[CDIM sharedInstance].userDelegate getUserById:msg.clientId];
    XHMessage *xhMessage;
    NSDate *time = [self getTimestampDate:msg.sendTimestamp];
    if (msg.mediaType == kAVIMMessageMediaTypeText) {
        AVIMTextMessage *textMsg = (AVIMTextMessage *)msg;
        xhMessage = [[XHMessage alloc] initWithText:[CDEmotionUtils emojiStringFromString:textMsg.text] sender:fromUser.username timestamp:time];
    }
    else if (msg.mediaType == kAVIMMessageMediaTypeAudio) {
        AVIMAudioMessage *audioMsg = (AVIMAudioMessage *)msg;
        NSString *duration = [NSString stringWithFormat:@"%.0f", audioMsg.duration];
        NSString *voicePath = [[CDIM sharedInstance] getPathByObjectId:audioMsg.messageId];
        xhMessage = [[XHMessage alloc] initWithVoicePath:voicePath voiceUrl:nil voiceDuration:duration sender:fromUser.username timestamp:time];
    }
    else if (msg.mediaType == kAVIMMessageMediaTypeLocation) {
        AVIMLocationMessage *locationMsg = (AVIMLocationMessage *)msg;
        xhMessage = [[XHMessage alloc] initWithLocalPositionPhoto:[UIImage imageNamed:@"Fav_Cell_Loc"] geolocations:locationMsg.text location:[[CLLocation alloc] initWithLatitude:locationMsg.latitude longitude:locationMsg.longitude] sender:fromUser.username timestamp:time];
    }
    else if (msg.mediaType == kAVIMMessageMediaTypeImage) {
        AVIMImageMessage *imageMsg = (AVIMImageMessage *)msg;
        DLog(@"%@", imageMsg);
        xhMessage = [[XHMessage alloc] initWithPhoto:nil thumbnailUrl:imageMsg.file.url originPhotoUrl:imageMsg.file.url sender:fromUser.username timestamp:time];
    }
    else {
        xhMessage = [[XHMessage alloc] initWithText:@"未知消息" sender:fromUser.username timestamp:time];
        DLog("unkonwMessage");
    }
    xhMessage.avator = nil;
    xhMessage.avatorUrl = [fromUser avatarUrl];
    
    if ([[CDIM sharedInstance].selfId isEqualToString:msg.clientId]) {
        xhMessage.bubbleMessageType = XHBubbleMessageTypeSending;
    }
    else {
        xhMessage.bubbleMessageType = XHBubbleMessageTypeReceiving;
    }
    NSInteger msgStatuses[4] = { AVIMMessageStatusSending, AVIMMessageStatusSent, AVIMMessageStatusDelivered, AVIMMessageStatusFailed };
    NSInteger xhMessageStatuses[4] = { XHMessageStatusSending, XHMessageStatusSent, XHMessageStatusReceived, XHMessageStatusFailed };
    
    if (self.conv.type == CDConvTypeGroup) {
        if (msg.status == AVIMMessageStatusSent) {
            msg.status = AVIMMessageStatusDelivered;
        }
    }
    if (xhMessage.bubbleMessageType == XHBubbleMessageTypeSending) {
        XHMessageStatus status = XHMessageStatusReceived;
        int i;
        for (i = 0; i < 4; i++) {
            if (msgStatuses[i] == msg.status) {
                status = xhMessageStatuses[i];
                break;
            }
        }
        xhMessage.status = status;
    }
    else {
        xhMessage.status = XHMessageStatusReceived;
    }
    return xhMessage;
}

- (void)refreshConv {
    self.title = self.conv.title;
}

- (NSArray *)getXHMessages:(NSArray *)msgs {
    NSMutableArray *messages = [[NSMutableArray alloc] init];
    for (AVIMTypedMessage *msg in msgs) {
        XHMessage *xhMsg = [self getXHMessageByMsg:msg];
        if (xhMsg) {
            [messages addObject:xhMsg];
        }
    }
    return messages;
}

- (void)runInMainQueue:(void (^)())queue {
    dispatch_async(dispatch_get_main_queue(), queue);
}

- (void)runInGlobalQueue:(void (^)())queue {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), queue);
}

#pragma mark - query messages

- (void)queryAndCacheMessagesWithTimestamp:(int64_t)timestamp block:(AVIMArrayResultBlock)block {
    [[CDIM sharedInstance] queryTypedMessagesWithConversation:self.conv timestamp:timestamp limit:kOnePageSize block:^(NSArray *msgs, NSError *error) {
        if (error) {
            block(msgs, error);
        } else {
            [self cacheMsgs:msgs callback:^(BOOL succeeded, NSError *error) {
                block (msgs, error);
            }];
        }
    }];
}

- (void)loadMessagesWhenInit {
    if (self.isLoadingMsg) {
        return;
    } else {
        self.isLoadingMsg = YES;
        [self queryAndCacheMessagesWithTimestamp:0 block:^(NSArray *msgs, NSError *error) {
            if ([self filterError:error]) {
                NSMutableArray *xhMsgs = [[self getXHMessages:msgs] mutableCopy];
                self.messages = xhMsgs;
                _msgs = msgs;
                [self.messageTableView reloadData];
                [self scrollToBottomAnimated:NO];
            }
            self.isLoadingMsg = NO;
        }];
    }
}

- (void)loadOldMessages{
    if (self.messages.count == 0 || self.isLoadingMsg) {
        return;
    } else {
        self.isLoadingMsg = YES;
        AVIMTypedMessage *msg = [self.msgs objectAtIndex:0];
        int64_t timestamp = msg.sendTimestamp;
        [self queryAndCacheMessagesWithTimestamp:timestamp block:^(NSArray *msgs, NSError *error) {
            if ([self filterError:error]) {
                NSMutableArray *xhMsgs = [[self getXHMessages:msgs] mutableCopy];
                NSMutableArray *newMsgs = [NSMutableArray arrayWithArray:msgs];
                [newMsgs addObjectsFromArray:self.msgs];
                self.msgs = newMsgs;
                [self insertOldMessages:xhMsgs completion: ^{
                    self.isLoadingMsg = NO;
                }];
            } else {
                self.isLoadingMsg = NO;
            }
        }];
    }
}

- (void)cacheMsgs:(NSArray *)msgs callback:(AVBooleanResultBlock)callback {
    [self runInGlobalQueue:^{
        __block NSMutableSet *userIds = [[NSMutableSet alloc] init];
        for (AVIMTypedMessage *msg in msgs) {
            [userIds addObject:msg.clientId];
            if (msg.mediaType == kAVIMMessageMediaTypeImage ||
                msg.mediaType == kAVIMMessageMediaTypeAudio) {
                NSString *path = [[CDIM sharedInstance] getPathByObjectId:msg.messageId];
                NSFileManager *fileMan = [NSFileManager defaultManager];
                if ([fileMan fileExistsAtPath:path] == NO) {
                    NSData *data = [msg.file getData];
                    [data writeToFile:path atomically:YES];
                }
            }
        }
        if ([[CDIM sharedInstance].userDelegate respondsToSelector:@selector(cacheUserByIds:block:)]) {
            [[CDIM sharedInstance].userDelegate cacheUserByIds:userIds block:^(BOOL succeeded, NSError *error) {
                [self runInMainQueue:^{
                    callback(succeeded, error);
                }];
            }];
        } else {
            [self runInMainQueue:^{
                callback(YES, nil);
            }];
        }
    }];
}

- (void)insertMessage:(AVIMTypedMessage *)message {
    if (self.isLoadingMsg) {
        [self performSelector:@selector(insertMessage:) withObject:message afterDelay:1];
        return;
    }
    self.isLoadingMsg = YES;
    [self cacheMsgs:@[message] callback:^(BOOL succeeded, NSError *error) {
        if ([self filterError:error]) {
            XHMessage *xhMessage = [self getXHMessageByMsg:message];
            [self.msgs addObject:message];
            [self.messages addObject:xhMessage];
            NSIndexPath *indexPath = [NSIndexPath indexPathForRow:self.msgs.count -1 inSection:0];
            [self.messageTableView insertRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
            [self scrollToBottomAnimated:YES];
        }
        self.isLoadingMsg = NO;
    }];
}

#pragma mark - XHMessageTableViewCell delegate

- (void)multiMediaMessageDidSelectedOnMessage:(id <XHMessageModel> )message atIndexPath:(NSIndexPath *)indexPath onMessageTableViewCell:(XHMessageTableViewCell *)messageTableViewCell {
    UIViewController *disPlayViewController;
    switch (message.messageMediaType) {
        case XHBubbleMessageMediaTypeVideo:
        case XHBubbleMessageMediaTypePhoto: {
            XHDisplayMediaViewController *messageDisplayTextView = [[XHDisplayMediaViewController alloc] init];
            messageDisplayTextView.message = message;
            disPlayViewController = messageDisplayTextView;
            break;
        }
            break;
            
        case XHBubbleMessageMediaTypeVoice: {
            // Mark the voice as read and hide the red dot.
            //message.isRead = YES;
            //messageTableViewCell.messageBubbleView.voiceUnreadDotImageView.hidden = YES;
            
            [[XHAudioPlayerHelper shareInstance] setDelegate:self];
            if (_currentSelectedCell) {
                [_currentSelectedCell.messageBubbleView.animationVoiceImageView stopAnimating];
            }
            if (_currentSelectedCell == messageTableViewCell) {
                [messageTableViewCell.messageBubbleView.animationVoiceImageView stopAnimating];
                [[XHAudioPlayerHelper shareInstance] stopAudio];
                self.currentSelectedCell = nil;
            }
            else {
                self.currentSelectedCell = messageTableViewCell;
                [messageTableViewCell.messageBubbleView.animationVoiceImageView startAnimating];
                [[XHAudioPlayerHelper shareInstance] managerAudioWithFileName:message.voicePath toPlay:YES];
            }
            break;
        }
            
        case XHBubbleMessageMediaTypeEmotion:
            DLog(@"facePath : %@", message.emotionPath);
            break;
            
        case XHBubbleMessageMediaTypeLocalPosition: {
            DLog(@"facePath : %@", message.localPositionPhoto);
            XHDisplayLocationViewController *displayLocationViewController = [[XHDisplayLocationViewController alloc] init];
            displayLocationViewController.message = message;
            disPlayViewController = displayLocationViewController;
            break;
        }
            
        default:
            break;
    }
    if (disPlayViewController) {
        [self.navigationController pushViewController:disPlayViewController animated:YES];
    }
}

- (void)didDoubleSelectedOnTextMessage:(id <XHMessageModel> )message atIndexPath:(NSIndexPath *)indexPath {
    DLog(@"text : %@", message.text);
    XHDisplayTextViewController *displayTextViewController = [[XHDisplayTextViewController alloc] init];
    displayTextViewController.message = message;
    [self.navigationController pushViewController:displayTextViewController animated:YES];
}

- (void)didSelectedAvatorOnMessage:(id <XHMessageModel> )message atIndexPath:(NSIndexPath *)indexPath {
    DLog(@"indexPath : %@", indexPath);
}

- (void)menuDidSelectedAtBubbleMessageMenuSelecteType:(XHBubbleMessageMenuSelecteType)bubbleMessageMenuSelecteType {
}

- (void)didRetrySendMessage:(id <XHMessageModel> )message atIndexPath:(NSIndexPath *)indexPath {
    AVIMTypedMessage *msg = [_msgs objectAtIndex:indexPath.row];
    XHMessage *xhMsg = (XHMessage *)message;
    xhMsg.status = XHMessageStatusSending;
    [self.messageTableView reloadData];
    [self resendMsg:msg];
}

#pragma mark - XHAudioPlayerHelper Delegate

- (void)didAudioPlayerStopPlay:(AVAudioPlayer *)audioPlayer {
    if (!_currentSelectedCell) {
        return;
    }
    [_currentSelectedCell.messageBubbleView.animationVoiceImageView stopAnimating];
    self.currentSelectedCell = nil;
}

#pragma mark - XHEmotionManagerView DataSource

- (NSInteger)numberOfEmotionManagers {
    return self.emotionManagers.count;
}

- (XHEmotionManager *)emotionManagerForColumn:(NSInteger)column {
    return [self.emotionManagers objectAtIndex:column];
}

- (NSArray *)emotionManagersAtManager {
    return self.emotionManagers;
}

#pragma mark - XHMessageTableViewController Delegate

- (BOOL)shouldLoadMoreMessagesScrollToTop {
    return YES;
}

- (void)loadMoreMessagesScrollTotop {
    [self loadOldMessages];
}

#pragma mark - send message

- (void)sendFileMsgWithPath:(NSString *)path type:(AVIMMessageMediaType)type {
    AVIMTypedMessage *msg;
    if (type == kAVIMMessageMediaTypeImage) {
        msg = [AVIMImageMessage messageWithText:nil attachedFilePath:path attributes:nil];
    }
    else {
        msg = [AVIMAudioMessage messageWithText:nil attachedFilePath:path attributes:nil];
    }
    [self sendMsg:msg originFilePath:path];
}

- (void)sendImage:(UIImage *)image {
    NSData *imageData = UIImageJPEGRepresentation(image, 0.6);
    NSString *path = [[CDIM sharedInstance] tmpPath];
    NSError *error;
    [imageData writeToFile:path options:NSDataWritingAtomic error:&error];
    if (error == nil) {
        [self sendFileMsgWithPath:path type:kAVIMMessageMediaTypeImage];
    }
    else {
        [self alert:@"write image to file error"];
    }
}

- (void)sendLocationWithLatitude:(double)latitude longitude:(double)longitude address:(NSString *)address {
    AVIMLocationMessage *locMsg = [AVIMLocationMessage messageWithText:nil latitude:latitude longitude:longitude attributes:nil];
    [self sendMsg:locMsg originFilePath:nil];
}

- (void)sendMsg:(AVIMTypedMessage *)msg originFilePath:(NSString *)path {
    [self.conv sendMessage:msg options:AVIMMessageSendOptionRequestReceipt callback: ^(BOOL succeeded, NSError *error) {
        if (error) {
            // 赋值一个临时的messageId，因为发送失败，messageId，sendTimestamp不能从服务端获取
            // resend 成功的时候再改过来
            msg.messageId = [[CDIM sharedInstance] uuid];
            msg.sendTimestamp = [[NSDate date] timeIntervalSince1970] * 1000;
        }
        if (path && error == nil) {
            NSString *newPath = [[CDIM sharedInstance] getPathByObjectId:msg.messageId];
            NSError *error1;
            [[NSFileManager defaultManager] moveItemAtPath:path toPath:newPath error:&error1];
            DLog(@"%@", newPath);
        }
        [self insertMessage:msg];
//        [_storage insertMsg:msg];
//        [self loadMsgsWithLoadMore:NO];
    }];
}

- (void)resendMsg:(AVIMTypedMessage *)msg {
    NSString *tmpId = msg.messageId;
    [self.conv sendMessage:msg options:AVIMMessageSendOptionRequestReceipt callback: ^(BOOL succeeded, NSError *error) {
        if (error) {
            [self alertError:error];
        }
        else {
//            [_storage updateFailedMsg:msg byTmpId:tmpId];
        }
//        [self loadMsgsWithLoadMore:NO];
    }];
}

- (void)receiveMessage:(NSNotification *)notification {
    AVIMTypedMessage *message = notification.object;
    if ([message.conversationId isEqualToString:self.conv.conversationId]) {
        [self insertMessage:message];
    }
}

- (void)onMessageDelivered:(NSNotification *)notification {
    AVIMTypedMessage *message = notification.object;
    if ([message.conversationId isEqualToString:self.conv.conversationId]) {
        AVIMTypedMessage *foundMessage;
        NSInteger pos;
        for (pos = 0; pos < self.msgs.count; pos++) {
            AVIMTypedMessage *msg = self.msgs[pos];
            if ([msg.messageId isEqualToString:message.messageId]) {
                foundMessage = msg;
                break;
            }
        }
        if (foundMessage !=nil) {
            foundMessage.status = AVIMMessageStatusDelivered;
            XHMessage *xhMsg = [self getXHMessageByMsg:foundMessage];
            [self.messages setObject:xhMsg atIndexedSubscript:pos];
            NSIndexPath *indexPath = [NSIndexPath indexPathForRow:pos inSection:0];
            [self.messageTableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
            [self scrollToBottomAnimated:YES];
        }
    }
}

#pragma mark - didSend delegate

//发送文本消息的回调方法
- (void)didSendText:(NSString *)text fromSender:(NSString *)sender onDate:(NSDate *)date {
    if ([text length] > 0) {
        AVIMTextMessage *msg = [AVIMTextMessage messageWithText:[CDEmotionUtils plainStringFromEmojiString:text] attributes:nil];
        [self sendMsg:msg originFilePath:nil];
        [self finishSendMessageWithBubbleMessageType:XHBubbleMessageMediaTypeText];
    }
}

//发送图片消息的回调方法
- (void)didSendPhoto:(UIImage *)photo fromSender:(NSString *)sender onDate:(NSDate *)date {
    [self sendImage:photo];
    [self finishSendMessageWithBubbleMessageType:XHBubbleMessageMediaTypePhoto];
}

// 发送视频消息的回调方法
- (void)didSendVideoConverPhoto:(UIImage *)videoConverPhoto videoPath:(NSString *)videoPath fromSender:(NSString *)sender onDate:(NSDate *)date {
}

// 发送语音消息的回调方法
- (void)didSendVoice:(NSString *)voicePath voiceDuration:(NSString *)voiceDuration fromSender:(NSString *)sender onDate:(NSDate *)date {
    [self sendFileMsgWithPath:voicePath type:kAVIMMessageMediaTypeAudio];
}

// 发送表情消息的回调方法
- (void)didSendEmotion:(NSString *)emotion fromSender:(NSString *)sender onDate:(NSDate *)date {
    UITextView *textView = self.messageInputView.inputTextView;
    NSRange range = [textView selectedRange];
    NSMutableString *str = [[NSMutableString alloc] initWithString:textView.text];
    [str deleteCharactersInRange:range];
    [str insertString:emotion atIndex:range.location];
    textView.text = [CDEmotionUtils emojiStringFromString:str];
    textView.selectedRange = NSMakeRange(range.location + emotion.length, 0);
    [self finishSendMessageWithBubbleMessageType:XHBubbleMessageMediaTypeEmotion];
}

- (void)didSendGeoLocationsPhoto:(UIImage *)geoLocationsPhoto geolocations:(NSString *)geolocations location:(CLLocation *)location fromSender:(NSString *)sender onDate:(NSDate *)date {
    [self finishSendMessageWithBubbleMessageType:XHBubbleMessageMediaTypeLocalPosition];
}

#pragma mark -  ui config

// 是否显示时间轴Label的回调方法
- (BOOL)shouldDisplayTimestampForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row == 0) {
        return YES;
    }
    else {
        XHMessage *msg = [self.messages objectAtIndex:indexPath.row];
        XHMessage *lastMsg = [self.messages objectAtIndex:indexPath.row - 1];
        int interval = [msg.timestamp timeIntervalSinceDate:lastMsg.timestamp];
        if (interval > 60 * 3) {
            return YES;
        }
        else {
            return NO;
        }
    }
}

// 配置Cell的样式或者字体
- (void)configureCell:(XHMessageTableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath {
    XHMessage *msg = [self.messages objectAtIndex:indexPath.row];
    if ([self shouldDisplayTimestampForRowAtIndexPath:indexPath]) {
        NSDate *ts = msg.timestamp;
        NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
        [dateFormatter setDateFormat:@"MM-dd HH:mm"];
        NSString *str = [dateFormatter stringFromDate:ts];
        cell.timestampLabel.text = str;
    }
    SETextView *textView = cell.messageBubbleView.displayTextView;
    if (msg.bubbleMessageType == XHBubbleMessageTypeSending) {
        [textView setTextColor:[UIColor whiteColor]];
    }
    else {
        [textView setTextColor:[UIColor blackColor]];
    }
}

// 协议回掉是否支持用户手动滚动
- (BOOL)shouldPreventScrollToBottomWhileUserScrolling {
    return YES;
}

- (void)didSelecteShareMenuItem:(XHShareMenuItem *)shareMenuItem atIndex:(NSInteger)index {
    [super didSelecteShareMenuItem:shareMenuItem atIndex:index];
}

#pragma mark - client status

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (object == [CDIM sharedInstance] && [keyPath isEqualToString:@"connect"]) {
        [self updateStatusView];
    }
}

- (void)updateStatusView {
    if ([CDIM sharedInstance].connect) {
        self.clientStatusView.hidden = YES;
    }else {
        self.clientStatusView.hidden = NO;
    }
}

#pragma mark - alert error

- (void)alert:(NSString *)msg {
    UIAlertView *alertView = [[UIAlertView alloc]
                              initWithTitle:nil message:msg delegate:nil
                              cancelButtonTitle   :@"确定" otherButtonTitles:nil];
    [alertView show];
}

- (BOOL)alertError:(NSError *)error {
    if (error) {
        if (error.code == kAVIMErrorConnectionLost) {
            [self alert:@"未能连接聊天服务"];
        }
        else if ([error.domain isEqualToString:NSURLErrorDomain]) {
            [self alert:@"网络连接发生错误"];
        }
        else {
            [self alert:[NSString stringWithFormat:@"%@", error]];
        }
        return YES;
    }
    return NO;
}

- (BOOL)filterError:(NSError *)error {
    return [self alertError:error] == NO;
}

@end
