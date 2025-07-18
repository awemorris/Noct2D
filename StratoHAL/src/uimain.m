/* -*- coding: utf-8; tab-width: 4; indent-tabs-mode: nil; -*- */

/*
 * Copyright (c) 2025, Awe Morris. All rights reserved.
 */

//
// iOS Main
//

@import UIKit;
#import <AVFoundation/AVFoundation.h>

#import "stratohal/platform.h"
#import "stdfile.h"
#import "uimain.h"
#import "aunit.h"
#import "GameRenderer.h"
#import "GameViewControllerProtocol.h"

#import <sys/time.h>

// Window title.
char *window_title;

// Window size.
int screen_width;
int screen_height;

// View controller.
static ViewController *theViewController;

// Swipe mode.
static BOOL isContinuousSwipeEnabled;

//
// Main
//

int main2(int argc, char * argv[]) {
    NSString * appDelegateClassName;
    @autoreleasepool {
        // Setup code that might create autoreleased objects goes here.
        appDelegateClassName = NSStringFromClass([AppDelegate class]);
    }
    setlocale(LC_NUMERIC, "C");
    return UIApplicationMain(argc, argv, nil, appDelegateClassName);
}

//
// AppDelegate
//

@interface AppDelegate ()
@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // Override point for customization after application launch.
    return YES;
}

#pragma mark - UISceneSession lifecycle

- (UISceneConfiguration *)application:(UIApplication *)application configurationForConnectingSceneSession:(UISceneSession *)connectingSceneSession options:(UISceneConnectionOptions *)options {
    // Called when a new scene session is being created.
    // Use this method to select a configuration to create the new scene with.
    return [[UISceneConfiguration alloc] initWithName:@"Default Configuration" sessionRole:connectingSceneSession.role];
}

- (void)application:(UIApplication *)application didDiscardSceneSessions:(NSSet<UISceneSession *> *)sceneSessions {
    // Called when the user discards a scene session.
    // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
    // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
}

@end

//
// ViewController
//

@interface ViewController ()
@end

@implementation ViewController
{
    // The GameView for AppKit
    GameView *_view;

    // The GameRender (common for AppKit and UIKit)
    GameRenderer *_renderer;

    // The screen information
    float _screenScale;
    CGSize _screenSize;
    CGPoint _screenOffset;

    // The video player objects and status.
    AVPlayer *_avPlayer;
    AVPlayerLayer *_avPlayerLayer;
    BOOL _isVideoPlaying;
}

// Called when the view is loaded.
- (void)viewDidLoad {
    [super viewDidLoad];

    // Initialize the file HAL.
    if(!init_file())
        exit(1);

    // Do a boot callback to acquire a screen configuration.
    if (!on_event_boot(&window_title, &screen_width, &screen_height))
        exit(1);

    // Initialize the sound HAL.
    if(!init_aunit())
        exit(1);
    
    // Create an MTKView.
    _view = (GameView *)self.view;
    _view.enableSetNeedsDisplay = YES;
    _view.device = MTLCreateSystemDefaultDevice();
    _view.clearColor = MTLClearColorMake(0.0, 0, 0, 1.0);
    _renderer = [[GameRenderer alloc] initWithMetalKitView:_view andController:self];
    if(!_renderer) {
        NSLog(@"Renderer initialization failed");
        return;
    }
    [_renderer mtkView:_view drawableSizeWillChange:_view.drawableSize];
    _view.delegate = _renderer;
    [self updateViewport:_view.frame.size];

    // Set multi-touch.
    self.view.multipleTouchEnabled = YES;

    // Setup a rendering timer.
    [NSTimer scheduledTimerWithTimeInterval:1.0/60.0
                                     target:self
                                   selector:@selector(timerFired:)
                                   userInfo:nil
                                    repeats:YES];

    // Do a start callback.
    if(!on_event_start())
        exit(1);
}

