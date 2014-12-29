/*
 Copyright (c) 2008 Matthew Ball - http://www.mattballdesign.com
 
 Permission is hereby granted, free of charge, to any person
 obtaining a copy of this software and associated documentation
 files (the "Software"), to deal in the Software without
 restriction, including without limitation the rights to use,
 copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the
 Software is furnished to do so, subject to the following
 conditions:
 
 The above copyright notice and this permission notice shall be
 included in all copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
 OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
 HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
 WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
 OTHER DEALINGS IN THE SOFTWARE.
 */

#import "MBTableGridContentView.h"

#import "MBTableGrid.h"
#import "MBTableGridCell.h"
#import "MBPopupButtonCell.h"
#import "MBButtonCell.h"
#import "MBImageCell.h"
#import "MBLevelIndicatorCell.h"

#define kGRAB_HANDLE_HALF_SIDE_LENGTH 2.0f
#define kGRAB_HANDLE_SIDE_LENGTH 4.0f

@interface MBTableGrid (Private)
- (id)_objectValueForColumn:(NSUInteger)columnIndex row:(NSUInteger)rowIndex;
- (NSFormatter *)_formatterForColumn:(NSUInteger)columnIndex;
- (NSCell *)_cellForColumn:(NSUInteger)columnIndex;
- (NSImage *)_accessoryButtonImageForColumn:(NSUInteger)columnIndex row:(NSUInteger)rowIndex;
- (void)_accessoryButtonClicked:(NSUInteger)columnIndex row:(NSUInteger)rowIndex;
- (NSArray *)_availableObjectValuesForColumn:(NSUInteger)columnIndex;
- (void)_setObjectValue:(id)value forColumn:(NSUInteger)columnIndex row:(NSUInteger)rowIndex;
- (BOOL)_canEditCellAtColumn:(NSUInteger)columnIndex row:(NSUInteger)rowIndex;
- (void)_setStickyColumn:(MBTableGridEdge)stickyColumn row:(MBTableGridEdge)stickyRow;
- (float)_widthForColumn:(NSUInteger)columnIndex;
- (id)_backgroundColorForColumn:(NSUInteger)columnIndex row:(NSUInteger)rowIndex;
- (MBTableGridEdge)_stickyColumn;
- (MBTableGridEdge)_stickyRow;
- (void)_userDidEnterInvalidStringInColumn:(NSUInteger)columnIndex row:(NSUInteger)rowIndex errorDescription:(NSString *)errorDescription;
@end

@interface MBTableGridContentView (Cursors)
- (NSCursor *)_cellSelectionCursor;
- (NSImage *)_cellSelectionCursorImage;
- (NSCursor *)_cellExtendSelectionCursor;
- (NSImage *)_cellExtendSelectionCursorImage;
@end

@interface MBTableGridContentView (DragAndDrop)
- (void)_setDraggingColumnOrRow:(BOOL)flag;
- (void)_setDropColumn:(NSInteger)columnIndex;
- (void)_setDropRow:(NSInteger)rowIndex;
- (void)_timerAutoscrollCallback:(NSTimer *)aTimer;
@end

@implementation MBTableGridContentView

#pragma mark -
#pragma mark Initialization & Superclass Overrides

- (id)initWithFrame:(NSRect)frameRect
{
	if(self = [super initWithFrame:frameRect]) {
		mouseDownColumn = NSNotFound;
		mouseDownRow = NSNotFound;
		
		editedColumn = NSNotFound;
		editedRow = NSNotFound;
		
		dropColumn = NSNotFound;
		dropRow = NSNotFound;
        
        
        grabHandleRect = NSRectFromCGRect(CGRectZero);
		
		// Cache the cursor image
		cursorImage = [self _cellSelectionCursorImage];
        cursorExtendSelectionImage = [self _cellExtendSelectionCursorImage];
		
		isDraggingColumnOrRow = NO;
		
		_defaultCell = [[MBTableGridCell alloc] initTextCell:@""];
        [_defaultCell setBordered:YES];
		[_defaultCell setScrollable:YES];
		[_defaultCell setLineBreakMode:NSLineBreakByTruncatingTail];
	}
	return self;
}


