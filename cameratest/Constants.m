#import "Constants.h"

@implementation Constants


+(NSString *)uploadBucket
{
    return [[NSString stringWithFormat:@"%@", S3BucketName] lowercaseString];
}

@end

