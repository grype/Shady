//
//  ShadyAppDelegate.m
//  Shady
//
//  Created by Matt Gemmell on 02/11/2009.
//

#import "MGTransparentWindow.h"
#import "NSApplication+DockIcon.h"
#import "ShadyAppDelegate.h"
#import <QuartzCore/QuartzCore.h>
#import <CoreFoundation/CoreFoundation.h>
#import <IOKit/IOKitLib.h>
#import <mach/mach.h>

#define OPACITY_UNIT				0.05; // "20 shades ought to be enough for _anybody_."
#define DEFAULT_OPACITY				0.4

#define STATE_MENU					NSLocalizedString(@"Turn Shady Off", nil) // global status menu-item title when enabled
#define STATE_MENU_OFF				NSLocalizedString(@"Turn Shady On", nil) // global status menu-item title when disabled

#define HELP_TEXT					NSLocalizedString(@"When Shady is frontmost:\rPress Up/Down to alter shade,\ror press Q to Quit.", nil)
#define HELP_TEXT_OFF				NSLocalizedString(@"Shady is Off.\rPress S to turn Shady on,\ror press Q to Quit.", nil)

#define STATUS_MENU_ICON			[NSImage imageNamed:@"Shady_Menu_Dark"]
#define STATUS_MENU_ICON_ALT		[NSImage imageNamed:@"Shady_Menu_Light"]
#define STATUS_MENU_ICON_OFF		[NSImage imageNamed:@"Shady_Menu_Dark_Off"]
#define STATUS_MENU_ICON_OFF_ALT	[NSImage imageNamed:@"Shady_Menu_Light_Off"]

#define MAX_OPACITY					0.90 // the darkest the screen can be, where 1.0 is pure black.
#define KEY_OPACITY_OFFSET  @"ShadeSavedUserOpacityKey" // name of user opacity setting.
#define KEY_OPACITY					@"ShadySavedOpacityKey" // name of the saved opacity setting.
#define KEY_DOCKICON				@"ShadySavedDockIconKey" // name of the saved dock icon state setting.
#define KEY_ENABLED					@"ShadySavedEnabledKey" // name of the saved primary state setting.
#define KEY_AUTOBRIGHTNESS  @"ShadySavedAutoBrightnessKey"  // name of the saved auto-brightness setting.

#define MAX_LMU_VALUE           67092480  // ambient light sensor's max value
#define AUTOBRIGHTNESS_INTERVAL 2.0 // timer interval (in seconds) for LMU query to automatically adjust brightness

@implementation ShadyAppDelegate {
  NSTimer *_autoBrightnessTimer;
  io_connect_t _dataPort;
  BOOL _autoBrightnessEnabled;
  float _lastKnownLMUValue;
}

@synthesize opacity;
@synthesize opacityOffset;
@synthesize statusMenu;
@synthesize opacitySlider;
@synthesize prefsWindow;
@synthesize dockIconCheckbox;
@synthesize stateMenuItemMainMenu;
@synthesize stateMenuItemStatusBar;
@synthesize autoBrightness;

#pragma mark Setup and Tear-down


- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	// Set the default opacity value and load any saved settings.
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  [defaults registerDefaults:[NSDictionary dictionaryWithObjectsAndKeys:
                              [NSNumber numberWithFloat:DEFAULT_OPACITY], KEY_OPACITY,
                              [NSNumber numberWithFloat:0.], KEY_OPACITY_OFFSET,
                              [NSNumber numberWithBool:YES], KEY_DOCKICON,
                              [NSNumber numberWithBool:YES], KEY_ENABLED,
                              [NSNumber numberWithBool:NO], KEY_AUTOBRIGHTNESS,
                              nil]];
	
	// Set up Dock icon.
	BOOL showsDockIcon = [defaults boolForKey:KEY_DOCKICON];
	[dockIconCheckbox setState:(showsDockIcon) ? NSOnState : NSOffState];
	if (showsDockIcon) {
		// Only set it here if it's YES, since we've just read a saved default and we always start with no Dock icon.
		[NSApp setShowsDockIcon:showsDockIcon];
	}
  
  // Set up Auto Brightness
  BOOL isAutoBrightnessEnabled = [defaults boolForKey:KEY_AUTOBRIGHTNESS];
  [autoBrightness setState:(isAutoBrightnessEnabled) ? NSOnState : NSOffState];
  if (isAutoBrightnessEnabled) {
    [self setAutoBrightnessEnabled:isAutoBrightnessEnabled];
  }
	
	// Activate statusItem.
	NSStatusBar *bar = [NSStatusBar systemStatusBar];
	statusItem = [bar statusItemWithLength:NSSquareStatusItemLength];
	[statusItem retain];
	
	NSImage* image = STATUS_MENU_ICON;
	[image setTemplate:YES];
	[statusItem setImage:image];
	
	NSImage* altImage = STATUS_MENU_ICON_ALT;
	[altImage setTemplate:YES];
	[statusItem setAlternateImage:altImage];
	[statusItem setHighlightMode:YES];
	[opacitySlider setFloatValue:(1.0 - opacity)];
	[statusItem setMenu:statusMenu];
	
	// Set appropriate initial display state.
	shadyEnabled = [defaults boolForKey:KEY_ENABLED];
	
	// Only show help text when activated _after_ we've launched and hidden ourselves.
	showsHelpWhenActive = NO;
	
	// Create transparent windows
	[self loadWindows];
	
	// Put this app into the background (the shade won't hide due to how its window is set up above).
	[NSApp hide:self];
}


- (void)dealloc
{
	if (statusItem) {
		[[NSStatusBar systemStatusBar] removeStatusItem:statusItem];
		[statusItem release];
		statusItem = nil;
	}
	[helpWindow.parentWindow removeChildWindow:helpWindow];
	
	[helpWindow close];
	[windows makeObjectsPerformSelector:@selector(close)];
	
	windows = nil; // released when closed.
	helpWindow = nil; // released when closed.
  
  [self setAutoBrightnessEnabled:NO];
	
	[super dealloc];
}

- (void)loadWindows
{
	NSMutableArray* array = [[NSMutableArray alloc] init];
	for( NSScreen* screen in [NSScreen screens] )
	{
		MGTransparentWindow* window;
		window = [[MGTransparentWindow windowWithFrame:screen.frame] retain];
		
		// Configure window.
		if( NSFoundationVersionNumber10_6 <= NSFoundationVersionNumber )
			[window setCollectionBehavior:NSWindowCollectionBehaviorCanJoinAllSpaces | NSWindowCollectionBehaviorStationary];
		else
			[window setCollectionBehavior:NSWindowCollectionBehaviorCanJoinAllSpaces];
		[window setIgnoresMouseEvents:YES];
		[window setLevel:NSScreenSaverWindowLevel];
		[window setDelegate:self];
		
		// Configure contentView.
		NSView *contentView = [window contentView];
		[contentView setWantsLayer:YES];
		CALayer *layer = [contentView layer];
		layer.backgroundColor = CGColorGetConstantColor(kCGColorBlack);
		layer.opacity = 0;
		[window makeFirstResponder:contentView];
		
		[array addObject: window];
	}
	
	[windows release];
	windows = array;
	
	[self updateEnabledStatus];
	self.opacity = [[NSUserDefaults standardUserDefaults] floatForKey:KEY_OPACITY];
  self.opacityOffset = [[NSUserDefaults standardUserDefaults] floatForKey:KEY_OPACITY_OFFSET];
	
	// Put window on screen.
	[windows makeObjectsPerformSelector:@selector(makeKeyAndOrderFront:) withObject:self];
	
}

#pragma mark Notifications handlers


- (void)applicationDidBecomeActive:(NSNotification *)aNotification
{
	[self applicationActiveStateChanged:aNotification];
}


- (void)applicationDidResignActive:(NSNotification *)aNotification
{
	[self applicationActiveStateChanged:aNotification];
}