- (void)drawRect:(NSRect)rect
{
    
	NSUInteger numberOfColumns = [self tableGrid].numberOfColumns;
	NSUInteger numberOfRows = [self tableGrid].numberOfRows;
	
	NSUInteger firstColumn = NSNotFound;
	NSUInteger lastColumn = numberOfColumns - 1;
	NSUInteger firstRow = NSNotFound;
	NSUInteger lastRow = numberOfRows - 1;
	
	// Find the columns to draw
	NSUInteger column = 0;
	while (column < numberOfColumns) {
		NSRect columnRect = [self rectOfColumn:column];
		if (firstColumn == NSNotFound && NSMinX(rect) >= NSMinX(columnRect) && NSMinX(rect) <= NSMaxX(columnRect)) {
			firstColumn = column;
		} else if (firstColumn != NSNotFound && NSMaxX(rect) >= NSMinX(columnRect) && NSMaxX(rect) <= NSMaxX(columnRect)) {
			lastColumn = column;
			break;
		}
		column++;
	}
	
	// Find the rows to draw
	NSUInteger row = 0;
	while (row < numberOfRows) {
		NSRect rowRect = [self rectOfRow:row];
		if (firstRow == NSNotFound && NSMinY(rect) >= rowRect.origin.x && NSMinY(rect) <= NSMaxY(rowRect)) {
			firstRow = row;
		} else if (firstRow != NSNotFound && NSMaxY(rect) >= NSMinY(rowRect) && NSMaxY(rect) <= NSMaxY(rowRect)) {
			lastRow = row;
			break;
		}
		row++;
	}	
	
	column = firstColumn;
	while (column <= lastColumn) {
		row = firstRow;
		while (row <= lastRow) {
			NSRect cellFrame = [self frameOfCellAtColumn:column row:row];
			// Only draw the cell if we need to
			if ([self needsToDrawRect:cellFrame] && !(row == editedRow && column == editedColumn)) {
                
                NSColor *backgroundColor = [[self tableGrid] _backgroundColorForColumn:column row:row] ?: [NSColor whiteColor];
				
				NSCell *_cell = [[self tableGrid] _cellForColumn:column];

				if (!_cell) {
					_cell = _defaultCell;
				}
				
				[_cell setFormatter:nil]; // An exception is raised if the formatter is not set to nil before changing at runtime
				[_cell setFormatter:[[self tableGrid] _formatterForColumn:column]];
				
				id objectValue = [[self tableGrid] _objectValueForColumn:column row:row];
				
				if ([_cell isKindOfClass:[MBPopupButtonCell class]]) {
					MBPopupButtonCell *cell = (MBPopupButtonCell *)_cell;
					NSInteger index = [cell indexOfItemWithTitle:objectValue];
					[_cell setObjectValue:@(index)];
				} else {
					[_cell setObjectValue:objectValue];
				}
				
				if ([_cell isKindOfClass:[MBPopupButtonCell class]]) {
					
					MBPopupButtonCell *cell = (MBPopupButtonCell *)_cell;
					[cell drawWithFrame:cellFrame inView:self withBackgroundColor:backgroundColor];// Draw background color
					
				} else if ([_cell isKindOfClass:[MBImageCell class]]) {
					
					MBImageCell *cell = (MBImageCell *)_cell;
					cell.accessoryButtonImage = [[self tableGrid] _accessoryButtonImageForColumn:column row:row];
					
					[cell drawWithFrame:cellFrame inView:self withBackgroundColor:backgroundColor];// Draw background color
					
				} else if ([_cell isKindOfClass:[MBLevelIndicatorCell class]]) {
					
					MBLevelIndicatorCell *cell = (MBLevelIndicatorCell *)_cell;

					cell.target = self;
					cell.action = @selector(updateLevelIndicator:);
					
					[cell drawWithFrame:cellFrame inView:[self tableGrid] withBackgroundColor:backgroundColor];// Draw background color
					
				} else {
					
					MBTableGridCell *cell = (MBTableGridCell *)_cell;
					cell.accessoryButtonImage = [[self tableGrid] _accessoryButtonImageForColumn:column row:row];
					
					[cell drawWithFrame:cellFrame inView:self withBackgroundColor:backgroundColor];// Draw background color
					
				}
			}
			row++;
		}
		column++;
	}
	
	// Draw the selection rectangle
	NSIndexSet *selectedColumns = [[self tableGrid] selectedColumnIndexes];
	NSIndexSet *selectedRows = [[self tableGrid] selectedRowIndexes];
	
	if([selectedColumns count] && [selectedRows count] && [self tableGrid].numberOfColumns > 0 && [self tableGrid].numberOfRows > 0) {
		NSRect selectionTopLeft = [self frameOfCellAtColumn:[selectedColumns firstIndex] row:[selectedRows firstIndex]];
		NSRect selectionBottomRight = [self frameOfCellAtColumn:[selectedColumns lastIndex] row:[selectedRows lastIndex]];
		
		NSRect selectionRect;
		selectionRect.origin = selectionTopLeft.origin;
		selectionRect.size.width = NSMaxX(selectionBottomRight)-selectionTopLeft.origin.x;
		selectionRect.size.height = NSMaxY(selectionBottomRight)-selectionTopLeft.origin.y;
		
        NSRect selectionInsetRect = NSInsetRect(selectionRect, 1, 1);
		NSBezierPath *selectionPath = [NSBezierPath bezierPathWithRect:selectionInsetRect];
		NSAffineTransform *translate = [NSAffineTransform transform];
		[translate translateXBy:-0.5 yBy:-0.5];
		[selectionPath transformUsingAffineTransform:translate];
		
		NSColor *selectionColor = [NSColor alternateSelectedControlColor];
		
		// If the view is not the first responder, then use a gray selection color
		NSResponder *firstResponder = [[self window] firstResponder];
		if (![[firstResponder class] isSubclassOfClass:[NSView class]] || ![(NSView *)firstResponder isDescendantOf:[self tableGrid]] || ![[self window] isKeyWindow]) {
			selectionColor = [[selectionColor colorUsingColorSpaceName:NSDeviceWhiteColorSpace] colorUsingColorSpaceName:NSDeviceRGBColorSpace];
		}
        else
        {
            // Draw grab handle
            [selectionColor set];
            grabHandleRect = NSMakeRect(NSMaxX(selectionInsetRect) - kGRAB_HANDLE_HALF_SIDE_LENGTH, NSMaxY(selectionInsetRect) - kGRAB_HANDLE_HALF_SIDE_LENGTH, kGRAB_HANDLE_SIDE_LENGTH, kGRAB_HANDLE_SIDE_LENGTH);
            NSRectFill(grabHandleRect);
        }
		
		[selectionColor set];
		[selectionPath setLineWidth: 1.0];
		[selectionPath stroke];
        
        [[selectionColor colorWithAlphaComponent:0.2f] set];
        [selectionPath fill];
        
        // Inavlidate cursors so we use the correct cursor for the selection in the right place
        [[self window] invalidateCursorRectsForView:self];
	}
	
	// Draw the column drop indicator
	if (isDraggingColumnOrRow && dropColumn != NSNotFound && dropColumn <= [self tableGrid].numberOfColumns && dropRow == NSNotFound) {
		NSRect columnBorder;
		if(dropColumn < [self tableGrid].numberOfColumns) {
			columnBorder = [self rectOfColumn:dropColumn];
		} else {
			columnBorder = [self rectOfColumn:dropColumn-1];
			columnBorder.origin.x += columnBorder.size.width;
		}
		columnBorder.origin.x = NSMinX(columnBorder)-2.0;
		columnBorder.size.width = 4.0;
		
		NSColor *selectionColor = [NSColor alternateSelectedControlColor];
		
		NSBezierPath *borderPath = [NSBezierPath bezierPathWithRect:columnBorder];
		[borderPath setLineWidth:2.0];
		
		[selectionColor set];
		[borderPath stroke];
	}
	
	// Draw the row drop indicator
	if (isDraggingColumnOrRow && dropRow != NSNotFound && dropRow <= [self tableGrid].numberOfRows && dropColumn == NSNotFound) {
		NSRect rowBorder;
		if(dropRow < [self tableGrid].numberOfRows) {
			rowBorder = [self rectOfRow:dropRow];
		} else {
			rowBorder = [self rectOfRow:dropRow-1];
			rowBorder.origin.y += rowBorder.size.height;
		}
		rowBorder.origin.y = NSMinY(rowBorder)-2.0;
		rowBorder.size.height = 4.0;
		
		NSColor *selectionColor = [NSColor alternateSelectedControlColor];
		
		NSBezierPath *borderPath = [NSBezierPath bezierPathWithRect:rowBorder];
		[borderPath setLineWidth:2.0];
		
		[selectionColor set];
		[borderPath stroke];
	}
	
	// Draw the cell drop indicator
	if (!isDraggingColumnOrRow && dropRow != NSNotFound && dropRow <= [self tableGrid].numberOfRows && dropColumn != NSNotFound && dropColumn <= [self tableGrid].numberOfColumns) {
		NSRect cellFrame = [self frameOfCellAtColumn:dropColumn row:dropRow];
		cellFrame.origin.x -= 2.0;
		cellFrame.origin.y -= 2.0;
		cellFrame.size.width += 3.0;
		cellFrame.size.height += 3.0;
		
		NSBezierPath *borderPath = [NSBezierPath bezierPathWithRect:NSInsetRect(cellFrame, 2, 2)];
		
		NSColor *dropColor = [NSColor alternateSelectedControlColor];
		[dropColor set];
		
		[borderPath setLineWidth:2.0];
		[borderPath stroke];
	}
}

