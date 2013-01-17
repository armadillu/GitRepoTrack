//
//  AppDelegate.h
//  GitRepoTrack
//
//  Created by Oriol Ferrer Mesià on 17/01/13.
//  Copyright (c) 2013 Oriol Ferrer Mesià. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <ScriptingBridge/ScriptingBridge.h>
#import "MyImageView.h"

@interface AppDelegate : NSObject <NSApplicationDelegate>{

	NSMutableArray * gitDirs;
	NSMutableArray * dirtyGitRepos;
	IBOutlet NSTableView * table;
	IBOutlet MyImageView * drop;
	IBOutlet NSButton * startButton;
	IBOutlet NSProgressIndicator * progress;

}


-(IBAction)startScanButtonPressed:(id)sender;

@property (assign) IBOutlet NSWindow *window;

@end
