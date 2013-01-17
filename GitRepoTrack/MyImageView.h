//
//  MyImageView.h
//  MenuApp
//
//  Created by Oriol Ferrer Mesià on 23/04/12.
//  Copyright 2012 uri.cat. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface MyImageView : NSImageView
{
	NSString * scanPath;
	IBOutlet NSPathControl * pathBar;
}

-(NSString*) getPath;

-(void)loadPrefs;
-(void)savePrefs;


@end