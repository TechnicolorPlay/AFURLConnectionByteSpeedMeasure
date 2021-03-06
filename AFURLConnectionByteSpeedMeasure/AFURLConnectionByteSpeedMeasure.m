// AFURLConnectionByteSpeedMeasure.m
//
//  Created by Oliver Letterer on 27.01.13.
//  Copyright (c) 2013 Oliver Letterer. All rights reserved.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import "AFURLConnectionByteSpeedMeasure.h"
#import "AFURLConnectionOperation.h"

@interface AFURLConnectionByteSpeedMeasure () {
    NSMutableArray *_timesArray;
    NSMutableArray *_chunkLengthsArray;
    NSTimeInterval _lastSpeedCalculationTimeInterval;
}

@property (readwrite, nonatomic) double speed;
@property (readwrite, nonatomic, copy) NSString *humanReadableSpeed;

@end

@implementation AFURLConnectionByteSpeedMeasure
@synthesize speed = _speed, humanReadableSpeed = _humanReadableSpeed, windowSize = _windowSize, speedCalculationTimeInterval = _speedCalculationTimeInterval;

#pragma mark - Setters and getters

- (void)setSpeed:(double)speed
{
    if (!fequal(speed, _speed)) {
        [self willChangeValueForKey:@"speed"];
        _speed = speed;
        [self didChangeValueForKey:@"speed"];
        
        self.humanReadableSpeed = [self _humanReadableSpeedFromSpeed:_speed];
    }
}

#pragma mark - Initialization

- (id)init
{
    self = [super init];
    if (self) {
        _windowSize = 64;
        _timesArray = [NSMutableArray arrayWithCapacity:_windowSize];
        _chunkLengthsArray = [NSMutableArray arrayWithCapacity:_windowSize];
        _speedCalculationTimeInterval = 1.0;
        _lastSpeedCalculationTimeInterval = [[NSDate date] timeIntervalSince1970];
        _humanReadableSpeed = [self _humanReadableSpeedFromSpeed:_speed];
    }
    return self;
}

#pragma mark - Instance methods

- (void)updateSpeedWithDataChunkLength:(NSUInteger)dataChunkLength receivedAtDate:(NSDate *)date
{
    if (_chunkLengthsArray.count >= self.windowSize) {
        [_chunkLengthsArray removeObjectAtIndex:0];
        [_timesArray removeObjectAtIndex:0];
    }
    
    [_chunkLengthsArray addObject:@((double)dataChunkLength)];
    [_timesArray addObject:@(date.timeIntervalSince1970)];
    
    if (_chunkLengthsArray.count <= 1) {
        return;
    }
    
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    if (now - _lastSpeedCalculationTimeInterval < self.speedCalculationTimeInterval) {
        //DLog(@"Warning: difference in time interval: %d", (self.speedCalculationTimeInterval - (now-_lastSpeedCalculationTimeInterval)));
        //return;
    }
    
    NSNumber *totalBytesUploaded = [_chunkLengthsArray valueForKeyPath:@"@sum.self"];
    NSTimeInterval overallTime = [_timesArray.lastObject doubleValue] - [_timesArray[0] doubleValue];
    
    self.speed = totalBytesUploaded.doubleValue / overallTime;
    _lastSpeedCalculationTimeInterval = now;
}

#pragma mark - Instance methods

- (NSTimeInterval)remainingTimeOfTotalSize:(long long)totalSize
                     numberOfCompletedBytes:(long long)numberOfCompletedBytes
{
    
    if (numberOfCompletedBytes >= totalSize || self.speed == 0.0) {
        return 0.0;
    }
    
    long long remainingBytes = totalSize - numberOfCompletedBytes;
    NSTimeInterval remainingSeconds = (double)remainingBytes / self.speed;
    
    return remainingSeconds;
}

- (NSString *)humanReadableRemainingTimeOfTotalSize:(long long)totalSize
                              numberOfCompletedBytes:(long long)numberOfCompletedBytes
{
    NSTimeInterval remainingTime = [self remainingTimeOfTotalSize:totalSize numberOfCompletedBytes:numberOfCompletedBytes];
    
    static NSUInteger availableTimeIntervals = 3;
    static double timeIntervals[] = { 60.0, 60.0, 24.0 };
    
    static NSArray *units = nil;
    static NSArray *pluralizedUnits = nil;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        units = (@[
                 NSLocalizedString(@"Second", @""),
                 NSLocalizedString(@"Minute", @""),
                 NSLocalizedString(@"Hour", @""),
                 NSLocalizedString(@"Day", @"")
                 ]);
        
        pluralizedUnits = (@[
                           NSLocalizedString(@"Seconds", @""),
                           NSLocalizedString(@"Minutes", @""),
                           NSLocalizedString(@"Hours", @""),
                           NSLocalizedString(@"Days", @"")
                           ]);
    });
    
    NSUInteger counter = 0;
    while (counter < availableTimeIntervals && remainingTime > timeIntervals[counter]) {
        remainingTime /= timeIntervals[counter];
        counter++;
    }
    
    remainingTime = round(remainingTime);
    NSString *unit = remainingTime == 1.0 ? units[counter] : pluralizedUnits[counter];
    
    return [NSString stringWithFormat:@"%.0lf %@", remainingTime, unit];
}

#pragma mark - Private category implementation ()

- (NSString *)_humanReadableSpeedFromSpeed:(double)speed
{
    static NSArray *speedMeasures = nil;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        speedMeasures = (@[
                         NSLocalizedString(@"B/s", @""),
                         NSLocalizedString(@"KB/s", @""),
                         NSLocalizedString(@"MB/s", @""),
                         NSLocalizedString(@"GB/s", @"")
                         ]);
    });
    
    NSUInteger counter = 0;
    while (counter < speedMeasures.count - 1 && speed > 900.0) {
        speed /= 1024.0;
        counter++;
    }
    
    return [NSString stringWithFormat:@"%01.02lf %@", speed, speedMeasures[counter]];
}

@end
