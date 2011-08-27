//
//  IIInstantMessage.m
//  iChat Image Indexer
//
//  Created by Jonathon Mah on 2011-08-26.
//

#import "IIChat.h"


@implementation IIChat

@synthesize participants = _participants;
@synthesize instantMessages = _instantMessages;

+ (void)initialize;
{
    if (self != [IIChat class])
        return;
    [NSKeyedUnarchiver setClass:[IIInstantMessage class] forClassName:@"InstantMessage"];
    [NSKeyedUnarchiver setClass:[IIParticipant class] forClassName:@"Presentity"];
}

- (id)initWithData:(NSData *)chatData;
{
    if (!(self = [super init]))
        return nil;
    
    @try {
        id rootObject = [NSKeyedUnarchiver unarchiveObjectWithData:chatData];
        if (![rootObject isKindOfClass:[NSArray class]] || [rootObject count] != 8)
            return nil;
        
        NSArray *rootArray = rootObject;
        _instantMessages = [rootArray objectAtIndex:2];
        if (_instantMessages.count && ![_instantMessages.lastObject isKindOfClass:[IIInstantMessage class]])
            return nil;
        _participants = [rootArray objectAtIndex:3];
        if (_participants.count && ![_participants.lastObject isKindOfClass:[IIParticipant class]])
            return nil;
    }
    @catch (...) {
        return nil;
    }
    
    return self;
}

@end


@implementation IIInstantMessage

@synthesize participant = _participant;
@synthesize date = _date;
@synthesize message = _message;

- (id)initWithCoder:(NSCoder *)decoder;
{
    if (!(self = [super init]))
        return nil;
    _participant = [decoder decodeObjectForKey:@"Sender"];
    _date = [decoder decodeObjectForKey:@"Time"];
    _message = [decoder decodeObjectForKey:@"MessageText"];
    return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder;
{ NSAssert1(NO, @"%@ does not allow encoding.", [self class]); }

@end



@implementation IIParticipant

@synthesize accountName = _accountName;
@synthesize matchingPerson = _lazyPerson;

- (id)initWithCoder:(NSCoder *)decoder;
{
    if (!(self = [super init]))
        return nil;
    _accountName = [decoder decodeObjectForKey:@"ID"];
    return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder;
{ NSAssert1(NO, @"%@ does not allow encoding.", [self class]); }

- (ABPerson *)matchingPerson;
{
    if (!_lazyPerson) {
        ABSearchElement *imNick = [ABPerson searchElementForProperty:kABInstantMessageProperty label:nil key:kABInstantMessageUsernameKey value:self.accountName comparison:kABEqualCaseInsensitive];
        ABRecord *record = [[[ABAddressBook sharedAddressBook] recordsMatchingSearchElement:imNick] lastObject];
        if ([record isKindOfClass:[ABPerson class]])
            _lazyPerson = (id)record;
        else
            _lazyPerson = (id)[NSNull null];
    }
    return ((id)_lazyPerson != [NSNull null]) ? _lazyPerson : nil;
}

@end