- (void)updateCell:(id)sender {
	// This is here just to satisfy NSLevelIndicatorCell because
	// when this view is the controlView for the NSLevelIndicatorCell,
	// it calls updateCell on this controlView.
}

- (void)updateLevelIndicator:(NSNumber *)value {
	NSInteger selectedColumn = [[self tableGrid].selectedColumnIndexes firstIndex];
	NSInteger selectedRow = [[self tableGrid].selectedRowIndexes firstIndex];
	// sanity check to make sure we have an NSNumber.
	// I've observed that when the user lets go of the mouse,
	// the value parameter becomes the MBTableGridContentView
	// object for some reason.
	if ([value isKindOfClass:[NSNumber class]]) {
		[[self tableGrid] _setObjectValue:value forColumn:selectedColumn row:selectedRow];
		NSRect cellFrame = [[self tableGrid] frameOfCellAtColumn:selectedColumn row:selectedRow];
		[[self tableGrid] setNeedsDisplayInRect:cellFrame];
	}
}

- (BOOL)isFlipped
{
	return YES;
}

- (void)mouseDown:(NSEvent *)theEvent
{
	// Setup the timer for autoscrolling
	// (the simply calling autoscroll: from mouseDragged: only works as long as the mouse is moving)
	autoscrollTimer = [NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(_timerAutoscrollCallback:) userInfo:nil repeats:YES];
	
	NSPoint mouseLocationInContentView = [self convertPoint:[theEvent locationInWindow] fromView:nil];
	mouseDownColumn = [self columnAtPoint:mouseLocationInContentView];
	mouseDownRow = [self rowAtPoint:mouseLocationInContentView];
	NSCell *cell = [[self tableGrid] _cellForColumn:mouseDownColumn];
	BOOL cellEditsOnFirstClick = ([cell respondsToSelector:@selector(editOnFirstClick)] && [(id<MBTableGridEditable>)cell editOnFirstClick]);

	if (theEvent.clickCount == 1) {
		// Pass the event back to the MBTableGrid (Used to give First Responder status)
		[[self tableGrid] mouseDown:theEvent];
		
		NSUInteger selectedColumn = [[self tableGrid].selectedColumnIndexes firstIndex];
		NSUInteger selectedRow = [[self tableGrid].selectedRowIndexes firstIndex];

		// Edit an already selected cell if it doesn't edit on first click
		if (selectedColumn == mouseDownColumn && selectedRow == mouseDownRow && !cellEditsOnFirstClick) {
			
			if ([[self tableGrid] _accessoryButtonImageForColumn:mouseDownColumn row:mouseDownRow]) {
				NSRect cellFrame = [self frameOfCellAtColumn:mouseDownColumn row:mouseDownRow];
				NSCellHitResult hitResult = [cell hitTestForEvent:theEvent inRect:cellFrame ofView:self];
				if (hitResult != NSCellHitNone) {
					[[self tableGrid] _accessoryButtonClicked:mouseDownColumn row:mouseDownRow];
				}
			} else if ([cell isKindOfClass:[MBLevelIndicatorCell class]]) {
				NSRect cellFrame = [self frameOfCellAtColumn:mouseDownColumn row:mouseDownRow];
				
				[cell trackMouse:theEvent inRect:cellFrame ofView:self untilMouseUp:YES];
				
			} else {
				[self editSelectedCell:self text:nil];
			}
			
		// Expand a selection when the user holds the shift key
		} else if (([theEvent modifierFlags] & NSShiftKeyMask) && [self tableGrid].allowsMultipleSelection) {
			// If the shift key was held down, extend the selection
			NSUInteger stickyColumn = [[self tableGrid].selectedColumnIndexes firstIndex];
			NSUInteger stickyRow = [[self tableGrid].selectedRowIndexes firstIndex];
			
			MBTableGridEdge stickyColumnEdge = [[self tableGrid] _stickyColumn];
			MBTableGridEdge stickyRowEdge = [[self tableGrid] _stickyRow];
			
			// Compensate for sticky edges
			if (stickyColumnEdge == MBTableGridRightEdge) {
				stickyColumn = [[self tableGrid].selectedColumnIndexes lastIndex];
			}
			if (stickyRowEdge == MBTableGridBottomEdge) {
				stickyRow = [[self tableGrid].selectedRowIndexes lastIndex];
			}
			
			NSRange selectionColumnRange = NSMakeRange(stickyColumn, mouseDownColumn-stickyColumn+1);
			NSRange selectionRowRange = NSMakeRange(stickyRow, mouseDownRow-stickyRow+1);
			
			if (mouseDownColumn < stickyColumn) {
				selectionColumnRange = NSMakeRange(mouseDownColumn, stickyColumn-mouseDownColumn+1);
				stickyColumnEdge = MBTableGridRightEdge;
			} else {
				stickyColumnEdge = MBTableGridLeftEdge;
			}
			
			if (mouseDownRow < stickyRow) {
				selectionRowRange = NSMakeRange(mouseDownRow, stickyRow-mouseDownRow+1);
				stickyRowEdge = MBTableGridBottomEdge;
			} else {
				stickyRowEdge = MBTableGridTopEdge;
			}
			
			// Select the proper cells
			[self tableGrid].selectedColumnIndexes = [NSIndexSet indexSetWithIndexesInRange:selectionColumnRange];
			[self tableGrid].selectedRowIndexes = [NSIndexSet indexSetWithIndexesInRange:selectionRowRange];
			
			// Set the sticky edges
			[[self tableGrid] _setStickyColumn:stickyColumnEdge row:stickyRowEdge];
		// First click on a cell without shift key modifier
		} else {
			// No modifier keys, so change the selection
			[self tableGrid].selectedColumnIndexes = [NSIndexSet indexSetWithIndex:mouseDownColumn];
			[self tableGrid].selectedRowIndexes = [NSIndexSet indexSetWithIndex:mouseDownRow];
			[[self tableGrid] _setStickyColumn:MBTableGridLeftEdge row:MBTableGridTopEdge];
		}
    // Edit cells on double click if they don't already edit on first click
	} else if (theEvent.clickCount == 2 && !cellEditsOnFirstClick && ![cell isKindOfClass:[MBLevelIndicatorCell class]]) {
		// Double click
		[self editSelectedCell:self text:nil];
	}

	// Any cells that should edit on first click are handled here
	if (cellEditsOnFirstClick) {
		NSRect cellFrame = [[self tableGrid] frameOfCellAtColumn:mouseDownColumn row:mouseDownRow];
		cellFrame = NSOffsetRect(cellFrame, -self.enclosingScrollView.frame.origin.x, -self.enclosingScrollView.frame.origin.y);
		BOOL mouseEventHitButton = [cell hitTestForEvent:theEvent inRect:cellFrame ofView:self] == NSCellHitContentArea;
		if (mouseEventHitButton) {
			[self editSelectedCell:self text:nil];
		}
	}

	[self setNeedsDisplay:YES];
}

