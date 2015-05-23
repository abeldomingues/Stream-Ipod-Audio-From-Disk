//
//  Utilities.m
//  iPodLibraryAccessDemo
//
//  Created by Abel Domingues on 5/20/15.
//  Copyright (c) 2015 Abel Domingues. All rights reserved.
//

#import <Foundation/Foundation.h>

static void CheckError(OSStatus error, const char *operation)
{
  if (error == noErr) return;
  
  char errorString[20];
  // see if it appears to be a 4-char code
  *(UInt32 *)(errorString + 1) = CFSwapInt32HostToBig(error);
  if (isprint(errorString[1]) && isprint(errorString[2]) &&
      isprint(errorString[3]) && isprint(errorString[4])) {
    errorString[0] = errorString[5] = '\'';
    errorString[6] = '\0';
  } else {
    // No, format it as an integer
    fprintf(stderr, "Error: %s (%s)\n", operation, errorString);
    
    exit(1);
  }
}


