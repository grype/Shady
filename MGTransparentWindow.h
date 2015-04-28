#import <Cocoa/Cocoa.h>

@interface MGTransparentWindow : NSWindow
{
   
}

+ (MGTransparentWindow *)windowWithFrame:(NSRect)frame;

@property (assign, nonatomic) float opacity;
- (void)setOpacity:(float)opacity duration:(NSTimeInterval)duration;

@end