- (void)mouseDragged:(NSEvent *)theEvent
{
	if (mouseDownColumn != NSNotFound && mouseDownRow != NSNotFound && [self tableGrid].allowsMultipleSelection) {
		NSPoint loc = [self convertPoint:[theEvent locationInWindow] fromView:nil];
		NSInteger column = [self columnAtPoint:loc];
		NSInteger row = [self rowAtPoint:loc];
		
		MBTableGridEdge columnEdge = MBTableGridLeftEdge;
		MBTableGridEdge rowEdge = MBTableGridTopEdge;
		
		// Select the appropriate number of columns
		if(column != NSNotFound) {
			NSInteger firstColumnToSelect = mouseDownColumn;
			NSInteger numberOfColumnsToSelect = column-mouseDownColumn+1;
			if(column < mouseDownColumn) {
				firstColumnToSelect = column;
				numberOfColumnsToSelect = mouseDownColumn-column+1;
				
				// Set the sticky edge to the right
				columnEdge = MBTableGridRightEdge;
			}
			
			[self tableGrid].selectedColumnIndexes = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(firstColumnToSelect,numberOfColumnsToSelect)];
			
		}
		
		// Select the appropriate number of rows
		if(row != NSNotFound) {
			NSInteger firstRowToSelect = mouseDownRow;
			NSInteger numberOfRowsToSelect = row-mouseDownRow+1;
			if(row < mouseDownRow) {
				firstRowToSelect = row;
				numberOfRowsToSelect = mouseDownRow-row+1;
				
				// Set the sticky row to the bottom
				rowEdge = MBTableGridBottomEdge;
			}
			
			[self tableGrid].selectedRowIndexes = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(firstRowToSelect,numberOfRowsToSelect)];
			
		}
		
		// Set the sticky edges
		[[self tableGrid] _setStickyColumn:columnEdge row:rowEdge];
		
        [self setNeedsDisplay:YES];
	}
	
