//
//  SearchMessagesView.m
//  Telegram
//
//  Created by keepcoder on 07.10.14.
//  Copyright (c) 2014 keepcoder. All rights reserved.
//

#import "SearchMessagesView.h"
#import "SpacemanBlocks.h"
@interface SearchMessagesView ()<TMSearchTextFieldDelegate>
@property (nonatomic,strong) TMSearchTextField *searchField;
@property (nonatomic,strong) TMTextButton *cancelButton;
@property (nonatomic,strong) BTRButton *nextButton;
@property (nonatomic,strong) BTRButton *prevButton;

@property (nonatomic,strong) NSProgressIndicator *progressIndicator;

@property (nonatomic,copy) void (^goToMessage)(int msg_id, NSString *searchString);
@property (nonatomic,copy) dispatch_block_t closeCallback;


@property (nonatomic,strong) RPCRequest *request;

@property (nonatomic,assign) BOOL locked;

@property (nonatomic,strong) SMDelayedBlockHandle block;

@property (nonatomic,strong) NSMutableArray *messages;
@property (nonatomic,assign) int currentIdx;


@end

@implementation SearchMessagesView


-(id)initWithFrame:(NSRect)frameRect {
    if(self = [super  initWithFrame:frameRect]) {
        
        self.searchField = [[TMSearchTextField alloc] initWithFrame:NSMakeRect(0, 0, NSWidth(frameRect) - 160, 30)];
        
        self.searchField.autoresizingMask = NSViewWidthSizable;
        
        self.searchField.wantsLayer = YES;
        
        [self addSubview:self.searchField];
        
        
        self.searchField.delegate = self;
        
        [self.searchField setCenterByView:self];
        
        self.cancelButton = [TMTextButton standartUserProfileButtonWithTitle:NSLocalizedString(@"Search.Cancel", nil)];
        
        weakify();
        
        [self.cancelButton setTapBlock:^ {
            strongSelf.closeCallback();
            [strongSelf.request cancelRequest];
            strongSelf.request = nil;
        }];
        
        [self.cancelButton setCenterByView:self];
        
        int minX = NSMinX(self.searchField.frame) + NSWidth(self.searchField.frame);
        int maxX = NSWidth(self.frame);
        
        int dif = ((maxX - minX) - NSWidth(self.cancelButton.frame)) /2;

        [self.cancelButton setFrameOrigin:NSMakePoint(minX + dif, NSMinY(self.cancelButton.frame))];
        
        
        self.cancelButton.autoresizingMask =   NSViewMinXMargin;
        
        [self addSubview:self.cancelButton];
        
        NSImage *searchUp = [NSImage imageNamed:@"SearchUp"];
        NSImage *searchDown = [NSImage imageNamed:@"SearchDown"];
        
        
        self.prevButton = [[BTRButton alloc] initWithFrame:NSMakeRect(0, 0, searchUp.size.width, searchUp.size.height)];
        self.nextButton = [[BTRButton alloc] initWithFrame:NSMakeRect(0, 0, searchDown.size.width, searchDown.size.height)];
        
        [self.prevButton setBackgroundImage:searchUp forControlState:BTRControlStateNormal];
        [self.nextButton setBackgroundImage:searchDown forControlState:BTRControlStateNormal];
        
        [self.prevButton addBlock:^(BTRControlEvents events) {
           [strongSelf prev];
        } forControlEvents:BTRControlEventClick];
        
        [self.nextButton addBlock:^(BTRControlEvents events) {
           [strongSelf next];
        } forControlEvents:BTRControlEventClick];
        
        
        [self.prevButton setCenterByView:self];
        [self.nextButton setCenterByView:self];
        
        [self.prevButton setFrameOrigin:NSMakePoint(23, NSMinY(self.prevButton.frame))];
        [self.nextButton setFrameOrigin:NSMakePoint(46, NSMinY(self.prevButton.frame))];
        
        self.progressIndicator = [[NSProgressIndicator alloc] initWithFrame:NSMakeRect(25, 0, 25, 25)];
        
        [self.progressIndicator setStyle:NSProgressIndicatorSpinningStyle];
        
        [self.progressIndicator setCenteredYByView:self];
        
        [self addSubview:_progressIndicator];
        
        _locked = YES;
        self.locked = NO;
        
        [self addSubview:self.prevButton];
        [self addSubview:self.nextButton];
        
    }
    
    return self;
}


-(BOOL)becomeFirstResponder {
    return [self.searchField becomeFirstResponder];
}

-(BOOL)resignFirstResponder {
    return [self.searchField resignFirstResponder];
}

-(void)searchFieldTextChange:(NSString *)searchString {
    
    self.locked = YES;
    
    _currentIdx = -1;
    
    cancel_delayed_block(_block);
    [_request cancelRequest];
    
    if(searchString)
    
    _block = perform_block_after_delay(0.4,  ^{
        
        _block = nil;
        
        [RPCRequest sendRequest:[TLAPI_messages_search createWithPeer:[Telegram conversation].inputPeer q:searchString filter:[TL_inputMessagesFilterEmpty create] min_date:0 max_date:0 offset:0 max_id:0 limit:100] successHandler:^(id request, TL_messages_messages *response) {
            
            self.locked = NO;
            
            if(response.messages.count > 0) {
                self.messages = response.messages;
                [self next];
            }
            
            
        } errorHandler:^(id request, RpcError *error) {
            self.locked = NO;
        }];
        
    });
    
  //  if(self.searchCallback != nil)
      //  self.searchCallback(searchString);
}

-(void)next {
    
    if(_messages.count == 0)
        return;
    
    if(++_currentIdx == _messages.count)
    {
        _currentIdx = 0;
    }
    
    _goToMessage([(TLMessage *)_messages[_currentIdx] n_id],_searchField.stringValue);
}

-(void)prev {
    if(_messages.count == 0)
        return;
    
    
    if(--_currentIdx == -1)
    {
        _currentIdx = (int)_messages.count - 1;
    }
    
    _goToMessage([(TLMessage *)_messages[_currentIdx] n_id],_searchField.stringValue);
}

-(void)setLocked:(BOOL)locked {
    
    if(_locked == locked)
        return;
    
    
    _locked = locked;
    
    if(_locked)
    {
        [self.progressIndicator startAnimation:self];
    } else {
        [self.progressIndicator stopAnimation:self];
    }
    
    [self.progressIndicator setHidden:!locked];
    [self.nextButton setHidden:locked];
    [self.prevButton setHidden:locked];
}

-(void)searchFieldDidEnter {
    [self next];
    
    [self.searchField setSelectedRange:NSMakeRange(self.searchField.stringValue.length,0)];
}

-(void)mouseDown:(NSEvent *)theEvent {
    
}

-(void)mouseUp:(NSEvent *)theEvent {
    
}



-(void)showSearchBox:( void (^)(int msg_id, NSString *searchString))callback closeCallback:(dispatch_block_t) closeCallback {
    
    self.goToMessage = callback;
    self.closeCallback = closeCallback;
    
}

- (void)drawRect:(NSRect)dirtyRect
{
    [super drawRect:dirtyRect];
    
    [[NSColor whiteColor] setFill];
    NSRectFill(self.bounds);
    
    [GRAY_BORDER_COLOR set];
    
    NSRectFill(NSMakeRect(0, 0, self.frame.size.width, 1));
    
}
@end