// Calculate the viewport size.
- (void)updateViewport:(CGSize)newViewSize {
    // If called before the view initialization.
    if (newViewSize.width == 0 || newViewSize.height == 0)
        return;

    // Get the aspect ratio of the game.
    float aspect = (float)screen_height / (float)screen_width;

    // 1. Use width-first.
    _screenSize.width = newViewSize.width;
    _screenSize.height = _screenSize.width * aspect;
    _screenScale = (float)screen_width / (float)_screenSize.width;
    
    // 2. If the height is not enough, use height-first.
    if(_screenSize.height > newViewSize.height) {
        _screenSize.height = newViewSize.height;
        _screenSize.width = _screenSize.height / aspect;
        _screenScale = (float)screen_height / (float)_screenSize.height;
    }
    
    // Calculate the scale factor and the margin for touch position.
    _view.left = (float)(newViewSize.width - _screenSize.width) / 2.0f;
    _view.top = (float)(newViewSize.height - _screenSize.height) / 2.0f;
    _view.scale = _screenScale;

    // Multiply the scale factor of MTKView.
    _screenScale *= (float)_view.layer.contentsScale;
    _screenSize.width *= _view.layer.contentsScale;
    _screenSize.height *= _view.layer.contentsScale;
    _screenOffset.x = _view.left * _view.layer.contentsScale;
    _screenOffset.y = _view.top * _view.layer.contentsScale;
}

// Called when the view appeared.
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self updateViewport:_view.frame.size];
}

// Called every frame.
- (void)timerFired:(NSTimer *)timer {
    [_view setNeedsDisplay];
}

// Get the screen scale.
- (float)screenScale {
    return _screenScale;
}

// Get the screen offset.
- (CGPoint)screenOffset {
    return _screenOffset;
}

// Get the screen size.
- (CGSize)screenSize {
    return _screenSize;
}

// Check whether we are playing back a video.
- (BOOL)isVideoPlaying {
    return _isVideoPlaying;
}

// Play a video.
- (void)playVideoWithPath:(NSString *)path skippable:(BOOL)isSkippable {
    // Create a player.
    AVPlayerItem *playerItem = [[AVPlayerItem alloc] initWithURL:[NSURL fileURLWithPath:path]];
    _avPlayer = [[AVPlayer alloc] initWithPlayerItem:playerItem];

    // Create a layer for the player.
    _avPlayerLayer = [AVPlayerLayer playerLayerWithPlayer:_avPlayer];
    [_avPlayerLayer setFrame:self.view.bounds];
    [self.view.layer addSublayer:_avPlayerLayer];

    // Set the finish notification.
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(onPlayEnd:)
                                               name:AVPlayerItemDidPlayToEndTimeNotification
                                             object:playerItem];

    // Start playing.
    [_avPlayer play];

    _isVideoPlaying = YES;
}

// Called when a video playback is finished.
- (void)onPlayEnd:(NSNotification *)notification {
    [_avPlayer replaceCurrentItemWithPlayerItem:nil];
    _isVideoPlaying = NO;
}

// Stop a video playback.
- (void)stopVideo {
    if (_avPlayer != nil) {
        [_avPlayer replaceCurrentItemWithPlayerItem:nil];
        _isVideoPlaying = NO;
        _avPlayer = nil;
        _avPlayerLayer = nil;
    }
}

// Not used in the iOS app.
- (void)setWindowTitle:(NSString *)name {
}

// Not used in the iOS app.
- (void)enterFullScreen {
}

// Not used in the iOS app.
- (BOOL)isFullScreen { 
    return NO;
}

// Not used in the iOS app.
- (void)leaveFullScreen { 
}

// Not used in the iOS app.
- (CGPoint)windowPointToScreenPoint:(CGPoint)windowPoint { 
    return windowPoint;
}

@end

//
// GameView
//

@implementation GameView
{
    BOOL _isTouch;
    int _touchStartX;
    int _touchStartY;
    int _touchLastY;
}

// Called when touches began.
- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    _isTouch = YES;

    UITouch *touch = [[event allTouches] anyObject];
    CGPoint touchLocation = [touch locationInView:self];
    _touchStartX = (int)((touchLocation.x - self.left) * self.scale);
    _touchStartY = (int)((touchLocation.y - self.top) * self.scale);
    _touchLastY = _touchStartY;

    on_event_mouse_press(MOUSE_LEFT, _touchStartX, _touchStartY);
}

