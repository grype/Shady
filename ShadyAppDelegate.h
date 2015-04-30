//
//  ShadyAppDelegate.h
//  Shady
//
//  Created by Matt Gemmell on 02/11/2009.
//

#import <Cocoa/Cocoa.h>

@interface ShadyAppDelegate : NSObject <NSWindowDelegate> {
    NSArray *windows;
	float opacity;
	BOOL showsHelpWhenActive;
	NSWindow *helpWindow;
	NSMenu *statusMenu;
	NSSlider *opacitySlider;
	NSStatusItem *statusItem;
	NSPanel *prefsWindow;
	NSButton *dockIconCheckbox;
	NSMenuItem *stateMenuItemMainMenu;
	NSMenuItem *stateMenuItemStatusBar;
  NSButton *autoBrightness;
	BOOL shadyEnabled;
}

@property (assign) float opacity;
@property (assign) float opacityOffset;
@property (assign) IBOutlet NSMenu *statusMenu;
@property (assign) IBOutlet NSSlider *opacitySlider;
@property (assign) IBOutlet NSPanel *prefsWindow;
@property (assign) IBOutlet NSButton *dockIconCheckbox;
@property (assign) IBOutlet NSMenuItem *stateMenuItemMainMenu;
@property (assign) IBOutlet NSMenuItem *stateMenuItemStatusBar;
@property (assign) IBOutlet NSButton *autoBrightness;


- (IBAction)showAbout:(id)sender;
- (IBAction)showPreferences:(id)sender;
- (IBAction)toggleDockIcon:(id)sender;
- (IBAction)toggleEnabledStatus:(id)sender;
- (IBAction)toggleAutoBrightness:(id)sender;

- (IBAction)increaseOpacity:(id)sender;
- (IBAction)decreaseOpacity:(id)sender;
- (IBAction)opacitySliderChanged:(id)sender;

- (void)applicationActiveStateChanged:(NSNotification *)aNotification;
- (void)toggleHelpDisplay;
- (void)updateEnabledStatus;

@end