//	[self autoscroll:theEvent];
}

- (void)mouseUp:(NSEvent *)theEvent
{
	[autoscrollTimer invalidate];
	autoscrollTimer = nil;
	
	mouseDownColumn = NSNotFound;
	mouseDownRow = NSNotFound;
}

#pragma mark Cursor Rects

- (void)resetCursorRects
{
    //NSLog(@"%s - %f %f %f %f", __func__, grabHandleRect.origin.x, grabHandleRect.origin.y, grabHandleRect.size.width, grabHandleRect.size.height);
	// The main cursor should be the cell selection cursor
	
	NSIndexSet *selectedColumns = [self tableGrid].selectedColumnIndexes;
	NSIndexSet *selectedRows = [self tableGrid].selectedRowIndexes;

	NSRect selectionTopLeft = [self frameOfCellAtColumn:[selectedColumns firstIndex] row:[selectedRows firstIndex]];
	NSRect selectionBottomRight = [self frameOfCellAtColumn:[selectedColumns lastIndex] row:[selectedRows lastIndex]];
	
	NSRect selectionRect;
	selectionRect.origin = selectionTopLeft.origin;
	selectionRect.size.width = NSMaxX(selectionBottomRight)-selectionTopLeft.origin.x;
	selectionRect.size.height = NSMaxY(selectionBottomRight)-selectionTopLeft.origin.y;

	[self addCursorRect:selectionRect cursor:[NSCursor arrowCursor]];

	[self addCursorRect:[self visibleRect] cursor:[self _cellSelectionCursor]];
    [self addCursorRect:grabHandleRect cursor:[self _cellExtendSelectionCursor]];
}

