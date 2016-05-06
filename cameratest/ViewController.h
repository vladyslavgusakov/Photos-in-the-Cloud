//
//  ViewController.h
//  CameraTest
//
//  Created by Aditya on 02/10/13.
//  Copyright (c) 2013 Aditya. All rights reserved.
//

@import UIKit;
@import AWSCore;
@import AWSS3;

#import "AmazonS3Util.h"
#import "Constants.h"

@interface ViewController : UIViewController
<UINavigationControllerDelegate, UIImagePickerControllerDelegate, UIPopoverControllerDelegate,
UITableViewDelegate, UITableViewDataSource, AmazonS3UtilDelegate>

@property (strong, nonatomic) AmazonS3Util *s3Util;

@property(strong,nonatomic)NSString *urlStr;
@property(strong,nonatomic)NSArray *tableData;
@property (nonatomic, strong) NSMutableArray *collection;


@property (nonatomic,weak) IBOutlet UIImageView *imageView;
@property (weak, nonatomic) IBOutlet UITableView *tableView;
@property (strong, nonatomic) IBOutlet UIProgressView *progressView;
@property (strong, nonatomic) IBOutlet UILabel *statusLabel;

- (IBAction)takePicture:(id)sender;
- (IBAction)edit:(id)sender;
- (IBAction)downloadAllFromS3:(id)sender;

-(void) tableViewUpdate;

@end
