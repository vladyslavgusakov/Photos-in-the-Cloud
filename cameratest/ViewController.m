//
//  ViewController.m
//  CameraTest
//
//  Created by Aditya on 02/10/13.
//  Copyright (c) 2013 Aditya. All rights reserved.
//

#import "ViewController.h"

@interface ViewController () 
@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.s3Util = [AmazonS3Util new];
    self.s3Util.delegate = self;
    [self.s3Util createDownloadDirectory];

    self.collection = [NSMutableArray new];
    self.collection = [self.s3Util listObjects];
    
    self.progressView.hidden = YES;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(void) tableViewUpdate {
    [self.tableView reloadData];
}

- (IBAction)edit:(id)sender{
    if([self.tableView isEditing]){
        [sender setTitle:@"Edit"];
    }else{
        [sender setTitle:@"Done"];
    }
    [self.tableView setEditing:![self.tableView isEditing]];
}

- (IBAction)downloadAllFromS3:(id)sender {
    [self.s3Util downloadAll];
}

- (IBAction)takePicture:(id)sender{
    
    UIImagePickerController *imagePicker = [[UIImagePickerController alloc] init];
    
    if( [UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera] ){
      
        [imagePicker setSourceType:UIImagePickerControllerSourceTypeCamera];
    }else
    {
        [imagePicker setSourceType:UIImagePickerControllerSourceTypePhotoLibrary];
 
    }
    
    [imagePicker setAllowsEditing:TRUE];
    [imagePicker setDelegate:self];
    
    [self presentViewController:imagePicker animated:YES completion:nil];
}

-(void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info{
    
    [self dismissViewControllerAnimated:YES completion:^(){
        
        
        self.imageView.image = [info objectForKey:UIImagePickerControllerEditedImage];
        NSData *imageData = UIImagePNGRepresentation(self.imageView.image);

        [self.s3Util uploadToS3:imageData];
    }];
}

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    NSLog(@"Table Data Count: %lu", (unsigned long)[self.collection count]);
    return [self.collection count];
}

-(UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    id object = [self.collection objectAtIndex:indexPath.row];
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"UITableViewCell"];
    
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"UITableViewCell"];
    }
    
    if ([object isKindOfClass:[AWSS3TransferManagerDownloadRequest class]]) {
        
        AWSS3TransferManagerDownloadRequest *downloadRequest = object;
        [self.s3Util setUpDownloadProgressForObject: downloadRequest];
        
        cell.imageView.image = nil;
        cell.textLabel.text = downloadRequest.key;
        
    } else if ([object isKindOfClass:[NSURL class]]) {
        NSURL *downloadFileURL = object;
        cell.textLabel.text = [downloadFileURL lastPathComponent];
        cell.imageView.image = [UIImage imageWithData:[NSData dataWithContentsOfURL:downloadFileURL]];
    }
    
    return cell;

}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath: (NSIndexPath *)indexPath
{
    id object = [self.collection objectAtIndex:indexPath.row];
    
    [self.s3Util presentImageWithObject: object];
}

- (void)tableView:(UITableView *) tableView  commitEditingStyle: (UITableViewCellEditingStyle) editingStyle
                                                forRowAtIndexPath: (NSIndexPath *)indexPath
{
    NSString *fileName = [NSString stringWithFormat:@"%@",
                          [self.collection objectAtIndex: indexPath.row ]].lastPathComponent;
    
    [self.s3Util deleteObjectWithKey:fileName];
    [self.collection removeObjectAtIndex:indexPath.row];
    [self.tableView reloadData];
 }


@end