// Called when touched moved.
- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    UITouch *touch = [[event allTouches] anyObject];
    CGPoint touchLocation = [touch locationInView:self];
    int touchX = (int)((touchLocation.x - self.left) * self.scale);
    int touchY = (int)((touchLocation.y - self.top) * self.scale);

	// Emulate a wheel down.
	const int FLICK_Y_DISTANCE = 30;
	int deltaY = touchY - _touchLastY;
	_touchLastY = touchY;
    if (isContinuousSwipeEnabled) {
        if (deltaY > 0 && deltaY < FLICK_Y_DISTANCE) {
            on_event_key_press(KEY_DOWN);
            on_event_key_release(KEY_DOWN);
            return;
        }
    }

	// Emulate a mouse move.
    on_event_mouse_move((int)touchX, (int)touchY);
}

// Called when touches ended.
- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    _isTouch = NO;

    UITouch *touch = [[event allTouches] anyObject];
    CGPoint touchLocation = [touch locationInView:self];
    int touchEndX = (int)((touchLocation.x - self.left) * self.scale);
    int touchEndY = (int)((touchLocation.y - self.top) * self.scale);

    // Detect a down/up swipe.
	const int FLICK_Y_DISTANCE = 50;
	int deltaY = touchEndY - _touchStartY;
	if (deltaY > FLICK_Y_DISTANCE) {
        on_event_touch_cancel();
        on_event_swipe_down();
        return;
	} else if (deltaY < -FLICK_Y_DISTANCE) {
        on_event_touch_cancel();
        on_event_swipe_up();
        return;
    }

	// Emulate a left click.
	const int FINGER_DISTANCE = 10;
    if ([[event allTouches] count] == 1 &&
        abs(touchEndX - _touchStartX) < FINGER_DISTANCE &&
	    abs(touchEndY - _touchStartY) < FINGER_DISTANCE) {
        on_event_touch_cancel();
        on_event_mouse_press(MOUSE_LEFT, touchEndX, touchEndY);
        on_event_mouse_release(MOUSE_LEFT, touchEndX, touchEndY);
        return;
    }

    // Emulate a right click.
    if ([[event allTouches] count] == 2 &&
        abs(touchEndX - _touchStartX) < FINGER_DISTANCE &&
        abs(touchEndY - _touchStartY) < FINGER_DISTANCE) {
        on_event_touch_cancel();
        on_event_mouse_press(MOUSE_RIGHT, touchEndX, touchEndY);
        on_event_mouse_release(MOUSE_RIGHT, touchEndX, touchEndY);
        return;
    }

    // Cancel the touch move.
    on_event_touch_cancel();
}

@end

//
// HAL
//

// Show an INFO log.
bool log_info(const char *s, ...)
{
    char buf[1024];
    va_list ap;
    
    va_start(ap, s);
    vsnprintf(buf, sizeof(buf), s, ap);
    va_end(ap);

    NSLog(@"%s", buf);
    
    return true;
}

// Show a WARN log.
bool log_warn(const char *s, ...)
{
    char buf[1024];
    va_list ap;

    va_start(ap, s);
    vsnprintf(buf, sizeof(buf), s, ap);
    va_end(ap);

    NSLog(@"%s", buf);

    return true;
}

// Show an ERROR log.
bool log_error(const char *s, ...)
{
    char buf[1024];
    va_list ap;

    va_start(ap, s);
    vsnprintf(buf, sizeof(buf), s, ap);
    va_end(ap);

    NSLog(@"%s", buf);

    return true;
}

// Show an out-of-memory error.
bool log_out_of_memory(void)
{
    log_error("Out of memory.");

    return true;
}

// Make a save directory.
bool make_save_directory(void)
{
    @autoreleasepool {
        NSString *path = [NSString stringWithFormat:@"%@/%@/%s/sav",
                          NSHomeDirectory(),
                          @"/Library/Application Support",
                          window_title];
        NSFileManager *manager = [NSFileManager defaultManager];
        NSError *error;
        if(![manager createDirectoryAtPath:path
               withIntermediateDirectories:YES
                                attributes:nil
                                     error:&error]) {
            NSLog(@"createDirectoryAtPath error: %@", error);
            return false;
        }
        return true;
    }
}

