//
//  AppDelegate.m
//  GitRepoTrack
//
//  Created by Oriol Ferrer Mesià on 17/01/13.
//  Copyright (c) 2013 Oriol Ferrer Mesià. All rights reserved.
//

#import "AppDelegate.h"
#import "Terminal.h"

using namespace std;


@implementation AppDelegate

- (void)dealloc
{
    [super dealloc];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification{
	gitDirs = [[NSMutableArray alloc] initWithCapacity:100];
	//numModifiedFiles = [[NSMutableDictionary alloc] initWithCapacity:100];
	scanning = false;

	//auto start scan at launch if a path is already set
	NSUserDefaults * d = [NSUserDefaults standardUserDefaults];
	NSString * scanPath = [d objectForKey:@"scanPath"];
	[checkRemoteCheckbox setState:[d integerForKey:@"checkRemotes"]];

	if (scanPath){
		BOOL isDir;
		if( [[NSFileManager defaultManager] fileExistsAtPath:scanPath isDirectory: &isDir]){
			if(isDir){
				[self startScanButtonPressed:self];
			}
		}
	}

}

-(IBAction)checkRemoteCheckboxPressed:(id)sender;{

	NSUserDefaults * d = [NSUserDefaults standardUserDefaults];
	[d setInteger:[sender state] forKey:@"checkRemotes"];
	[d synchronize];
}


-(IBAction)startScanButtonPressed:(id)sender;{

	if (!scanning){ // start the scan!
		[gitDirs removeAllObjects];
		//[numModifiedFiles removeAllObjects];
		gitDirStats.clear();
		[table reloadData];
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


- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender{
    return YES;
}


-(void)checkIfDirty:(NSString *) s{
	
	NSTask * task = [[NSTask alloc] init];
	[task setLaunchPath:@"/bin/sh"];
	[task setCurrentDirectoryPath:s];
	[task setArguments:[NSArray arrayWithObjects:@"-c", @"/usr/bin/git status | grep 'modified:'", nil]];
	NSPipe *pipe = [NSPipe pipe];
	[task setStandardOutput:pipe];
	[task launch];
	NSData * data = [[pipe fileHandleForReading] readDataToEndOfFile];
	[task waitUntilExit];
	[task release];
	NSString * string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];

	if ([string length] > 0){
		std::string key = [s UTF8String];
		//NSLog(@"This Git Repo is dirty: %@ >> %@", s, string);
		@synchronized (self) {
			gitRepoStat stat = gitDirStats[key];
			stat.isDirty = true;
			gitDirStats[key] = stat;
		}		
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

	std::string key = [s UTF8String];
	gitRepoStat stat = gitDirStats[key];

	if ([string length] > 0){
		int val = [string intValue];
		//NSLog(@"This Git Repo has _%@_ mod files (%d)", @"", val);
		//[numModifiedFiles setObject:[NSNumber numberWithInt:val] forKey:s];
		stat.localModifications = val;
	}else{
		//[numModifiedFiles setObject:[NSNumber numberWithInt:0] forKey:s];
		stat.localModifications = 0;
	}
	gitDirStats[key] = stat;
	[string release];
}

-(BOOL)checkForRemote:(NSString *) s{

	NSTask * task = [[NSTask alloc] init];
	[task setLaunchPath:@"/bin/sh"];
	[task setCurrentDirectoryPath:s];
	// /bin/sh -c trick to complex pipes from http://borkware.com/quickies/one?topic=nstask
	[task setArguments:[NSArray arrayWithObjects:@"-c", @"/usr/bin/git remote -v | grep fetch | awk ' { print $2 } ' ",  nil]];

	NSPipe *pipe = [NSPipe pipe];
	[task setStandardOutput:pipe];
	[task launch];
	NSData * data = [[pipe fileHandleForReading] readDataToEndOfFile];
	[task waitUntilExit];
	[task release];
	NSString * string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];

	std::string key = [s UTF8String];
	gitRepoStat stat = gitDirStats[key];
	if ([string length] > 0){
		//NSLog(@"This Git Repo (%@) has a remote _%@_ ", [s lastPathComponent], string);
		int val = [string intValue];
		//[numModifiedFiles setObject:[NSNumber numberWithInt:val] forKey:s];
		stat.hasRemote = true;
		stat.remoteName = [[string stringByReplacingOccurrencesOfString:@"\n" withString:@""] UTF8String];
	}else{
		//NSLog(@"This Git Repo (%@) has NO remote", [s lastPathComponent]);
		//[numModifiedFiles setObject:[NSNumber numberWithInt:0] forKey:s];
		stat.hasRemote = false;
	}
	gitDirStats[key] = stat;
	[string release];
	return stat.hasRemote;
}

-(void)remoteDiff:(NSString *) s{

	NSTask * task = [[NSTask alloc] init];
	[task setLaunchPath:@"/bin/sh"];
	[task setCurrentDirectoryPath:s];
	// /bin/sh -c trick to complex pipes from http://borkware.com/quickies/one?topic=nstask
	//git fetch origin -q; git diff -w --shortstat  origin/master;
	[task setArguments:[NSArray arrayWithObjects:@"-c", @"/usr/bin/git fetch origin -q; /usr/bin/git diff -w --shortstat  origin/master; ",  nil]];

	NSPipe *pipe = [NSPipe pipe];
	[task setStandardOutput:pipe];
	[task launch];
	NSData * data = [[pipe fileHandleForReading] readDataToEndOfFile];
	[task waitUntilExit];
	[task release];
	NSString * string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] ;

	std::string key = [s UTF8String];
	gitRepoStat stat = gitDirStats[key];
	if ([string length] > 0){
		//NSLog(@"This Git Repo (%@) has a remote diff _%@_ ", [s lastPathComponent], string);
		//[numModifiedFiles setObject:[NSNumber numberWithInt:val] forKey:s];
		NSArray * comp = [[string stringByReplacingOccurrencesOfString:@"\n" withString:@""] componentsSeparatedByString:@","];
		if ([comp count] > 1){
			stat.remoteDiffs = [[[comp objectAtIndex:0] stringByReplacingOccurrencesOfString:@" changed" withString:@""] UTF8String];
		}else{
			stat.remoteDiffs = "???";
		}

	}else{
		//NSLog(@"This Git Repo (%@) has NO remote diff", [s lastPathComponent]);
	}
	gitDirStats[key] = stat;
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
		if ( [checkRemoteCheckbox state]){
			BOOL hasRemote = [self checkForRemote:s];
			if (hasRemote){
				[self remoteDiff:s];
			}
		}
		[self performSelectorOnMainThread:@selector(updateTable) withObject:nil waitUntilDone:YES];
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


-(NSString*)stringFromString:(string) s{
	return  [NSString stringWithCString:s.c_str() encoding:[NSString defaultCStringEncoding]];
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
			std::string key = [s UTF8String];
			gitRepoStat stat = gitDirStats[key];

			if( !stat.isDirty ){ //not locally dirty
				if (stat.hasRemote){
					if(stat.remoteDiffs == ""){ //nothing pending on remote
						return [NSImage imageNamed: @"1"]; //code away! u r in sync with remote
					}else{	//remote has newer stuff, we are old
						return [NSImage imageNamed: @"2"];	//u should pull!
					}
				}else{	//only local
					return [NSImage imageNamed: @"3"];
				}
			}else{ //local repo is dirty
				if (stat.hasRemote){
					if(stat.remoteDiffs == ""){ //nothing pending on remote
						return [NSImage imageNamed: @"4"]; // we should push to remote
					}else{	//remote has newer stuff, we are old, and we are dirty too >> need to merge!!
						return [NSImage imageNamed: @"5"];
					}
				}else{	//only local
					return [NSImage imageNamed: @"6"]; //u should commit!
				}
			}
		}else


		if ([[tableColumn identifier] isEqualTo: @"numLocal"]){
			[[tableColumn dataCell] setVerticalCentering:YES];
			if ( row < gitDirStats.size() ){
				std::string key = [s UTF8String];
				int val = gitDirStats[key].localModifications;
				if ( val > 0 ){
					//[[tableColumn dataCell] setTextColor: [NSColor colorWithDeviceRed:150/255. green:42/255. blue:50/255. alpha:1]];
					return [NSString stringWithFormat:@"%d files", val];
				}else{
					//[[tableColumn dataCell] setTextColor: [NSColor colorWithDeviceRed:112/255. green:167/255. blue:37/255. alpha:1]];
					return nil;
				}
			}
		}else


		if ([[tableColumn identifier] isEqualTo: @"remoteName"]){
			[[tableColumn dataCell] setVerticalCentering:YES];
			if ( row < gitDirStats.size() ){

				std::string key = [s UTF8String];
				gitRepoStat stat = gitDirStats[key];
				if ( stat.hasRemote ){
					//[[tableColumn dataCell] setTextColor: [NSColor colorWithDeviceRed:150/255. green:42/255. blue:50/255. alpha:1]];
					return [self stringFromString: stat.remoteName] ;
				}else{
					//[[tableColumn dataCell] setTextColor: [NSColor colorWithDeviceRed:112/255. green:167/255. blue:37/255. alpha:1]];
					return nil;
				}
			}
		}else


		if ([[tableColumn identifier] isEqualTo: @"remoteDiff"]){
			[[tableColumn dataCell] setVerticalCentering:YES];
			if ( row < gitDirStats.size() ){
				std::string key = [s UTF8String];
				gitRepoStat stat = gitDirStats[key];
				//[[tableColumn dataCell] setTextColor: [NSColor colorWithDeviceRed:150/255. green:42/255. blue:50/255. alpha:1]];
				return [self stringFromString: stat.remoteDiffs] ;
			}
		}else

			
		if ([[tableColumn identifier] isEqualTo: @"path"]){
			[[tableColumn dataCell] setVerticalCentering:YES];
			return [[s stringByReplacingOccurrencesOfString:[drop getPath] withString:@"➤"] stringByDeletingLastPathComponent];
		}else

		if ([[tableColumn identifier] isEqualTo: @"repo"]){
			[[tableColumn dataCell] setVerticalCentering:YES];
			return [NSString stringWithFormat:@" %@", [s lastPathComponent] ];
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
