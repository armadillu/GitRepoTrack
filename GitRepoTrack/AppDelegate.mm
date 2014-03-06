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
	[drop setEnabled:false];
	[progress startAnimation:self];

	NSString * startAt = [[drop getPath] retain];
	[self scan:startAt];
	[startAt release];

	//[startButton setEnabled:true];
	[drop setEnabled:true];
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

-(void)checkSourceCodeLines:(NSString *) s{

	// git ls-files | grep  -e '\.m$' -e '\.h$' -e '\.mm$' -e '\.c$' -e '\.cpp$' -e '\.java$' -e '\.php$' -e '\.js$' -e '\.html$' -e '\.css$' -e '\.sh$' -e '\.py$' -e '\.frag$' -e '\.vert$' -e '\.geom$' -e '\.rb$' -e '\.pde$' -e '\.lua$' -e '\.pl$' | xargs wc -l | tail -1 | awk ' { print $1 } '


	NSTask * task = [[NSTask alloc] init];
	[task setLaunchPath:@"/bin/sh"];
	[task setCurrentDirectoryPath:s];
	[task setArguments: [NSArray arrayWithObjects:@"-c", @"/usr/bin/git ls-files | grep  -e '\.m$' -e '\.h$' -e '\.mm$' -e '\.txt$' -e '\.c$' -e '\.cpp$' -e '\.java$' -e '\.php$' -e '\.js$' -e '\.html$' -e '\.css$' -e '\.sh$' -e '\.py$' -e '\.frag$' -e '\.vert$' -e '\.geom$' -e '\.rb$' -e '\.pde$' -e '\.lua$' -e '\.pl$' | xargs -I{} wc -l {} | awk ' { print $1 } ' | awk '{s+=$1} END {print s}' ", nil]];
	NSPipe *pipe = [NSPipe pipe];
	[task setStandardOutput:pipe];
	[task launch];
	NSData * data = [[pipe fileHandleForReading] readDataToEndOfFile];
	[task waitUntilExit];
	[task release];
	NSString * string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];

	if ([string length] > 0){
		std::string key = [s UTF8String];
		//NSLog(@"This Git Repo Has %@ lines: %@ ", string, s );
		@synchronized (self) {
			gitRepoStat stat = gitDirStats[key];
			stat.numLines = [string intValue];
			stat.numLines = [string intValue];
			gitDirStats[key] = stat;
			NSLog(@"%@ has %d lines", s, stat.numLines);
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
		stat.localModifications = val;
	}else{
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
	[task setArguments:[NSArray arrayWithObjects:@"-c", @"/usr/bin/git remote -v | head -1",  nil]];

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
		stat.hasRemote = true;
		NSArray * split = [string componentsSeparatedByString:@"	"]; // tab separated >> "origin (tab) git@github.com:armadillu/ofxTouchHelper.git"
		if ( [split count] >= 2){
			stat.remoteName = [[[split objectAtIndex:0] stringByReplacingOccurrencesOfString:@"\n" withString:@""] UTF8String];
			stat.remoteURL = [[[split objectAtIndex:1] stringByReplacingOccurrencesOfString:@"(fetch)\n" withString:@""] UTF8String];
		}else{
			stat.remoteName = "??";
			stat.remoteName = "???";
		}

	}else{
		//NSLog(@"This Git Repo (%@) has NO remote", [s lastPathComponent]);
		stat.hasRemote = false;
	}
	gitDirStats[key] = stat;
	[string release];
	return stat.hasRemote;
}

-(void)remoteDiff:(NSString *) s{

	//NSLog(@"remoteDiff: (%@) ", [s lastPathComponent]);
	std::string key = [s UTF8String];
	gitRepoStat stat = gitDirStats[key];

	NSTask * task = [[NSTask alloc] init];
	[task setLaunchPath:@"/bin/sh"];
	[task setCurrentDirectoryPath:s];
	// /bin/sh -c trick to complex pipes from http://borkware.com/quickies/one?topic=nstask
	NSString * command = [NSString stringWithFormat:
						  @"/usr/bin/git fetch %s -q; /usr/bin/git diff -w --shortstat  master %s/master;",
						  stat.remoteName.c_str(), stat.remoteName.c_str()
						  ];
	[task setArguments:[NSArray arrayWithObjects:@"-c", command,  nil]];

	NSPipe *pipe = [NSPipe pipe];
	NSPipe *pipeErr = [NSPipe pipe];
	[task setStandardOutput:pipe];
	[task setStandardError:pipeErr];
	[task launch];
	NSData * data = [[pipe fileHandleForReading] readDataToEndOfFile];
	NSData * dataErr = [[pipeErr fileHandleForReading] readDataToEndOfFile];
	[task waitUntilExit];
	[task release];
	NSString * string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] ;
	NSString * stringErr = [[NSString alloc] initWithData:dataErr encoding:NSUTF8StringEncoding] ;

	if([stringErr length] > 0 ){
		stat.remoteError = true;
		NSLog(@"Error at remoteDiff for repo %@ >> %@", [s lastPathComponent], [stringErr stringByReplacingOccurrencesOfString:@"\n" withString:@" "]);
	}else{
		if ([string length] > 0){
			NSArray * comp = [[string stringByReplacingOccurrencesOfString:@"\n" withString:@""] componentsSeparatedByString:@","];
			if ([comp count] > 1){
				stat.remoteDiffs = [[[comp objectAtIndex:0] stringByReplacingOccurrencesOfString:@" changed" withString:@""] UTF8String];
			}else{
				stat.remoteDiffs = "";
			}
		}else{
			//NSLog(@"This Git Repo (%@) has NO remote diff", [s lastPathComponent]);
		}
	}

	gitDirStats[key] = stat;
	[string release];
	[stringErr release];
}