#pragma mark -
#pragma mark Notifications

#pragma mark Field Editor

- (void)textDidEndEditing:(NSNotification *)aNotification
{	
	// Give focus back to the table grid (the field editor took it)
	[[self window] makeFirstResponder:[self tableGrid]];
	
	NSString *stringValue = [[[aNotification object] string] copy];
	id objectValue;
	NSString *errorDescription;
	NSFormatter *formatter = [[self tableGrid] _formatterForColumn:editedColumn];
	BOOL success = [formatter getObjectValue:&objectValue forString:stringValue errorDescription:&errorDescription];
	if (formatter && success) {
		[[self tableGrid] _setObjectValue:objectValue forColumn:editedColumn row:editedRow];
	}
	else if (!formatter) {
		[[self tableGrid] _setObjectValue:stringValue forColumn:editedColumn row:editedRow];
	}
	else {
		[[self tableGrid] _userDidEnterInvalidStringInColumn:editedColumn row:editedRow errorDescription:errorDescription];
	}

	editedColumn = NSNotFound;
	editedRow = NSNotFound;
	
	// End the editing session
	[[[self tableGrid] cell] endEditing:[[self window] fieldEditor:NO forObject:self]];

	NSInteger movementType = [aNotification.userInfo[@"NSTextMovement"] integerValue];
	switch (movementType) {
		case NSTabTextMovement:
			[[self tableGrid] moveRight:self];
			break;
		case NSReturnTextMovement:
			[[self tableGrid] moveDown:self];
			break;
		default:
			break;
	}
}

#pragma mark -
#pragma mark Protocol Methods

#pragma mark NSDraggingDestination

/*
 * These methods simply pass the drag event back to the table grid.
 * They are only required for autoscrolling.
 */

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender
{
	// Setup the timer for autoscrolling 
	// (the simply calling autoscroll: from mouseDragged: only works as long as the mouse is moving)
	autoscrollTimer = [NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(_timerAutoscrollCallback:) userInfo:nil repeats:YES];
	
	return [[self tableGrid] draggingEntered:sender];
}

- (NSDragOperation)draggingUpdated:(id <NSDraggingInfo>)sender
{
	return [[self tableGrid] draggingUpdated:sender];
}

- (void)draggingExited:(id <NSDraggingInfo>)sender
{
	[autoscrollTimer invalidate];
	autoscrollTimer = nil;
	
	[[self tableGrid] draggingExited:sender];
}

- (void)draggingEnded:(id <NSDraggingInfo>)sender
{
	[[self tableGrid] draggingEnded:sender];
}

- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender
{
	return [[self tableGrid] prepareForDragOperation:sender];
}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender
{
	return [[self tableGrid] performDragOperation:sender];
}

- (void)concludeDragOperation:(id <NSDraggingInfo>)sender
{
	[[self tableGrid] concludeDragOperation:sender];
}

#pragma mark -
#pragma mark Subclass Methods

- (MBTableGrid *)tableGrid
{
	return (MBTableGrid *)[[self enclosingScrollView] superview];
}

