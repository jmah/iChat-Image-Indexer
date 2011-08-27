//
//  main.m
//  iChat Image Indexer
//
//  Created by Jonathon Mah on 2011-08-26.
//

#import <Cocoa/Cocoa.h>

#import "IIChat.h"


int main(int argc, const char *argv[])
{
    @autoreleasepool {
        NSFileManager *fm = [NSFileManager defaultManager];
        NSMutableArray *chatFiles = [NSMutableArray new];
        
        for (NSUInteger i = 1; i < argc; i++) {
            NSString *argString = [NSString stringWithCString:argv[i] encoding:NSUTF8StringEncoding];
//            BOOL directory;
//            if ([fm fileExistsAtPath:argString isDirectory:&directory] && !directory)
            [chatFiles addObject:argString];
        }
        
        NSSet *const imageTypesSet = [NSSet setWithArray:[NSImage imageFileTypes]];
        
        for (NSString *path in chatFiles) {
            @autoreleasepool {
                __autoreleasing NSError *readError;
                NSData *mappedData = [NSData dataWithContentsOfFile:path options:NSMappedRead error:&readError];
                if (!mappedData) {
                    fputs([[NSString stringWithFormat:@"Unable to read file %@: %@\n", path, readError] UTF8String], stderr);
                    continue;
                }
                
                IIChat *chat = [[IIChat alloc] initWithData:mappedData];
                if (!chat) {
                    fputs([[NSString stringWithFormat:@"Unable to parse messages from %@\n", path] UTF8String], stderr);
                    continue;
                }
                
                NSLog(@"In chat with: %@", [chat.participants valueForKey:@"accountName"]);
                for (IIInstantMessage *instantMessage in chat.instantMessages) {
                    if (![instantMessage.message containsAttachments])
                        continue;
                    
                    NSRange fullRange = NSMakeRange(0, instantMessage.message.length);
                    [instantMessage.message enumerateAttribute:NSAttachmentAttributeName inRange:fullRange options:0 usingBlock:^(NSTextAttachment *attachment, NSRange range, BOOL *stop) {
                        NSFileWrapper *fileWrapper = attachment.fileWrapper;
                        if (![fileWrapper isRegularFile])
                            return;
                        
                        // Decide whether this is an image purely from the extension right now
                        if (![imageTypesSet containsObject:[fileWrapper.preferredFilename pathExtension]])
                            return;
                        
                        
                        
                        
                        // <#Write image somewhere#>
                        NSLog(@"%@: %@", instantMessage.participant.accountName, fileWrapper.preferredFilename);
                    }];
                }
            }
        }
    }
    return 0;
}
