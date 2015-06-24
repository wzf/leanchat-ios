//
//  CDChatRoomController.h
//  AVOSChatDemo
//
//  Created by Qihe Bian on 7/28/14.
//  Copyright (c) 2014 AVOS. All rights reserved.
//

#import "XHMessageTableViewController.h"
#import "CDIM.h"

@interface CDChatRoomVC : XHMessageTableViewController

@property (nonatomic, strong) AVIMConversation *conv;

@property (nonatomic, strong) NSMutableArray *msgs;

- (instancetype)initWithConv:(AVIMConversation *)conv;

@end