// Get a real path for a file.
char *make_real_path(const char *fname)
{
    @autoreleasepool {
        // If a save file:
            if(strncmp(fname, "save/", 5) == 0) {
            // Return a "Application Support" path.
            NSString *path = [NSString stringWithFormat:@"%@/%@/%s/save/%s",
                              NSHomeDirectory(),
                              @"/Library/Application Support",
                              window_title,
                              fname];
            const char *cstr = [path UTF8String];
            return strdup(cstr);
        }

        // If an mp4 file:
        if(strncmp(fname, "mov/", 4) == 0) {
            // Return an bundle resource path.
            *strstr(fname, ".") = '\0';
            NSString *basename = [NSString stringWithFormat:@"mov/%s", fname];
            NSString *path = [[NSBundle mainBundle] pathForResource:basename ofType:@"mp4"];
            const char *cstr = [path UTF8String];
            return strdup(cstr);
        }

        // If the package:
        if(strcmp(fname, PACKAGE_FILE) == 0) {
            // Return a bundle resource path.
            NSString *path = [[NSBundle mainBundle] pathForResource:@"package" ofType:@"dat"];
            const char *cstr = [path UTF8String];
            return strdup(cstr);
        }

        // We cannot load other files.
        return strdup("dummy");
    }
}

// Reset a lap timer.
void reset_lap_timer(uint64_t *origin)
{
    struct timeval tv;

    gettimeofday(&tv, NULL);
    *origin = (uint64_t)(tv.tv_sec * 1000 + tv.tv_usec / 1000);
}

// Get a timer lap
uint64_t get_lap_timer_millisec(uint64_t *origin)
{
    struct timeval tv;
    uint64_t now;

    gettimeofday(&tv, NULL);
    now = (uint64_t)(tv.tv_sec * 1000 + tv.tv_usec / 1000);
    if (now < *origin) {
        reset_lap_timer(origin);
        return 0;
    }
    return (uint64_t)(now - *origin);
}

// Play a video.
bool play_video(const char *fname, bool is_skippable)
{
    // Make a path.
    char *cpath = make_real_path(fname);
    assert(cpath != NULL);
    NSString *path = [[NSString alloc] initWithUTF8String:cpath];
    free(cpath);
    path = [path stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLPathAllowedCharacterSet]];

    // Play a video.
    [theViewController playVideoWithPath:path skippable:is_skippable ? YES : NO];

    return true;
}

// Stop a video.
void stop_video(void)
{
    [theViewController stopVideo];
}

// Check if video is playing back.
//
bool is_video_playing(void)
{
    return [theViewController isVideoPlaying] ? true : false;
}

// Check if the full screen mode is supported.
bool is_full_screen_supported(void)
{
    return true;
}

// Check if operating in the full screen mode.
bool is_full_screen_mode(void)
{
    return [theViewController isFullScreen];
}

// Enter the full screen mode.
void enter_full_screen_mode(void)
{
    [theViewController enterFullScreen];
}

// Leave the full screen mode.
void leave_full_screen_mode(void)
{
    [theViewController leaveFullScreen];
}

// Get a system language.
const char *get_system_language(void)
{
    NSString *language = [[NSLocale preferredLanguages] objectAtIndex:0];
    if ([language hasPrefix:@"ja"])
        return "ja";
    if ([language hasPrefix:@"en"])
        return "en";
    if ([language hasPrefix:@"fr"])
        return "fr";
    if ([language hasPrefix:@"de"])
        return "de";
    if ([language hasPrefix:@"es"])
        return "es";
    if ([language hasPrefix:@"it"])
        return "it";
    if ([language hasPrefix:@"el"])
        return "el";
    if ([language hasPrefix:@"ru"])
        return "ru";
    if ([language hasPrefix:@"zh-Hans"])
        return "zh";
    if ([language hasPrefix:@"zh-Hant"])
        return "tw";
    return "other";
}

// Not used in macOS.
void set_continuous_swipe_enabled(bool is_enabled)
{
    isContinuousSwipeEnabled = is_enabled;
}