- (void)applicationActiveStateChanged:(NSNotification *)aNotification
{
	BOOL appActive = [NSApp isActive];
	if (appActive) {
		// Give the window a kick into focus, so we still get key-presses.
		[windows makeObjectsPerformSelector:@selector(makeKeyAndOrderFront:) withObject:self];
	}
	
	if (!showsHelpWhenActive && !appActive) {
		// Enable help text display when active from now on.
		showsHelpWhenActive = YES;
		
	} else if (showsHelpWhenActive) {
		[self toggleHelpDisplay];
	}
}

- (void)applicationDidChangeScreenParameters:(NSNotification *)aNotification
{
	[windows[0] removeChildWindow:helpWindow];
	
	[helpWindow close];
	[windows makeObjectsPerformSelector:@selector(close)];
	
	[windows release];
	windows = nil; // released when closed.
	helpWindow = nil; // released when closed.
	
	
	[self loadWindows];
}

#pragma mark IBActions


- (IBAction)showAbout:(id)sender
{
	// We wrap this for the statusItem to ensure Shady comes to the front first.
	[NSApp activateIgnoringOtherApps:YES];
	[NSApp orderFrontStandardAboutPanel:self];
}


- (IBAction)showPreferences:(id)sender
{
	[NSApp activateIgnoringOtherApps:YES];
	[prefsWindow makeKeyAndOrderFront:self];
}


- (IBAction)increaseOpacity:(id)sender
{
	// i.e. make screen darker by making our mask less transparent.
	if (shadyEnabled) {
		self.opacity = opacity + OPACITY_UNIT;
	} else {
		NSBeep();
	}
}


- (IBAction)decreaseOpacity:(id)sender
{
	// i.e. make screen lighter by making our mask more transparent.
	if (shadyEnabled) {
		self.opacity = opacity - OPACITY_UNIT;
	} else {
		NSBeep();
	}
}


- (IBAction)opacitySliderChanged:(id)sender
{
  float sliderValue = [sender floatValue];
  self.opacityOffset += (1.0 - self.opacity) - sliderValue;
	self.opacity = (1.0 - sliderValue);
}


- (IBAction)toggleDockIcon:(id)sender
{
	BOOL showsDockIcon = ([sender state] != NSOffState);
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	[defaults setBool:showsDockIcon forKey:KEY_DOCKICON];
	[defaults synchronize];
	[NSApp setShowsDockIcon:showsDockIcon];
}


- (IBAction)toggleEnabledStatus:(id)sender
{
	shadyEnabled = !shadyEnabled;
	[self updateEnabledStatus];
}

- (IBAction)toggleAutoBrightness:(id)sender {
  BOOL enabled = [sender state] != NSOffState;
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  [defaults setBool:enabled forKey:KEY_AUTOBRIGHTNESS];
  [defaults synchronize];
  [self setAutoBrightnessEnabled:enabled];
}


- (void)keyDown:(NSEvent *)event
{
	if ( [windows containsObject:[event window]]) {
		unsigned short keyCode = [event keyCode];
		if (keyCode == 12 || keyCode == 53) { // q || Esc
			[NSApp terminate:self];
			
		} else if (keyCode == 126) { // up-arrow
			[self decreaseOpacity:self];
			
		} else if (keyCode == 125) { // down-arrow
			[self increaseOpacity:self];
			
		} else if (keyCode == 1) { // s
			[self toggleEnabledStatus:self];
			
		} else if (keyCode == 43) { // ,
			[self showPreferences:self];
			
		} else {
			//NSLog(@"keyCode: %d", keyCode);
		}
	}
}


#pragma mark Helper methods


