#import "MGTransparentWindow.h"

@implementation MGTransparentWindow


// Designated initializer.
- (id)initWithContentRect:(NSRect)contentRect 
                styleMask:(NSUInteger)aStyle 
                  backing:(NSBackingStoreType)bufferingType 
                    defer:(BOOL)flag {
    
    if (self = [super initWithContentRect:contentRect 
                                        styleMask:NSBorderlessWindowMask 
                                          backing:NSBackingStoreBuffered 
                                   defer:NO]) {
        
        [self setBackgroundColor:[NSColor clearColor]];
        [self setAlphaValue:1.0];
        [self setOpaque:NO];
        [self setHasShadow:NO];
    [self setReleasedWhenClosed:YES];
    [self setHidesOnDeactivate:NO];
    [self setCanHide:NO];
    [self setIgnoresMouseEvents:YES];
    }
    
    return self;
}


// Convenience constructor.
+ (MGTransparentWindow *)windowWithFrame:(NSRect)frame
{
	MGTransparentWindow *window = [[self alloc] 
								   initWithContentRect:frame 
								   styleMask:NSBorderlessWindowMask 
								   backing:NSBackingStoreBuffered 
								   defer:NO];
	return [window autorelease];
}


- (BOOL)canBecomeKeyWindow
{
    return YES;
}

- (BOOL)canBecomeMainWindow
{
	return NO;
}


- (void)keyDown:(NSEvent *)event
{
	if( [[self delegate] respondsToSelector:@selector(keyDown:)] )
		[[self delegate] performSelector:@selector(keyDown:) withObject:event];
}


@end
