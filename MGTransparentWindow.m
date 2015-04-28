#import "MGTransparentWindow.h"
#import <QuartzCore/QuartzCore.h>

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
  MGTransparentWindow *window = [[self alloc] initWithContentRect:frame
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


#pragma mark - Opacity
- (void)setOpacity:(float)opacity
{
  [self setOpacity:opacity duration:0.];
}

- (void)setOpacity:(float)opacity duration:(NSTimeInterval)duration
{
  CALayer *layer = [[self contentView] layer];
  float currentOpacity = [layer opacity];
  if (opacity == currentOpacity) {
    return;
  }
  if (duration > 0.) {
    CABasicAnimation *anim = [CABasicAnimation animationWithKeyPath:@"opacity"];
    anim.fromValue = @([layer opacity]);
    anim.toValue = @(opacity);
    anim.duration = duration;
    [layer removeAnimationForKey:@"opacity"];
    [layer addAnimation:anim forKey:@"opacity"];
  }
  else {
    [layer removeAnimationForKey:@"opacity"];
  }
  layer.opacity = opacity;
}

- (float)opacity
{
  return [[[self contentView] layer] opacity];
}



@end
