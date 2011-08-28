//
//  main.m
//  iChat Image Indexer
//
//  Created by Jonathon Mah on 2011-08-26.
//

#import <Cocoa/Cocoa.h>
#import <sys/xattr.h>

#import "IIChat.h"


int main(int argc, const char *argv[])
{
    @autoreleasepool {
        NSFileManager *fm = [NSFileManager defaultManager];
        
        BOOL remainingArgsArePaths = NO;
        NSMutableArray *optionArgs = [NSMutableArray new];
        NSMutableArray *pathArgs = [NSMutableArray new];
        
        for (NSUInteger i = 1; i < argc; i++) {
            NSString *argString = [NSString stringWithCString:argv[i] encoding:NSUTF8StringEncoding];
            
            if (remainingArgsArePaths || ![argString hasPrefix:@"-"])
                [pathArgs addObject:argString];
            else if ([argString isEqual:@"--"])
                remainingArgsArePaths = YES;
            else
                [optionArgs addObject:argString];
        }
        
        // Parse options
        BOOL rewriteExistingChats = [optionArgs containsObject:@"-f"];
        
        
        NSSet *const imageTypesSet = [NSSet setWithArray:[NSImage imageFileTypes]];
        NSURL *const baseDirectoryForEachChat = ({
            NSURL *cachesURL = [fm URLsForDirectory:NSCachesDirectory inDomains:NSUserDomainMask].lastObject;
            if (!cachesURL) {
                fputs([[NSString stringWithFormat:@"Unable to get path to user-local caches directory, aborting.\n"] UTF8String], stderr);
                exit(EXIT_FAILURE);
            }
            [[cachesURL URLByAppendingPathComponent:@"Metadata"] URLByAppendingPathComponent:@"iChat Image Indexer"];
        });
        
        void (^writeImageFilesForChatPath)() = ^(NSString *path) {
            __autoreleasing NSError *readError;
            NSData *mappedData = [NSData dataWithContentsOfFile:path options:NSMappedRead error:&readError];
            if (!mappedData) {
                fputs([[NSString stringWithFormat:@"Unable to read file %@: %@\n", path, readError] UTF8String], stderr);
                return;
            }
            
            IIChat *chat = [[IIChat alloc] initWithData:mappedData];
            if (!chat) {
                fputs([[NSString stringWithFormat:@"Unable to parse messages from %@\n", path] UTF8String], stderr);
                return;
            }
            
            NSIndexSet *messageIndexesWithAttachments = [chat.instantMessages indexesOfObjectsPassingTest:^BOOL(IIInstantMessage *im, NSUInteger idx, BOOL *stop) {
                return [im.message containsAttachments];
            }];
            if (messageIndexesWithAttachments.count == 0)
                return;
            
            NSURL *imageDirectoryForThisChat = [baseDirectoryForEachChat URLByAppendingPathComponent:path.lastPathComponent.stringByDeletingPathExtension];
            if (!rewriteExistingChats && [fm fileExistsAtPath:imageDirectoryForThisChat.path])
                return;
            
            __autoreleasing NSError *directoryError;
            if (![fm createDirectoryAtURL:imageDirectoryForThisChat withIntermediateDirectories:YES attributes:nil error:&directoryError]) {
                fputs([[NSString stringWithFormat:@"Unable to create directory for chat images at %@: %@", imageDirectoryForThisChat.path, directoryError] UTF8String], stderr);
                return;
            }
            
            // Copy metadata from chat
            NSArray *metadataKeys = [NSArray arrayWithObjects:(__bridge id)kMDItemDeliveryType, kMDItemInstantMessageAddresses, kMDItemDescription, kMDItemContentCreationDate, nil];
            MDItemRef mdItem = MDItemCreate(NULL, (__bridge CFStringRef)path);
            NSDictionary *baseChatMetadata = (__bridge_transfer id)MDItemCopyAttributes(mdItem, (__bridge CFArrayRef)metadataKeys);
            CFRelease(mdItem);
            
            NSMutableDictionary *chatMetadata = [baseChatMetadata mutableCopy];
            [chatMetadata setObject:@"iChat" forKey:(__bridge id)kMDItemCreator];
            
            // Enumerate the images
            [chat.instantMessages enumerateObjectsAtIndexes:messageIndexesWithAttachments options:0 usingBlock:^(IIInstantMessage *im, NSUInteger imIndex, BOOL *stop) {
                NSRange fullRange = NSMakeRange(0, im.message.length);
                __block NSUInteger imageIndex = 0;
                [im.message enumerateAttribute:NSAttachmentAttributeName inRange:fullRange options:0 usingBlock:^(NSTextAttachment *attachment, NSRange range, BOOL *stop) {
                    NSFileWrapper *fileWrapper = attachment.fileWrapper;
                    if (![fileWrapper isRegularFile])
                        return;
                    
                    // Decide whether this is an image purely from the extension right now
                    if (![imageTypesSet containsObject:fileWrapper.preferredFilename.pathExtension])
                        return;
                    
                    // Create a unique filename for this (chat message, image) pair, so we can overwrite knowing it'll be the same
                    NSString *uniqueFilename = [NSString stringWithFormat:@"%04lu %lu - %@", imIndex, imageIndex++, fileWrapper.preferredFilename];
                    NSURL *imageURL = [imageDirectoryForThisChat URLByAppendingPathComponent:uniqueFilename];
                    
                    __autoreleasing NSError *writeError;
                    if (![fileWrapper.regularFileContents writeToURL:imageURL options:NSAtomicWrite error:&writeError]) {
                        fputs([[NSString stringWithFormat:@"%@: Unable to write image: %@", imageURL.path, writeError] UTF8String], stderr);
                        return;
                    }
                    
                    NSMutableDictionary *imageMetadata = [chatMetadata mutableCopy];
                    [imageMetadata setObject:[NSArray arrayWithObject:im.participant.accountName] forKey:(__bridge id)kMDItemAuthorAddresses];
                    if (im.participant.matchingPersonName)
                        [imageMetadata setObject:[NSArray arrayWithObject:im.participant.matchingPersonName] forKey:(__bridge id)kMDItemAuthors];
                    if (im.date)
                        [imageMetadata setObject:im.date forKey:(__bridge id)kMDItemContentCreationDate];
                    [imageMetadata setObject:fileWrapper.preferredFilename forKey:(__bridge id)kMDItemDisplayName];
                    
                    const char *imageFSPath = imageURL.path.fileSystemRepresentation;
                    [imageMetadata enumerateKeysAndObjectsUsingBlock:^(NSString *key, id value, BOOL *stop) {
                        __autoreleasing NSError *encodeError;
                        NSData *plistData = [NSPropertyListSerialization dataWithPropertyList:value format:NSPropertyListBinaryFormat_v1_0 options:0 error:&encodeError];
                        if (!plistData) {
                            fputs([[NSString stringWithFormat:@"%@: Unable to encode value for %@ as plist: %@", imageURL.path, key, encodeError] UTF8String], stderr);
                            return;
                        }
                        NSString *xattrKey = [@"com.apple.metadata:" stringByAppendingString:key];
                        if (setxattr(imageFSPath, xattrKey.UTF8String, plistData.bytes, plistData.length, 0, 0) != 0)
                            fputs([[NSString stringWithFormat:@"%@: Unable to write xattr (key = %@)", imageURL.path, key] UTF8String], stderr);
                    }];
                }];
            }];
        };
        
        __block void (^writeImageFilesForChatOrDirectory)() = ^(NSString *fileOrDirPath) {
            BOOL directory;
            if ([fm fileExistsAtPath:fileOrDirPath isDirectory:&directory]) {
                if (!directory) {
                    @autoreleasepool {
                        writeImageFilesForChatPath(fileOrDirPath);
                    }
                } else {
                    __autoreleasing NSError *enumerateError;
                    NSArray *dirContents = [fm contentsOfDirectoryAtPath:fileOrDirPath error:&enumerateError];
                    if (!dirContents) {
                        fputs([[NSString stringWithFormat:@"%@: Unable to list directory: %@", fileOrDirPath, enumerateError] UTF8String], stderr);
                        return;
                    }
                    for (NSString *filename in dirContents)
                        writeImageFilesForChatOrDirectory([fileOrDirPath stringByAppendingPathComponent:filename]);
                }
            } else
                fputs([[NSString stringWithFormat:@"%@: No such file or directory", fileOrDirPath] UTF8String], stderr);
        };
        
        
        // ---- Main driver loop ----
        for (NSString *path in pathArgs)
            writeImageFilesForChatOrDirectory(path);
    }
    return 0;
}
