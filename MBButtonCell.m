//
//  MBButtonCell.m
//  MBTableGrid
//
//  Created by Brendan Duddridge on 2014-10-28.
//
//

#import "MBButtonCell.h"

@implementation MBButtonCell

- (instancetype)init {
	self = [super init];
	if (self) {
		self.title = nil;
		[self setBordered:NO];
		[self setBezeled:NO];
		[self setBackgroundColor:[NSColor clearColor]];
	}
	return self;
}

- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView withBackgroundColor:(NSColor *)backgroundColor
{
	
	[backgroundColor set];
	NSRectFill(cellFrame);
	
	[self drawWithFrame:cellFrame inView:controlView];
}

- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
	NSRect popupFrame = cellFrame;
	popupFrame.size.width = 16;
	popupFrame.size.height = 16;
	popupFrame.origin.x = cellFrame.origin.x + (cellFrame.size.width / 2 - 8);
	popupFrame.origin.y = cellFrame.origin.y + (cellFrame.size.height / 2 - 8);
	
	[super drawWithFrame:popupFrame inView:controlView];
	
	NSColor *borderColor = [NSColor colorWithDeviceWhite:0.83 alpha:1.0];
	[borderColor set];
	
	// Draw the right border
	NSRect rightLine = NSMakeRect(NSMaxX(cellFrame)-1.0, NSMinY(cellFrame), 1.0, NSHeight(cellFrame));
	NSRectFill(rightLine);
	
	// Draw the bottom border
	NSRect bottomLine = NSMakeRect(NSMinX(cellFrame), NSMaxY(cellFrame)-1.0, NSWidth(cellFrame), 1.0);
	NSRectFill(bottomLine);
	
	//	[self drawInteriorWithFrame:cellFrame inView:controlView];
}

- (NSColor *)highlightColorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
	// Do not draw any highlight.
	return nil;
}

@end
