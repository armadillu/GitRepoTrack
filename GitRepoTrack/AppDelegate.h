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
#include <vector>

@interface AppDelegate : NSObject <NSApplicationDelegate>{

	NSMutableArray * gitDirs;
	std::vector<int> numModifiedFiles;
	NSMutableArray * dirtyGitRepos;
	IBOutlet NSTableView * table;
	IBOutlet MyImageView * drop;
	IBOutlet NSButton * startButton;
	IBOutlet NSProgressIndicator * progress;
	IBOutlet NSTextField * filter;

	bool forceStop;
	bool scanning;
}


-(IBAction)startScanButtonPressed:(id)sender;
-(IBAction)filterType:(id)sender;

@property (assign) IBOutlet NSWindow *window;

@end
