//
//  IIInstantMessage.m
//  iChat Image Indexer
//
//  Created by Jonathon Mah on 2011-08-26.
//

#import "IIInstantMessage.h"


@implementation IIInstantMessage

@synthesize participant = _participant;
@synthesize date = _date;
@synthesize message = _message;

+ (void)registerInGlobalKeyedUnarchiver;
{
    [NSKeyedUnarchiver setClass:[IIInstantMessage class] forClassName:@"InstantMessage"];
    [NSKeyedUnarchiver setClass:[IIParticipant class] forClassName:@"Presentity"];
}

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
