//
//  MyNSTableView.m
//  GitRepoTrack
//
//  Created by Oriol Ferrer Mesià on 17/01/13.
//  Copyright (c) 2013 Oriol Ferrer Mesià. All rights reserved.
//

#import "MyNSTableView.h"

@implementation MyNSTableView

//- (void)mouseDown:(NSEvent *)theEvent {
//
//	[super mouseDown:theEvent];
//	NSPoint point = [self convertPoint:theEvent.locationInWindow fromView:nil];
//	NSView *theView = [self hitTest:point];
//	if ([theView isKindOfClass:[NSTextField class]]) {
//		NSTextField * field = (NSTextField *)theView;
//		[[field window] makeFirstResponder: field];
//	}
//}


@end


//http://stackoverflow.com/questions/1235219/is-there-a-right-way-to-have-nstextfieldcell-draw-vertically-centered-text

@implementation NSTextFieldCell (MyCategories)
- (void)setVerticalCentering:(BOOL)centerVertical
{
    @try { _cFlags.vCentered = centerVertical ? 1 : 0; }
    @catch(...) { NSLog(@"*** unable to set vertical centering"); }
}
@end