-(void)scan:(NSString *) s{

	if(forceStop) return; // stop scan if asked to do so

	NSFileManager * fm = [NSFileManager defaultManager];

	BOOL isDir;
	NSArray * dirs = [fm contentsOfDirectoryAtPath:s error:nil];
	NSString * gitPath = [NSString stringWithFormat:@"%@/.git", s ];

	//if this dir contains a .git init, add to gitDirs and continue diving in that tree branch
	BOOL exists = [fm fileExistsAtPath:gitPath isDirectory:&isDir];
	NSDictionary * atts = [fm attributesOfItemAtPath: s error:nil];
	BOOL isSymLink = [atts objectForKey:NSFileType] == NSFileTypeSymbolicLink;
	//if (isSymLink) NSLog(@"GitRepoHub doesn't follow symlinks! %@", s);

	if( exists && !isSymLink ){

		@synchronized (self) {
			[gitDirs addObject: s];
		}
		[self checkIfDirty:s];
		[self checkNumberOfModifiedFiles:s];
		[self checkSourceCodeLines:s];
		
		if ( [checkRemoteCheckbox state]){
			BOOL hasRemote = [self checkForRemote:s];
			if (hasRemote){
				[self remoteDiff:s];
			}
		}
		[self performSelectorOnMainThread:@selector(updateTable) withObject:nil waitUntilDone:YES];

	}
//	else{

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
//	}
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

			if( !stat.isDirty ){ //local repo is clean
				if (stat.hasRemote){
					if(stat.remoteError){
						return [NSImage imageNamed: @"7"]; //err with remote, local clean
					}else{
						if(stat.remoteDiffs == ""){ //nothing pending on remote
							return [NSImage imageNamed: @"1"]; //code away! u r in sync with remote
						}else{	//remote has newer stuff, we are old
							return [NSImage imageNamed: @"2"];	//u should pull!
						}
					}
				}else{	//only local
					return [NSImage imageNamed: @"3"];
				}
			}else{ //local repo is dirty
				if (stat.hasRemote){
					if(stat.remoteError){
						return [NSImage imageNamed: @"8"]; //err with remote, local dirty
					}else{
						if(stat.remoteDiffs == ""){ //nothing pending on remote
							return [NSImage imageNamed: @"4"]; // we should push to remote
						}else{	//remote has newer stuff, we are old, and we are dirty too >> need to merge!!
							return [NSImage imageNamed: @"5"];
						}
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
				gitRepoStat stat = gitDirStats[key];
				int val = stat.localModifications;
				if ( val > 0 ){
//					if (stat.hasRemote){
//						[[tableColumn dataCell] setTextColor: [NSColor colorWithDeviceRed:150/255. green:5/255. blue:204/255. alpha:1]];
//					}else{
//						[[tableColumn dataCell] setTextColor: [NSColor colorWithDeviceRed:180/255. green:0/255. blue:2/255. alpha:1]];
//					}
					return [NSString stringWithFormat: (val==1 ? @"%d file" : @"%d files") , val];
				}else{
					//[[tableColumn dataCell] setTextColor: [NSColor colorWithDeviceRed:112/255. green:167/255. blue:37/255. alpha:1]];
					return nil;
				}
			}
		}else


			if ([[tableColumn identifier] isEqualTo: @"lines"]){
				[[tableColumn dataCell] setVerticalCentering:YES];
				if ( row < gitDirStats.size() ){
					std::string key = [s UTF8String];
					gitRepoStat stat = gitDirStats[key];
					return [NSString stringWithFormat:@"%d", stat.numLines] ;
				}
			}else


		if ([[tableColumn identifier] isEqualTo: @"remoteName"]){
			[[tableColumn dataCell] setVerticalCentering:YES];
			if ( row < gitDirStats.size() ){

				std::string key = [s UTF8String];
				gitRepoStat stat = gitDirStats[key];
				if ( stat.hasRemote ){
					//[[tableColumn dataCell] setTextColor: [NSColor colorWithDeviceRed:150/255. green:42/255. blue:50/255. alpha:1]];
					//return [self stringFromString: stat.remoteName + " - " + stat.remoteURL] ;
					return [self stringFromString: stat.remoteURL] ;
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
				//[[tableColumn dataCell] setTextColor: [NSColor colorWithDeviceRed:22/255. green:160/255. blue:233/255. alpha:1]];
				return [self stringFromString: stat.remoteDiffs] ;
			}
		}else

			
		if ([[tableColumn identifier] isEqualTo: @"path"]){
			[[tableColumn dataCell] setVerticalCentering:YES];
			return [s stringByReplacingOccurrencesOfString:[drop getPath] withString:@"➤"];
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
	//NSLog(@"edit >> %@", s);
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
