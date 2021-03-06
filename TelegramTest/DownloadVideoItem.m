//
//  DownloadVideoItem.m
//  Messenger for Telegram
//
//  Created by keepcoder on 13.03.14.
//  Copyright (c) 2014 keepcoder. All rights reserved.
//

#import "DownloadVideoItem.h"
#import "FileUtils.h"
#import <AVFoundation/AVFoundation.h>
@implementation DownloadVideoItem



-(id)initWithObject:(TLMessage *)object {
    if(self = [super initWithObject:object]) {
        self.isEncrypted = [object isKindOfClass:[TL_destructMessage class]];
        self.n_id = object.media.video.n_id;
        self.path = mediaFilePath(object.media);
        self.fileType = DownloadFileVideo;
        self.dc_id = object.media.video.dc_id;
        self.size = object.media.video.size;
    }
    return self;
}

-(void)setDownloadState:(DownloadState)downloadState {
    if(self.downloadState != DownloadStateCompleted && downloadState == DownloadStateCompleted) {
        
        AVURLAsset *asset = [AVURLAsset assetWithURL:[NSURL fileURLWithPath:self.path]];
        
        AVAssetImageGenerator *generator = [[AVAssetImageGenerator alloc] initWithAsset:asset];
        generator.appliesPreferredTrackTransform = TRUE;
        CMTime thumbTime = CMTimeMakeWithSeconds(0, 30);
        
        __block NSImage *thumbImg;
        
        dispatch_semaphore_t sema = dispatch_semaphore_create(0);
        
        AVAssetImageGeneratorCompletionHandler handler = ^(CMTime requestedTime, CGImageRef im, CMTime actualTime, AVAssetImageGeneratorResult result, NSError *error){
            
            if (result != AVAssetImageGeneratorSucceeded) {
                DLog(@"couldn't generate thumbnail, error:%@", error);
            }
            
            thumbImg = [[NSImage alloc] initWithCGImage:im size:NSMakeSize(250, 250)];
            dispatch_semaphore_signal(sema);
        };

        
        CGSize maxSize = CGSizeMake(250, 250);
        generator.maximumSize = maxSize;
        
        [generator generateCGImagesAsynchronouslyForTimes:[NSArray arrayWithObject:[NSValue valueWithCMTime:thumbTime]] completionHandler:handler];
        
        dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
        dispatch_release(sema);

        
        TL_localMessage *msg = (TL_localMessage *)self.object;
        
        msg.media.video.thumb = [TL_photoCachedSize createWithType:@"x" location:msg.media.video.thumb.location w:250 h:250 bytes:jpegNormalizedData(thumbImg)];
        
        [[Storage manager] updateMessages:@[msg]];
        
        
    }
    [super setDownloadState:downloadState];
}


-(TLInputFileLocation *)input {
    TLMessage *message = [self object];
    if(self.isEncrypted)
        return [TL_inputEncryptedFileLocation createWithN_id:self.n_id access_hash:message.media.video.access_hash];
    return [TL_inputVideoFileLocation createWithN_id:self.n_id access_hash:message.media.video.access_hash];
}




@end
