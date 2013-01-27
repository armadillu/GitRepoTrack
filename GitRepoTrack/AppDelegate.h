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
#include <map>
#include <string>

using namespace std;

@interface AppDelegate : NSObject <NSApplicationDelegate>{

	struct gitRepoStat{
		gitRepoStat(){ localModifications = 0; hasRemote = false; remoteModifications = 0; remoteName = ""; isDirty = false;}
		int localModifications; //num
		bool hasRemote;
		bool isDirty; //has local changes
		string remoteName;
		string remoteDiffs;
		int remoteModifications; //todo
	};
	NSMutableArray * gitDirs;

	//NSMutableDictionary* numModifiedFiles;
	map<string, gitRepoStat> gitDirStats;

	IBOutlet NSTableView * table;
	IBOutlet MyImageView * drop;
	IBOutlet NSButton * startButton;
	IBOutlet NSButton * checkRemoteCheckbox;
	IBOutlet NSProgressIndicator * progress;
	IBOutlet NSTextField * filter;


	bool forceStop;
	bool scanning;
}


-(IBAction)startScanButtonPressed:(id)sender;
-(IBAction)checkRemoteCheckboxPressed:(id)sender;
-(IBAction)filterType:(id)sender;

@property (assign) IBOutlet NSWindow *window;

@end
