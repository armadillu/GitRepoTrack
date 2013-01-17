//
//  MyNSTableView.h
//  GitRepoTrack
//
//  Created by Oriol Ferrer Mesià on 17/01/13.
//  Copyright (c) 2013 Oriol Ferrer Mesià. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface MyNSTableView : NSTableView

//- (void)mouseDown:(NSEvent *)theEvent ;

@end

//http://stackoverflow.com/questions/1235219/is-there-a-right-way-to-have-nstextfieldcell-draw-vertically-centered-text

@interface NSTextFieldCell (MyCategories)
- (void)setVerticalCentering:(BOOL)centerVertical;
@end
