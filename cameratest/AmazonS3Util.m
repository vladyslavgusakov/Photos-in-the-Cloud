//
//  AmazonS3Util.m
//  CameraTest
//
//  Created by Aditya on 08/11/13.
//  Copyright (c) 2013 Aditya. All rights reserved.
//

#import "AmazonS3Util.h"
#import "Constants.h"

@implementation AmazonS3Util

-(void) createDownloadDirectory {
    
    NSError *error = nil;
    if (![[NSFileManager defaultManager] createDirectoryAtPath:[NSTemporaryDirectory() stringByAppendingPathComponent:@"download"]
                                   withIntermediateDirectories:YES
                                                    attributes:nil
                                                         error:&error]) {
        NSLog(@"Creating 'download' directory failed. Error: [%@]", error);
    }
    
}

- (NSMutableArray *)listObjects {
    
    NSMutableArray *listArray = [NSMutableArray new];
    AWSS3 *s3 = [AWSS3 defaultS3];
    
    AWSS3ListObjectsRequest *listObjectsRequest = [AWSS3ListObjectsRequest new];
    listObjectsRequest.bucket = S3BucketName;
    [[s3 listObjects:listObjectsRequest] continueWithBlock:^id(AWSTask *task) {
        if (task.error) {
            NSLog(@"listObjects failed: [%@]", task.error);
        } else {
            AWSS3ListObjectsOutput *listObjectsOutput = task.result;
            for (AWSS3Object *s3Object in listObjectsOutput.contents) {
                NSString *downloadingFilePath = [[NSTemporaryDirectory() stringByAppendingPathComponent:@"download"] stringByAppendingPathComponent:s3Object.key];
                NSURL *downloadingFileURL = [NSURL fileURLWithPath:downloadingFilePath];
                
                if ([[NSFileManager defaultManager] fileExistsAtPath:downloadingFilePath]) {
                    [listArray addObject:downloadingFileURL];
                } else {
                    AWSS3TransferManagerDownloadRequest *downloadRequest = [AWSS3TransferManagerDownloadRequest new];
                    downloadRequest.bucket = S3BucketName;
                    downloadRequest.key = s3Object.key;
                    downloadRequest.downloadingFileURL = downloadingFileURL;
                    [listArray addObject:downloadRequest];
                }
            }
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate tableViewUpdate];
            });
        }
        return nil;
    }];
    
    return listArray;
}

- (void)download:(AWSS3TransferManagerDownloadRequest *)downloadRequest {
    switch (downloadRequest.state) {
        case AWSS3TransferManagerRequestStateNotStarted:
        case AWSS3TransferManagerRequestStatePaused:
        {
            AWSS3TransferManager *transferManager = [AWSS3TransferManager defaultS3TransferManager];
            [[transferManager download:downloadRequest] continueWithBlock:^id(AWSTask *task) {
                if ([task.error.domain isEqualToString:AWSS3TransferManagerErrorDomain]
                    && task.error.code == AWSS3TransferManagerErrorPaused) {
                    NSLog(@"Download paused.");
                } else if (task.error) {
                    NSLog(@"Upload failed: [%@]", task.error);
                } else {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        
                        NSUInteger index = [self.delegate.collection indexOfObject:downloadRequest];
                        [self.delegate.collection replaceObjectAtIndex:index
                                                         withObject:downloadRequest.downloadingFileURL];
                        [self.delegate tableViewUpdate];
                    });
                }
                return nil;
            }];
        }
            break;
        default:
            break;
    }
}

- (void)downloadAll {
    [self.delegate.collection enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        if ([obj isKindOfClass:[AWSS3TransferManagerDownloadRequest class]]) {
            AWSS3TransferManagerDownloadRequest *downloadRequest = obj;
            if (downloadRequest.state == AWSS3TransferManagerRequestStateNotStarted
                || downloadRequest.state == AWSS3TransferManagerRequestStatePaused) {
                [self download:downloadRequest];
            }
        }
    }];
    
    [self.delegate tableViewUpdate];
}

-(void) presentImageWithObject: (id) object {
    
    if ([object isKindOfClass:[AWSS3TransferManagerDownloadRequest class]]) {
        AWSS3TransferManagerDownloadRequest *downloadRequest = object;
        
        if (downloadRequest.state == AWSS3TransferManagerRequestStateNotStarted ||
            downloadRequest.state == AWSS3TransferManagerRequestStatePaused) {
            
            [self download:downloadRequest];
            [self.delegate tableViewUpdate];
        }
        
    } else
        if ([object isKindOfClass:[NSURL class]]) {
            NSURL * downloadingFileURL = object;
            self.delegate.imageView.image = [UIImage imageWithData:[NSData dataWithContentsOfURL:downloadingFileURL]];
        }
}

