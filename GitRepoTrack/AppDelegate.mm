//
//  AppDelegate.m
//  GitRepoTrack
//
//  Created by Oriol Ferrer Mesià on 17/01/13.
//  Copyright (c) 2013 Oriol Ferrer Mesià. All rights reserved.
//

#import "AppDelegate.h"
#import "Terminal.h"

@implementation AppDelegate

- (void)dealloc
{
    [super dealloc];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification{
	gitDirs = [[NSMutableArray alloc] initWithCapacity:100];
	dirtyGitRepos = [[NSMutableArray alloc] initWithCapacity:100];
	scanning = false;

	//auto start scan at launch if a path is already set
	NSUserDefaults * d = [NSUserDefaults standardUserDefaults];
	NSString * scanPath = [d objectForKey:@"scanPath"];
	if (scanPath){
		BOOL isDir;
		if( [[NSFileManager defaultManager] fileExistsAtPath:scanPath isDirectory: &isDir]){
			if(isDir){
				[self startScanButtonPressed:self];
			}
		}
	}

}


-(IBAction)startScanButtonPressed:(id)sender;{

	if (!scanning){ // start the scan!
		[gitDirs removeAllObjects];
		numModifiedFiles.clear();
		[dirtyGitRepos removeAllObjects];
		//[self startScan];
		[NSThread detachNewThreadSelector:@selector(doScan) toTarget:self withObject:nil];
	}else{	//stop the scan!
		forceStop = true;
	}

}


-(void)doScan{

	forceStop = false;
	scanning = true;
	//[startButton setEnabled:false];
	[startButton setTitle:@"Stop Scan!"];
	[progress startAnimation:self];

	NSString * startAt = [[drop getPath] retain];
	[self scan:startAt];
	//[startButton setEnabled:true];
	[startButton setTitle:@"Scan!"];
	[progress stopAnimation:self];
	scanning = false;

}
-(void)updateTable{
	//NSLog(@"updateTable");
	@synchronized (self) {
		[table reloadData];
	}
}

-(void)checkIfDirty:(NSString *) s{
	
	NSTask * task = [[NSTask alloc] init];
	[task setLaunchPath:@"/usr/bin/git"];
	[task setCurrentDirectoryPath:s];
	[task setArguments:[NSArray arrayWithObjects:@"status", @"-s", nil]];

	NSPipe *pipe = [NSPipe pipe];
	[task setStandardOutput:pipe];
	[task launch];

	NSData * data = [[pipe fileHandleForReading] readDataToEndOfFile];

	[task waitUntilExit];
	[task release];

	NSString * string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];

	if ([string length] > 0){
		//NSLog(@"This Git Repo is dirty: %@", s);
		@synchronized (self) {
			[dirtyGitRepos addObject:s];
		}
		[self performSelectorOnMainThread:@selector(updateTable) withObject:nil waitUntilDone:YES];
	}
	[string release];
}


-(void)checkNumberOfModifiedFiles:(NSString *) s{

	NSTask * task = [[NSTask alloc] init];
	[task setLaunchPath:@"/bin/sh"];
	[task setCurrentDirectoryPath:s];
	// /bin/sh -c trick to complex pipes from http://borkware.com/quickies/one?topic=nstask
	//git status | grep 'modified:' | awk ' { print $3 } ' | wc -l
	[task setArguments:[NSArray arrayWithObjects:@"-c", @"/usr/bin/git status | grep 'modified:' | awk ' { print $3 } ' | wc -l",  nil]];

	NSPipe *pipe = [NSPipe pipe];
	[task setStandardOutput:pipe];
	[task launch];

	NSData * data = [[pipe fileHandleForReading] readDataToEndOfFile];

	[task waitUntilExit];
	[task release];

	NSString * string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];

	if ([string length] > 0){
		int val = [string intValue];
		//NSLog(@"This Git Repo has _%@_ mod files (%d)", string, val);
		numModifiedFiles.push_back(val);
		//[self performSelectorOnMainThread:@selector(updateTable) withObject:nil waitUntilDone:YES];
	}else{
		numModifiedFiles.push_back(0);
	}
	[string release];
}


-(void)scan:(NSString *) s{

	if(forceStop) return; // stop scan if asked to do so

	NSFileManager * fm = [NSFileManager defaultManager];

	BOOL isDir;
	NSArray * dirs = [fm contentsOfDirectoryAtPath:s error:nil];
	NSString * gitPath = [NSString stringWithFormat:@"%@/.git", s ];

	//if this dir contains a .git init, add to gitDirs and stop diving in that tree branch
	if( [fm fileExistsAtPath:gitPath isDirectory:&isDir] ){
		@synchronized (self) {
			[gitDirs addObject: s];
		}
		[self checkIfDirty:s];
		[self checkNumberOfModifiedFiles:s];
		//NSLog(@"This dir is a GIT repo! %@", gitPath);
	}else{

		for( NSString* item in dirs){
			NSString * path = [NSString stringWithFormat:@"%@/%@", s, item ];
			if (![item hasPrefix:@"."]){ //ignore invisible dirs/files
				if( [fm fileExistsAtPath:path isDirectory:&isDir]){
					if (isDir){
						NSWorkspace * ws = [NSWorkspace sharedWorkspace];
						if (![ws isFilePackageAtPath:path]){ //test if its a "real" dir and not a package!
							//NSLog(@"is dir %@", path);
							[self scan:path];
						}
					}
				}
			}
		}
	}
}


