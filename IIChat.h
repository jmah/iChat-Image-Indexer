//
//  IIChat.h
//  iChat Image Indexer
//
//  Created by Jonathon Mah on 2011-08-26.
//

#import <Foundation/Foundation.h>
#import <AddressBook/AddressBook.h>

@class IIParticipant;


@interface IIChat : NSObject

- (id)initWithData:(NSData *)chatData;
@property (readonly, copy) NSString *serviceName;
@property (readonly, copy) NSArray *participants;
@property (readonly, copy) NSArray *instantMessages;

@end


@interface IIInstantMessage : NSObject <NSCoding /* Decoding only */>

@property (readonly, retain) IIParticipant *participant;
@property (readonly, copy) NSDate *date;
@property (readonly, copy) NSAttributedString *message;

@end


@interface IIParticipant : NSObject <NSCoding /* Decoding only */>

@property (readonly, copy) NSString *accountName;
@property (readonly, retain) ABPerson *matchingPerson;
@property (readonly, copy) NSString *matchingPersonName;

@end
