//
//  ViewController.h
//  StreamIpodAudioFromDisk
//
//  Created by Abel Domingues on 5/23/15.
//  Copyright (c) 2015 Abel Domingues. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AudioToolbox/AudioToolbox.h>
#import <MediaPlayer/MediaPlayer.h>
#import "Output.h"

/* A sample project demonstrating how to stream iPod Library audio tracks from disk, ie without loading the entire audio file into memory. See companion blog post at mojolama.com */

@interface ViewController : UIViewController <MPMediaPickerControllerDelegate, OutputDataSource>

@property (strong, nonatomic) Output* output;
@property (weak, nonatomic) IBOutlet UIButton* playPauseButton;

- (void)readFrames:(UInt32)frames
   audioBufferList:(AudioBufferList *)audioBufferList
        bufferSize:(UInt32 *)bufferSize;

@end