- (void)openTerminal:(id)sender path:(NSString*) path{
	
	TerminalApplication* termApp = [SBApplication applicationWithBundleIdentifier:@"com.apple.terminal"];
	NSString *dir = path;// Get your directory here
	//NSString *cmd = [NSString stringWithFormat:@"cd \"%@\"; clear", dir]; // Assumes bash, which is okay for me, but maybe not others.

//	TerminalWindow *window = nil;
//	if (termApp.windows.count > 0){
//		window = [termApp.windows objectAtIndex:0];
//	}
//
//	TerminalSettingsSet *settings = [termApp startupSettings];
//	TerminalTab *newTab = [termApp doScript:cmd in:window];
//	[newTab setCurrentSettings:settings];
//	[newTab setSelected:YES];
//	[termApp activate];

	[termApp activate];
	[termApp open:[NSArray arrayWithObject:path]];
	TerminalWindow *window = nil;
	if (termApp.windows.count > 0){
		window = [termApp.windows objectAtIndex:0];
	}
	NSString *cmd = [NSString stringWithFormat:@"clear; git status;", dir]; // Assumes bash, which is okay for me, but maybe not others.
	TerminalTab *newTab = [termApp doScript:cmd in:window];
}


-(BOOL) string:(NSString*) s isInArray:(NSArray*)array{

	for (NSString* item in array){
		if ([item rangeOfString:s ].location != NSNotFound){
			return YES;
		}
	}
	return NO;
}


-(NSArray*)dirsThatMatch:(NSString*) s{

	NSMutableArray * filteredArray = [NSMutableArray arrayWithCapacity:10];
	@synchronized (self) {
		for (NSString* item in gitDirs){
			if ([[item lastPathComponent] rangeOfString:s options:NSCaseInsensitiveSearch].location != NSNotFound){
				[filteredArray addObject:item];
			}
		}
	}
	return filteredArray;
}


- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(int)row{

	//NSString * s = [gitDirs objectAtIndex:row];

	NSString * s;

	@synchronized (self) {
		if([filter.stringValue length] > 0){
			s = [[self dirsThatMatch:filter.stringValue] objectAtIndex:row];
		}else{
			s = [gitDirs objectAtIndex:row];
		}

		if ([[tableColumn identifier] isEqualTo: @"icon"]){
			if([self string:s isInArray: dirtyGitRepos]){
				return [NSImage imageNamed: @"red"];
			}else{
				return [NSImage imageNamed: @"green"];
			}
		}



		if ([[tableColumn identifier] isEqualTo: @"num"]){
			if ( row < numModifiedFiles.size() ){
				[[tableColumn dataCell] setVerticalCentering:YES];
				if ( numModifiedFiles[row] > 0 ){
					return [NSString stringWithFormat:@"%d",numModifiedFiles[row] ];
				}else{
					@"";
				}
			}
		}


		if ([[tableColumn identifier] isEqualTo: @"path"]){
			[[tableColumn dataCell] setVerticalCentering:YES];
			return s;
		}

		if ([[tableColumn identifier] isEqualTo: @"repo"]){
			return [s lastPathComponent];
		}

		if ([[tableColumn identifier] isEqualTo: @"reveal"]){
			return [NSImage imageNamed: @"showfile.png"];
		}
	}

	return nil;
}


-(IBAction)filterType:(id)sender;{
	[table reloadData];
}


- (int)numberOfRowsInTableView:(NSTableView *)tableView{
    //return [gitDirs count];
	@synchronized (self) {
		if([filter.stringValue length] > 0){
			return [[self dirsThatMatch:filter.stringValue] count];
		}else{
			return [gitDirs count];
		}
	}
}

- (BOOL)tableView:(NSTableView *)tableView shouldEditTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row;{

	NSString * s;
	@synchronized (self) {
		if([filter.stringValue length] > 0){
			s = [[self dirsThatMatch:filter.stringValue] objectAtIndex:row];
		}else{
			s = [gitDirs objectAtIndex:row];
		}
	}
	NSLog(@"edit>>%@", s);
	//NSURL *fileURL = [NSURL fileURLWithPath: s];
	//[[NSWorkspace sharedWorkspace] openURL: fileURL];
	[self openTerminal:self path: s];
	[table deselectAll:nil];
	return NO;
}


- (BOOL)tableView:(NSTableView *)tableView shouldSelectRow:(NSInteger)row{
//	NSString * s = [gitDirs objectAtIndex:row];
//	//NSURL *fileURL = [NSURL fileURLWithPath: s];
//	//[[NSWorkspace sharedWorkspace] openURL: fileURL];
//	[self openTerminal:self path: s];
	//NSLog(@"%d row %@!", row, fileURL);
	return YES;
}


- (BOOL)selectionShouldChangeInTableView:(NSTableView *)tableView;{
	return YES;
}

@end
