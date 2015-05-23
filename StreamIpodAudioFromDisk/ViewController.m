//
//  ViewController.m
//  StreamIpodAudioFromDisk
//
//  Created by Abel Domingues on 5/23/15.
//  Copyright (c) 2015 Abel Domingues. All rights reserved.
//

#import "ViewController.h"
#import "Utilities.m"

@interface ViewController() {
  AudioStreamBasicDescription   _clientFormat;
}

@property (assign, nonatomic) ExtAudioFileRef audioFile;
@property (assign, nonatomic) BOOL isPlaying;
@property (assign, nonatomic) SInt64 frameIndex;

@end

@implementation ViewController

- (void)viewDidLoad {
  [super viewDidLoad];
  
  self.isPlaying = NO;
  
  self.output = [[Output alloc] init];
  self.output.outputDataSource = self;
}

#pragma mark - Actions
- (IBAction)browseIpodLibrary {
  MPMediaPickerController *pickerController =	[[MPMediaPickerController alloc] initWithMediaTypes: MPMediaTypeMusic];
  pickerController.showsCloudItems = NO;
  pickerController.prompt = @"Pick Something To Play";
  pickerController.allowsPickingMultipleItems = NO;
  pickerController.delegate = self;
  [self presentViewController:pickerController animated:YES completion:NULL];
}

- (IBAction)playPause:(UIButton*)sender
{
  if (!self.isPlaying) {
    [self.output startOutputUnit];
    [sender setTitle:@"Pause" forState:UIControlStateNormal];
    self.isPlaying = YES;
  } else {
    [self.output stopOutputUnit];
    [sender setTitle:@"Play" forState:UIControlStateNormal];
    self.isPlaying = NO;
  }
}

#pragma mark - File Reading
- (void)openFileAtURL:(NSURL*)url
{
  // get a reference to the selected file and open it for reading by first (a) NULLing out our existing ExtAudioFileRef...
  self.audioFile = NULL;
  // then (b) casting the track's NSURL to a CFURLRef ('cause that's what ExtAudioFileOpenURL requires)...
  CFURLRef cfurl = (__bridge CFURLRef)url;
  // and finally (c) opening the file for reading.
  CheckError(ExtAudioFileOpenURL(cfurl, &_audioFile),
             "ExtAudioFileOpenURL Failed");
  
  // get the total number of sample frames in the file (we're not actually doing anything with  totalFrames in this demo, but you'll nearly always want to grab the file's length as soon as you open it for reading)
  SInt64 totalFrames;
  UInt32 dataSize = sizeof(totalFrames);
  CheckError(ExtAudioFileGetProperty(_audioFile, kExtAudioFileProperty_FileLengthFrames, &dataSize, &totalFrames),
             "ExtAudioFileGetProperty FileLengthFrames failed");
  
  // get the file's native format (so ExtAudioFileRead knows what format it's converting _from_)
  AudioStreamBasicDescription asbd;
  dataSize = sizeof(asbd);
  CheckError(ExtAudioFileGetProperty(_audioFile, kExtAudioFileProperty_FileDataFormat, &dataSize, &asbd), "ExtAudioFileGetProperty FileDataFormat failed");
  
  // set up a client format (so ExtAudioFileRead knows what format it's converting _to_ - here we're converting to LPCM 32-bit floating point, which is what we've told the output audio unit to expect!)
  AudioStreamBasicDescription clientFormat;
  clientFormat.mFormatID = kAudioFormatLinearPCM;
  clientFormat.mFormatFlags       = kAudioFormatFlagIsBigEndian | kAudioFormatFlagIsPacked | kAudioFormatFlagIsFloat;
  clientFormat.mSampleRate        = 44100;
  clientFormat.mChannelsPerFrame  = 2;
  clientFormat.mBitsPerChannel    = 32;
  clientFormat.mBytesPerPacket    = (clientFormat.mBitsPerChannel / 8) * clientFormat.mChannelsPerFrame;
  clientFormat.mFramesPerPacket   = 1;
  clientFormat.mBytesPerFrame     = clientFormat.mBytesPerPacket;
  
  // set the client format on our ExtAudioFileRef
  CheckError(ExtAudioFileSetProperty(_audioFile, kExtAudioFileProperty_ClientDataFormat, sizeof(clientFormat), &clientFormat), "ExtAudioFileSetProperty ClientDataFormat failed");
  _clientFormat = clientFormat;
  
  // finally, set our _frameIndex property to 0 in prep for the first read
  self.frameIndex = 0;
}

