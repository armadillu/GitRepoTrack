//
//  MyImageView.m
//  MenuApp
//
//  Created by Oriol Ferrer Mesià on 23/04/12.
//  Copyright 2012 uri.cat. All rights reserved.
//

#import "MyImageView.h"


@implementation MyImageView

//- (id)initWithFrame:(NSRect)frame{
//    self = [super initWithFrame:frame];
//    return self;
//}


-(void)awakeFromNib{
	[super awakeFromNib];
	scanPath = @"";
	[self loadPrefs];
}


- (void)savePrefs{
    //[self unregisterDraggedTypes];
	NSUserDefaults * d = [NSUserDefaults standardUserDefaults];
	[d setObject: scanPath forKey:@"scanPath"];
	[d synchronize];
    //[super dealloc];
}

-(void)loadPrefs{
	//[self registerForDraggedTypes:[NSArray arrayWithObject:NSFilenamesPboardType]];
	NSUserDefaults * d = [NSUserDefaults standardUserDefaults];
	scanPath = [d objectForKey:@"scanPath"];
	if(scanPath){
		[pathBar setURL:[NSURL fileURLWithPath:scanPath ]];
	}else{
		[self setImage: nil];
		[pathBar setURL:[NSURL fileURLWithPath:@"/"]];
	}
	NSImage * img = [[NSWorkspace sharedWorkspace] iconForFile: scanPath];
	[super setImage: img];
}


-(NSString*) getPath;{
	return scanPath;
}

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender{
    if ((NSDragOperationGeneric & [sender draggingSourceOperationMask]) 
                == NSDragOperationGeneric)
    {
        return NSDragOperationGeneric;
    }else{
        return NSDragOperationNone;
    }
}

- (void)draggingExited:(id <NSDraggingInfo>)sender{}


- (NSDragOperation)draggingUpdated:(id <NSDraggingInfo>)sender{
    if ((NSDragOperationGeneric & [sender draggingSourceOperationMask]) 
                    == NSDragOperationGeneric)
    {
        return NSDragOperationGeneric;
    }else{
        return NSDragOperationNone;
    }
}

- (void)draggingEnded:(id <NSDraggingInfo>)sender{}

- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender{
    return YES;
}


- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender{
	
    NSPasteboard *paste = [sender draggingPasteboard];
    NSArray *types = [NSArray arrayWithObjects: NSFilenamesPboardType, nil];
    NSString *desiredType = [paste availableTypeFromArray:types];
    NSData *carriedData = [paste dataForType:desiredType];

    if (nil == carriedData){
        NSRunAlertPanel(@"Paste Error", @"Sorry, but the past operation failed", nil, nil, nil);
        return NO;

    }else{
        
        if ([desiredType isEqualToString:NSFilenamesPboardType]){
            //we have a list of file names in an NSData object
			NSArray *fileArray = [paste propertyListForType:@"NSFilenamesPboardType"];
			NSString *path = [fileArray objectAtIndex:0];
			scanPath = path;
			[scanPath retain];
			NSURL * url = [NSURL fileURLWithPath:[scanPath stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
			//NSLog(@"url: %@", url);

			[pathBar performSelectorOnMainThread:@selector(setURL:) withObject:url waitUntilDone:NO];
			[self performSelectorOnMainThread:@selector(savePrefs) withObject:nil waitUntilDone:NO];
			//[pathBar setURL:[NSURL URLWithString:scanPath]];
			//[self savePrefs];
			NSImage * img = [[NSWorkspace sharedWorkspace] iconForFile: path];
			//NSLog(@"img: %@", img);
			[super setImage: img];
        }else{
            NSAssert(NO, @"This can't happen");
            return NO;
        }
    }

    [super setNeedsDisplay:YES];    //redraw us with the new image
    return YES;
}


- (void)concludeDragOperation:(id <NSDraggingInfo>)sender{
    //[self setNeedsDisplay:YES];
}


@end