- (void)toggleHelpDisplay
{
	if( windows.count == 0 )	return; // Unknown error
	
	if (!helpWindow) {
		// Create helpWindow.
		NSRect mainFrame = [windows[0] frame];
		NSRect helpFrame = NSZeroRect;
		float width = 600;
		float height = 200;
		helpFrame.origin.x = (mainFrame.size.width - width) / 2.0;
		helpFrame.origin.y = 200.0;
		helpFrame.size.width = width;
		helpFrame.size.height = height;
		helpWindow = [[MGTransparentWindow windowWithFrame:helpFrame] retain];
		
		// Configure window.
		[helpWindow setCollectionBehavior:NSWindowCollectionBehaviorCanJoinAllSpaces];
		
		// Configure contentView.
		NSView *contentView = [helpWindow contentView];
		[contentView setWantsLayer:YES];
		CATextLayer *layer = [CATextLayer layer];
		layer.opacity = 0;
		[contentView setLayer:layer];
		CGColorRef bgColor = CGColorCreateGenericGray(0.0, 0.6);
		layer.backgroundColor = bgColor;
		CGColorRelease(bgColor);
		layer.string = (shadyEnabled) ? HELP_TEXT : HELP_TEXT_OFF;
		layer.contentsRect = CGRectMake(0, 0, 1, 1.2);
		layer.fontSize = 40.0;
		layer.foregroundColor = CGColorGetConstantColor(kCGColorWhite);
		layer.borderColor = CGColorGetConstantColor(kCGColorWhite);
		layer.borderWidth = 4.0;
		layer.cornerRadius = 15.0;
		layer.alignmentMode = kCAAlignmentCenter;
		
		[windows[0] addChildWindow:helpWindow ordered:NSWindowAbove];
	}
	
	if (showsHelpWhenActive) {
		float helpOpacity = (([NSApp isActive] ? 1 : 0));
		[[[helpWindow contentView] layer] setOpacity:helpOpacity];
	}
}


- (void)updateEnabledStatus
{
	// Save state.
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	[defaults setBool:shadyEnabled forKey:KEY_ENABLED];
	[defaults synchronize];
	
	// Show or hide the shade layer's view appropriately.
	for( NSWindow* window in windows )
		[[[window contentView] animator] setHidden:!shadyEnabled];
	
	// Modify help text shown when we're frontmost.
	if (helpWindow) {
		CATextLayer *helpLayer = (CATextLayer *)[[helpWindow contentView] layer];
		helpLayer.string = (shadyEnabled) ? HELP_TEXT : HELP_TEXT_OFF;
	}
	
	// Update both enable/disable menu-items (in the main menubar and in the NSStatusItem's menu).
	[stateMenuItemMainMenu setTitle:(shadyEnabled) ? STATE_MENU : STATE_MENU_OFF];
	[stateMenuItemStatusBar setTitle:(shadyEnabled) ? STATE_MENU : STATE_MENU_OFF];
	
	// Update status item's regular and alt/selected images.
	
	NSImage* image = (shadyEnabled) ? STATUS_MENU_ICON : STATUS_MENU_ICON_OFF;
	[image setTemplate:YES];

	NSImage* altImage = (shadyEnabled) ? STATUS_MENU_ICON_ALT : STATUS_MENU_ICON_OFF_ALT;
	[altImage setTemplate:YES];

	
	[statusItem setImage:image];
	[statusItem setAlternateImage:altImage];
	
	// Enable/disable slider.
	[opacitySlider setEnabled:shadyEnabled];
  
  if (!shadyEnabled) {
    [self setAutoBrightnessEnabled:NO];
  }
  else {
    [self setAutoBrightnessEnabled:[defaults boolForKey:KEY_AUTOBRIGHTNESS]];
  }
}

#pragma mark Auto Brightness
- (void)setAutoBrightnessEnabled:(BOOL)enabled
{
  if (enabled == _autoBrightnessEnabled) {
    return;
  }
  
  _autoBrightnessEnabled = enabled;
  
  if (enabled) {
    kern_return_t kr;
    
    io_service_t serviceObject = IOServiceGetMatchingService(kIOMasterPortDefault,
                                                             IOServiceMatching("AppleLMUController"));
    if (!serviceObject) {
      NSLog(@"failed to find ambient light sensor");
      return;
    }
    
    kr = IOServiceOpen(serviceObject, mach_task_self(), 0, &_dataPort);
    IOObjectRelease(serviceObject);
    if (kr != KERN_SUCCESS) {
      NSLog(@"IOServiceOpen: %i", kr);
      return; 
    }
    
    _autoBrightnessTimer = [NSTimer timerWithTimeInterval:AUTOBRIGHTNESS_INTERVAL
                                                   target:self
                                                 selector:@selector(updateBrightnessFromLMU)
                                                 userInfo:nil
                                                  repeats:YES];
    [[NSRunLoop mainRunLoop] addTimer:_autoBrightnessTimer
                              forMode:NSDefaultRunLoopMode];
  }
  else {
    if (_dataPort) {
      IOServiceClose(&_dataPort);
      IOObjectRelease(_dataPort);
      _dataPort = 0;
    }
    if (_autoBrightnessTimer != nil) {
      [_autoBrightnessTimer invalidate];
    }
    _autoBrightnessTimer = nil;
  }
}

