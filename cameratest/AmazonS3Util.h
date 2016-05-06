//
//  AmazonS3Util.h
//  CameraTest
//
//  Created by Aditya on 08/11/13.
//  Copyright (c) 2013 Aditya. All rights reserved.
//
//
//
@import AWSS3;
@import AWSCore;
@import UIKit;

@protocol AmazonS3UtilDelegate <NSObject>

@optional

@property (nonatomic, strong) NSMutableArray *collection;
@property (nonatomic, strong) UIProgressView *progressView;
@property (nonatomic, weak) UIImageView *imageView;
@property (nonatomic, strong) UILabel *statusLabel;

-(void) tableViewUpdate;

@end

@interface AmazonS3Util : NSObject

@property (nonatomic, retain) id <AmazonS3UtilDelegate>  delegate;

- (void) createDownloadDirectory;
- (NSMutableArray *)listObjects;
- (void) download:(AWSS3TransferManagerDownloadRequest *)downloadRequest;
- (void) downloadAll;
- (void) presentImageWithObject: (id) object;
- (void) setUpDownloadProgressForObject: (AWSS3TransferManagerDownloadRequest *) object;
- (void) upload:(AWSS3TransferManagerUploadRequest *)uploadRequest;
- (void) uploadToS3: (NSData *) data;
- (void) deleteObjectWithKey: (NSString *) key;

@end