- (void)editSelectedCell:(id)sender text:(NSString *)aString
{
	NSInteger selectedColumn = [[self tableGrid].selectedColumnIndexes firstIndex];
	NSInteger selectedRow = [[self tableGrid].selectedRowIndexes firstIndex];
	NSCell *selectedCell = [[self tableGrid] _cellForColumn:selectedColumn];

	// Check if the cell can be edited
	if(![[self tableGrid] _canEditCellAtColumn:selectedColumn row:selectedColumn]) {
		editedColumn = NSNotFound;
		editedRow = NSNotFound;
		return;
	}

	// Select it and only it
	if([[self tableGrid].selectedColumnIndexes count] > 1) {
		[self tableGrid].selectedColumnIndexes = [NSIndexSet indexSetWithIndex:editedColumn];
	}
	if([[self tableGrid].selectedRowIndexes count] > 1) {
		[self tableGrid].selectedRowIndexes = [NSIndexSet indexSetWithIndex:editedRow];
	}

	// Editing a button cell involves simply toggling its state, we don't need to change the edited column and row or enter an editing state
	if ([selectedCell isKindOfClass:[MBButtonCell class]]) {
		id currentValue = [[self tableGrid] _objectValueForColumn:selectedColumn row:selectedRow];
		selectedCell.objectValue = @(![currentValue boolValue]);
		[[self tableGrid] _setObjectValue:selectedCell.objectValue forColumn:selectedColumn row:selectedRow];

		return;
		
	} else if ([selectedCell isKindOfClass:[MBImageCell class]]) {
		editedColumn = NSNotFound;
		editedRow = NSNotFound;
		
		return;
	} else if ([selectedCell isKindOfClass:[MBLevelIndicatorCell class]]) {
		
		MBLevelIndicatorCell *cell = (MBLevelIndicatorCell *)selectedCell;
		
		id currentValue = [[self tableGrid] _objectValueForColumn:selectedColumn row:selectedRow];
		
		if ([aString isEqualToString:@" "]) {
			if ([currentValue integerValue] >= cell.maxValue) {
				cell.objectValue = @0;
			} else {
				cell.objectValue = @([currentValue integerValue] + 1);
			}
		} else {
			NSInteger ratingValue = [aString integerValue];
			if (ratingValue <= cell.maxValue) {
				cell.objectValue = @([aString integerValue]);
			} else {
				cell.objectValue = @([currentValue integerValue]);
			}
		}
		
		[[self tableGrid] _setObjectValue:cell.objectValue forColumn:selectedColumn row:selectedRow];

		editedColumn = NSNotFound;
		editedRow = NSNotFound;
		
		return;
	}

	// Get the top-left selection
	editedColumn = selectedColumn;
	editedRow = selectedRow;

	NSRect cellFrame = [self frameOfCellAtColumn:editedColumn row:editedRow];

	[selectedCell setEditable:YES];
	[selectedCell setSelectable:YES];
	
	id currentValue = [[self tableGrid] _objectValueForColumn:editedColumn row:editedRow];

	if ([selectedCell isKindOfClass:[MBPopupButtonCell class]]) {
		MBPopupButtonCell *popupCell = (MBPopupButtonCell *)selectedCell;

		NSMenu *menu = selectedCell.menu;
		for (NSMenuItem *item in menu.itemArray) {
			item.action = @selector(cellPopupMenuItemSelected:);
			item.target = self;
		}

		[popupCell selectItemAtIndex:[currentValue integerValue]];
		[selectedCell.menu popUpMenuPositioningItem:nil atLocation:cellFrame.origin inView:self];
		
	} else {
		NSText *editor = [[self window] fieldEditor:YES forObject:self];
		editor.delegate = self;
		[selectedCell editWithFrame:cellFrame inView:self editor:editor delegate:self event:nil];
		editor.string = currentValue;
	}
}

- (void)cellPopupMenuItemSelected:(NSMenuItem *)menuItem {
	MBPopupButtonCell *cell = (MBPopupButtonCell *)[[self tableGrid] _cellForColumn:editedColumn];
	[cell selectItem:menuItem];

	[[self tableGrid] _setObjectValue:menuItem.title forColumn:editedColumn row:editedRow];
	
	editedColumn = NSNotFound;
	editedRow = NSNotFound;
}

#pragma mark Layout Support

- (NSRect)rectOfColumn:(NSUInteger)columnIndex
{
	NSRect rect = NSZeroRect;
	BOOL foundRect = NO;
	if (columnIndex < [self tableGrid].numberOfColumns) {
		NSValue *cachedRectValue = [self tableGrid].columnRects[@(columnIndex)];
		if (cachedRectValue) {
			rect = [cachedRectValue rectValue];
			foundRect = YES;
		}
	}
	
	if (!foundRect) {
		float width = [[self tableGrid] _widthForColumn:columnIndex];
		
		rect = NSMakeRect(0, 0, width, [self frame].size.height);
		//rect.origin.x += 60.0 * columnIndex;
		
		NSUInteger i = 0;
		while(i < columnIndex) {
			float headerWidth = [[self tableGrid] _widthForColumn:i];
			rect.origin.x += headerWidth;
			i++;
		}
	
		[self tableGrid].columnRects[@(columnIndex)] = [NSValue valueWithRect:rect];

	}
	return rect;
}

- (NSRect)rectOfRow:(NSUInteger)rowIndex
{
    
	float heightForRow = 20.0;
	NSRect rect = NSMakeRect(0, 0, [self frame].size.width, heightForRow);
	
	rect.origin.y += 20.0 * rowIndex;
	
	/*NSUInteger i = 0;
	while(i < rowIndex) {
		float rowHeight = rect.size.height;
		rect.origin.y += rowHeight;
		i++;
	}*/
	
	return rect;
}

- (NSRect)frameOfCellAtColumn:(NSUInteger)columnIndex row:(NSUInteger)rowIndex
{
	NSRect columnRect = [self rectOfColumn:columnIndex];
	NSRect rowRect = [self rectOfRow:rowIndex];
	return NSMakeRect(columnRect.origin.x, rowRect.origin.y, columnRect.size.width, rowRect.size.height);
}

- (NSInteger)columnAtPoint:(NSPoint)aPoint
{
	NSInteger column = 0;
	while(column < [self tableGrid].numberOfColumns) {
		NSRect columnFrame = [self rectOfColumn:column];
		if(NSPointInRect(aPoint, columnFrame)) {
			return column;
		}
		column++;
	}
	return NSNotFound;
}