- (BOOL)isAutoBrightnessEnabled
{
  return [[NSUserDefaults standardUserDefaults] boolForKey:KEY_AUTOBRIGHTNESS];
}

- (void)updateBrightnessFromLMU
{
  float currentLMUValue = [self currentLMUValue];
  if (currentLMUValue == NSNotFound
      || _lastKnownLMUValue == currentLMUValue) {
    return;
  }
  
  NSScreen *nativeScreen = [[NSScreen screens] firstObject];
  NSMutableArray *targetWindows = [NSMutableArray array];
  for (NSWindow *window in windows) {
    if (window.screen == nativeScreen) {
      continue;
    }
    [targetWindows addObject:window];
  }
  
  float newOpacity = 1.0 - (log(MAX(1., currentLMUValue)) / log(MAX_LMU_VALUE));
  newOpacity = MIN(MAX_OPACITY, ((roundf(newOpacity * 100.)/100.) + self.opacityOffset));
//  NSLog(@"LMU: %f; opacity: %f; offset: %f", currentLMUValue, newOpacity, self.opacityOffset);
  
  _lastKnownLMUValue = currentLMUValue;
  
  [self setOpacity:newOpacity onWindows:targetWindows withDuration:1.33];
}

- (float) currentLMUValue {
  uint32_t outputs = 2;
  uint64_t values[outputs];
  
  kern_return_t kr = IOConnectCallMethod(_dataPort, 0, nil, 0, nil, 0, values, &outputs, nil, 0);
  uint64_t left = values[0];
  uint64_t right = values[1];
  
  if (kr == KERN_SUCCESS) {
    return (left + right)/2.;
  }
  
  if (kr != kIOReturnBusy) {
    NSLog(@"I/O Kit error: %i", kr);
  }
  
  return NSNotFound;
}

#pragma mark Accessors

- (void)setOpacity:(float)newOpacity
         onScreens:(NSArray *)screens
      withDuration:(NSTimeInterval)duration
{
  if (screens == nil) {
    screens = @[[NSScreen mainScreen]];
  }
  NSMutableArray *targetWindows = [NSMutableArray array];
  for (MGTransparentWindow *window in windows) {
    for (NSScreen *screen in screens) {
      if (window.screen == screen) {
        [targetWindows addObject:window];
        break;
      }
    }
  }
  [self setOpacity:newOpacity onWindows:targetWindows withDuration:duration];
}

- (void)setOpacity:(float)newOpacity
         onWindows:(NSArray *)targetWindows
      withDuration:(NSTimeInterval)duration
{
  float normalisedOpacity = MIN(MAX_OPACITY, MAX(newOpacity, 0.0));
  if (normalisedOpacity != opacity) {
    opacity = normalisedOpacity;
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setFloat:opacity forKey:KEY_OPACITY];
    [defaults synchronize];
  }
  
  if (targetWindows == nil) {
    targetWindows = windows;
  }
  
  for(MGTransparentWindow* window in targetWindows) {
    [window setOpacity:newOpacity duration:duration];
  }
  
  [opacitySlider setFloatValue:(1.0 - opacity)];
}

- (void)setOpacity:(float)newOpacity
{
  [self setOpacity:newOpacity
         onScreens:nil
      withDuration:0.];
}

-(float)opacity
{
	return opacity;
}

@end
