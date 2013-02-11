#import <UIKit/UIKit.h>

#include <stdlib.h>
#include <stdio.h>
#include <signal.h>
#include <time.h>

/** The limits of time separation durations between two swipes. */
static const NSTimeInterval kMinGapTime = 20.0;
static const NSTimeInterval kMaxGapTime = 120.0;

/**
 * The time interval where the run loop would be paused to check if SIGINT is
 * raised.
 */
static const NSTimeInterval kCheckRunLoopInterval = 8.0;

/**
 * The ratio of the bounding box against the whole screen which random swipes
 * will start and end.
 */
static const CGFloat kMinRatioX = 0.25f;
static const CGFloat kMaxRatioX = 0.75f;
static const CGFloat kMinRatioY = 0.25f;
static const CGFloat kMaxRatioY = 0.75f;

/** The minimum and maximum duration of a swipe. */
static const NSTimeInterval kMinDuration = 0.5;
static const NSTimeInterval kMaxDuration = 3.5;

/** Fetch a random time interval given the minimum and maximum. */
static inline NSTimeInterval randomIntervalBetween(NSTimeInterval min,
                                                   NSTimeInterval max) {
    return rand() * (max - min) / RAND_MAX + min;
}

/** Fetch a random float given the minimum and maximum. */
static inline CGPoint randomPointInside(const CGRect* rect) {
    CGFloat x = rand() * rect->size.width / RAND_MAX + rect->origin.x;
    CGFloat y = rand() * rect->size.height / RAND_MAX + rect->origin.y;
    return CGPointMake(x, y);
}

/** Just a protocol to avoid clang complaining. */
@protocol UIATarget
+(id<UIATarget>)localTarget;
-(NSValue*)rect;
-(void)dragFrom:(NSValue*)from to:(NSValue*)to forDuration:(NSNumber*)duration;
@end

@interface RSRunner : NSObject {
    NSTimer* _timer;
    id<UIATarget> _target;
    CGRect _boundingRect;
}
/** Uninstall the random swipe timer. */
-(void)uninstall;
/** Reinstall the random swipe timer. */
-(void)reinstall;
/** Perform a random swipe. */
-(void)performRandomSwipe;
/** Prepare to run the random swipe timer. */
-(BOOL)prepare;
/** Start running the random swipe timer. */
+(void)run;
@end

static RSRunner* gRunner = nil;

/**
 * The handler of SIGINT. This method will remove all timers from the current
 * run loop, thus making it stop running.
 */
static void interruptHandler(int signal) {
    RSRunner* runner = gRunner;
    gRunner = nil;
    // TODO: Not sure if it is async-safe to do these...
    printf("Received SIGINT! Quitting in %g seconds...\n", kCheckRunLoopInterval);
    [runner uninstall];
}

/** Install the SIGINT handler. */
static void installInterruptHandler() {
    printf("Starting to randomly swipe!\n"
           "Press Ctrl+C or type `kill -INT %d` to quit.\n", getpid());

    struct sigaction interruptAction;
    interruptAction.sa_handler = &interruptHandler;
    sigemptyset(&interruptAction.sa_mask);
    interruptAction.sa_flags = 0;
    sigaction(SIGINT, &interruptAction, NULL);
}


@implementation RSRunner

-(void)uninstall {
    if ([_timer isValid]) {
        [_timer invalidate];
        _timer = nil;
    }
}

-(void)reinstall {
    [self uninstall];
    [self performRandomSwipe];
    NSTimeInterval gapTime = randomIntervalBetween(kMinGapTime, kMaxGapTime);
    printf("Rescheduling timer after %g seconds...      \r", gapTime);
    fflush(stdout);
    _timer = [NSTimer scheduledTimerWithTimeInterval:gapTime target:self selector:_cmd userInfo:nil repeats:NO];
}

-(void)performRandomSwipe {
    NSTimeInterval duration = randomIntervalBetween(kMinDuration, kMaxDuration);
    CGPoint fromPoint = randomPointInside(&_boundingRect);
    CGPoint toPoint = randomPointInside(&_boundingRect);
    [_target dragFrom:[NSValue valueWithCGPoint:fromPoint]
                   to:[NSValue valueWithCGPoint:toPoint]
          forDuration:@(duration)];
}

-(BOOL)prepare {
    NSBundle* bundle = [NSBundle bundleWithPath:@"/Developer/Library/PrivateFrameworks/UIAutomation.framework"];
    if (bundle == nil) {
        printf("Cannot load UIAutomation framework!\n"
               "Please ensure this device already used for development.\n");
        return NO;
    }
    [bundle load];

    Class<UIATarget> cls = [bundle classNamed:@"UIATarget"];
    if (cls == nil) {
        printf("Cannot find UIATarget class!\n");
        return NO;
    }
    _target = [cls localTarget];
    NSValue* rectValue = [_target rect];
    CGRect rect = [rectValue CGRectValue];
    _boundingRect = CGRectMake(rect.size.width * kMinRatioX + rect.origin.x,
                               rect.size.height * kMinRatioY + rect.origin.y,
                               rect.size.width * (kMaxRatioX - kMinRatioX),
                               rect.size.height * (kMaxRatioY - kMinRatioY));
    return YES;
}

+(void)run {
    gRunner = [[RSRunner alloc] init];
    if (![gRunner prepare]) {
        return;
    }
    [gRunner reinstall];
    NSRunLoop* loop = [NSRunLoop currentRunLoop];
    while (gRunner != nil) {
        NSDate* nextCheckDate = [NSDate dateWithTimeIntervalSinceNow:kCheckRunLoopInterval];
        [loop runUntilDate:nextCheckDate];
    }
}
@end


int main() {
    installInterruptHandler();
    srand(time(NULL));

    @autoreleasepool {
        [RSRunner run];
    }

    printf("Done random swiping.\n");

    return 0;
}

/*-- GPLv3 ---------------------------------------------------------------------

RandomSwipe – Perform a swipe at some random interval
Copyright (C) 2013  kennytm

This program is free software: you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free Software
Foundation, either version 3 of the License, or (at your option) any later
version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with
this program.  If not, see <http://www.gnu.org/licenses/>.

*/