- (NSInteger)rowAtPoint:(NSPoint)aPoint
{
	NSInteger row = 0;
	while(row < [self tableGrid].numberOfRows) {
		NSRect rowFrame = [self rectOfRow:row];
		if(NSPointInRect(aPoint, rowFrame)) {
			return row;
		}
		row++;
	}
	return NSNotFound;
}

@end

@implementation MBTableGridContentView (Cursors)

- (NSCursor *)_cellSelectionCursor
{
	NSCursor *cursor = [[NSCursor alloc] initWithImage:cursorImage hotSpot:NSMakePoint(8, 8)];
	return cursor;
}

/**
 * @warning		This method is not as efficient as it could be, but
 *				it should only be called once, at initialization.
 *				TODO: Make it faster
 */
- (NSImage *)_cellSelectionCursorImage
{
	NSImage *image = [[NSImage alloc] initWithSize:NSMakeSize(20, 20)];
	[image lockFocusFlipped:YES];
	
	NSRect horizontalInner = NSMakeRect(7.0, 2.0, 2.0, 12.0);
	NSRect verticalInner = NSMakeRect(2.0, 7.0, 12.0, 2.0);
	
	NSRect horizontalOuter = NSInsetRect(horizontalInner, -1.0, -1.0);
	NSRect verticalOuter = NSInsetRect(verticalInner, -1.0, -1.0);
	
	// Set the shadow
	NSShadow *shadow = [[NSShadow alloc] init];
	[shadow setShadowColor:[NSColor colorWithDeviceWhite:0.0 alpha:0.8]];
	[shadow setShadowBlurRadius:2.0];
	[shadow setShadowOffset:NSMakeSize(0, -1.0)];
	
	[[NSGraphicsContext currentContext] saveGraphicsState];
	
	[shadow set];
	
	[[NSColor blackColor] set];
	NSRectFill(horizontalOuter);
	NSRectFill(verticalOuter);
	
	[[NSGraphicsContext currentContext] restoreGraphicsState];
	
	// Fill them again to compensate for the shadows
	NSRectFill(horizontalOuter);
	NSRectFill(verticalOuter);
	
	[[NSColor whiteColor] set];
	NSRectFill(horizontalInner);
	NSRectFill(verticalInner);
	
	[image unlockFocus];
	
	return image;
}

- (NSCursor *)_cellExtendSelectionCursor
{
	NSCursor *cursor = [[NSCursor alloc] initWithImage:cursorExtendSelectionImage hotSpot:NSMakePoint(8, 8)];
	return cursor;
}

/**
 * @warning		This method is not as efficient as it could be, but
 *				it should only be called once, at initialization.
 *				TODO: Make it faster
 */
- (NSImage *)_cellExtendSelectionCursorImage
{
	NSImage *image = [[NSImage alloc] initWithSize:NSMakeSize(20, 20)];
	[image lockFocusFlipped:YES];
	
	NSRect horizontalInner = NSMakeRect(7.0, 1.0, 1.0, 12.0);
	NSRect verticalInner = NSMakeRect(1.0, 6.0, 12.0, 1.0);
	
	NSRect horizontalOuter = NSInsetRect(horizontalInner, -1.0, -1.0);
	NSRect verticalOuter = NSInsetRect(verticalInner, -1.0, -1.0);
	
	// Set the shadow
	NSShadow *shadow = [[NSShadow alloc] init];
	[shadow setShadowColor:[NSColor colorWithDeviceWhite:0.0 alpha:0.8]];
	[shadow setShadowBlurRadius:1.0];
	[shadow setShadowOffset:NSMakeSize(0, -1.0)];
	
	[[NSGraphicsContext currentContext] saveGraphicsState];
	
	[shadow set];
	
	[[NSColor whiteColor] set];
	NSRectFill(horizontalOuter);
	NSRectFill(verticalOuter);
	
	[[NSGraphicsContext currentContext] restoreGraphicsState];
	
	// Fill them again to compensate for the shadows
	NSRectFill(horizontalOuter);
	NSRectFill(verticalOuter);
	
	[[NSColor blackColor] set];
	NSRectFill(horizontalInner);
	NSRectFill(verticalInner);
	
	[image unlockFocus];
	
	return image;
}

@end

@implementation MBTableGridContentView (DragAndDrop)

- (void)_setDraggingColumnOrRow:(BOOL)flag
{
	isDraggingColumnOrRow = flag;
}

- (void)_setDropColumn:(NSInteger)columnIndex
{
	dropColumn = columnIndex;
	[self setNeedsDisplay:YES];
}

- (void)_setDropRow:(NSInteger)rowIndex
{
	dropRow = rowIndex;
	[self setNeedsDisplay:YES];
}

- (void)_timerAutoscrollCallback:(NSTimer *)aTimer
{
	NSEvent* event = [NSApp currentEvent];
    if ([event type] == NSLeftMouseDragged )
        [self autoscroll:event];
}

@end