- (void) setUpDownloadProgressForObject: (AWSS3TransferManagerDownloadRequest *) object {
    
    object.downloadProgress = ^(int64_t bytesWritten, int64_t totalBytesWritten, int64_t totalBytesExpectedToWrite) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (totalBytesExpectedToWrite > 0) {
                self.delegate.statusLabel.text = [NSString stringWithFormat:@"Downloading ... %.0f%%", (float)((double) totalBytesWritten / totalBytesExpectedToWrite * 100)];
                
                if (totalBytesWritten == totalBytesExpectedToWrite) {
                    self.delegate.statusLabel.text = @"";
                }
            }
            
        });
    };
}

- (void)upload:(AWSS3TransferManagerUploadRequest *)uploadRequest {
    
    AWSS3TransferManager *transferManager = [AWSS3TransferManager defaultS3TransferManager];
    
    [[transferManager upload:uploadRequest] continueWithBlock:^id(AWSTask *task) {
        if (task.error) {
            if ([task.error.domain isEqualToString:AWSS3TransferManagerErrorDomain]) {
                switch (task.error.code) {
                    case AWSS3TransferManagerErrorCancelled:
                    case AWSS3TransferManagerErrorPaused:
                    {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [self.delegate tableViewUpdate];
                        });
                    }
                        break;
                        
                    default:
                        NSLog(@"Upload failed: [%@]", task.error);
                        break;
                }
            } else {
                NSLog(@"Upload failed: [%@]", task.error);
            }
        }
        
        if (task.result) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate.collection insertObject:uploadRequest.body atIndex:0];
                [self.delegate tableViewUpdate];
            });
        }
        
        return nil;
    }];
}

-(void) uploadToS3: (NSData *) data {
    
    NSString *fileName = [[[NSProcessInfo processInfo] globallyUniqueString] stringByAppendingString:@".png"];
    NSString *path = [[NSTemporaryDirectory() stringByAppendingPathComponent:@"download"] stringByAppendingPathComponent:fileName];
    [data writeToFile:path atomically:YES];
    
    NSURL *url = [NSURL fileURLWithPath:path];
    
    AWSS3TransferManagerUploadRequest *uploadRequest = [AWSS3TransferManagerUploadRequest new];
    
    uploadRequest.bucket = @"cameraproject";
    uploadRequest.ACL = AWSS3ObjectCannedACLPublicRead;
    uploadRequest.key = fileName;
    uploadRequest.contentType = @"image/png";
    uploadRequest.body = url;
    
    self.delegate.progressView.hidden = NO;
    
    uploadRequest.uploadProgress = ^(int64_t bytesSent, int64_t totalBytesSent, int64_t totalBytesExpectedToSend){
        dispatch_sync(dispatch_get_main_queue(), ^{
            
            if (self.delegate.progressView.progress == 1) {
                self.delegate.progressView.hidden = YES;
            } else {
                self.delegate.progressView.hidden = NO;
                self.delegate.progressView.progress = (float) totalBytesSent / (float) totalBytesExpectedToSend;
            }
            
            if (totalBytesSent > 0) {
                self.delegate.statusLabel.text = [NSString stringWithFormat:@"Uploading ... %.0f%%", (float)((double) totalBytesSent / totalBytesExpectedToSend * 100)];
                
                if (totalBytesSent == totalBytesExpectedToSend) {
                    self.delegate.statusLabel.text = @"";
                }
            }
            
        });
        
    };
    [self.delegate tableViewUpdate];
    
    [self upload:uploadRequest];
    
}

-(void) deleteObjectWithKey: (NSString *) key {
    
    //delete from amazon
    AWSS3 *s3 = [AWSS3 defaultS3];
    
    AWSS3DeleteObjectRequest *deleteRequest = [AWSS3DeleteObjectRequest new];
    deleteRequest.bucket = [Constants uploadBucket];
    deleteRequest.key = key;
    
    [s3 deleteObject:deleteRequest];
    
    //delete from local tmp dir
    NSError *error = nil;
    [[NSFileManager defaultManager] removeItemAtPath:[[NSTemporaryDirectory() stringByAppendingPathComponent:@"download"] stringByAppendingPathComponent:key] error:&error];
}

- (void)dealloc {
    self.delegate = nil;
    NSLog(@"Deallocation Done");
}

@end