- (void)readFrames:(UInt32)frames
   audioBufferList:(AudioBufferList *)audioBufferList
        bufferSize:(UInt32 *)bufferSize
{
  /* This is the call being made from inside the output unit's render callback.
   
   Key Grokking Point: the incoming audioBufferList here _is_ the audioBufferList (*ioData) in the callback - they both point to the same location in memory. In short: the render callback tells us where to find ioData, we fill its buffers, from here, with converted samples and the render callback then ships the filled buffers out to the speakers, through the air, into your ears, down your spine.
   
   Likewise, 'frames' _is_ 'inNumberFrames' (also from the callback) which tells us how many frames there are in the buffers, and therefore how many samples to read from the file */
  
  if (self.audioFile) {
    // seek to the current frame index
    CheckError(ExtAudioFileSeek(_audioFile, _frameIndex), nil);
    // do the read
    CheckError(ExtAudioFileRead(self.audioFile, &frames, audioBufferList),
               "Failed to read audio data from audio file");
    *bufferSize = audioBufferList->mBuffers[0].mDataByteSize/sizeof(float);
    // update the frame index so we know where to pick up when the next request for samples comes in from the render callback
    _frameIndex += frames;
  }
}

#pragma mark - Media Picker Delegate
- (void)mediaPicker: (MPMediaPickerController *)mediaPicker
  didPickMediaItems:(MPMediaItemCollection *)mediaItemCollection
{
  [self dismissViewControllerAnimated:YES completion:NULL];
  // if we come up dry, we bail
  if ([mediaItemCollection count] < 1) {
    NSLog(@"Sorry, the returned mediaItemCollection appears to be empty");
    return;
  }
  // otherwise grab the first mediaItem in the returned mediaItemCollection
  MPMediaItem* mediaItem = [[mediaItemCollection items] objectAtIndex:0];
  [self logMediaItemAttributes:mediaItem]; // just logging some file attributes to the console
  // get the internal url to the file
  NSURL* assetURL = [mediaItem valueForProperty:MPMediaItemPropertyAssetURL];
  
  // if the url comes back nil, throw up an alert view and return gracefully
  if (!assetURL) {
    [self createNilFileAlert];
  }
  
  // if the url points to an iCloud item, throw up an alert view and return gracefully
  if ([[mediaItem valueForProperty:MPMediaItemPropertyIsCloudItem] integerValue] == 1) {
    [self createICloudFileAlert];
  }
  
  // otherwise, we're ready to open the file for reading
  [self openFileAtURL:assetURL];
}

- (void)mediaPickerDidCancel:(MPMediaPickerController *)mediaPicker {
  [self dismissViewControllerAnimated:YES completion:NULL];
}


#pragma mark - Helpers
- (void)createNilFileAlert
{
  UIAlertController *nilFileAlert = [UIAlertController alertControllerWithTitle:@"File Not Available" message:@"The track you selected failed to load from the iPod Library. Please try loading another track." preferredStyle:UIAlertControllerStyleAlert];
  UIAlertAction *OKAction = [UIAlertAction actionWithTitle:@"OK"
                                                     style:UIAlertActionStyleDefault
                                                   handler:^(UIAlertAction *action){
                                                     [nilFileAlert dismissViewControllerAnimated:YES completion:nil];
                                                   }];
  
  [nilFileAlert addAction:OKAction];
  [self presentViewController:nilFileAlert animated:YES completion:nil];
}

- (void)createICloudFileAlert
{
  UIAlertController *iCloudItemAlert = [UIAlertController alertControllerWithTitle:@"iCloud File Not Available" message:@"Sorry, that selection appears to be an iCloud item and is not presently available on this device." preferredStyle:UIAlertControllerStyleAlert];
  UIAlertAction *OKAction = [UIAlertAction actionWithTitle:@"OK"
                                                     style:UIAlertActionStyleDefault
                                                   handler:^(UIAlertAction *action){
                                                     [iCloudItemAlert dismissViewControllerAnimated:YES completion:nil];
                                                   }];
  [iCloudItemAlert addAction:OKAction];
  [self presentViewController:iCloudItemAlert animated:YES completion:nil];
}

- (void)logMediaItemAttributes:(MPMediaItem *)item
{
  NSLog(@"Title: %@", [item valueForProperty:MPMediaItemPropertyTitle]);
  NSLog(@"Artist: %@", [item valueForProperty:MPMediaItemPropertyArtist]);
  NSLog(@"Album: %@", [item valueForProperty:MPMediaItemPropertyAlbumTitle]);
  NSLog(@"Duration (in seconds): %@", [item valueForProperty:MPMediaItemPropertyPlaybackDuration]);
}

@end