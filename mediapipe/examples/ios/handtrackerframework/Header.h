#import <Foundation/Foundation.h>
#import <CoreVideo/CoreVideo.h>

@class Landmark;
@class HandTracker;

@protocol HandTrackerDelegate <NSObject>
    @optional
    - (void)handTracker: (HandTracker*)handTracker didOutputLandmarks: (NSArray<Landmark *> *)landmarks timestamp: (double)timestamp;
    - (void)handTracker: (HandTracker*)handTracker didOutputPixelBuffer: (CVPixelBufferRef)pixelBuffer;
@end

@interface HandTracker : NSObject
    - (instancetype)init;
    - (void)startGraph;
    - (void)processVideoFrame:(CVPixelBufferRef)imageBuffer timestamp:(double)timestamp;
    @property (weak, nonatomic) id <HandTrackerDelegate> delegate;
@end

@interface Landmark: NSObject
    @property(nonatomic, readonly) float x;
    @property(nonatomic, readonly) float y;
    @property(nonatomic, readonly) float z;
    
    // Landmark visibility. Should stay unset if not supported.
    // Float score of whether landmark is visible or occluded by other objects.
    // Landmark considered as invisible also if it is not present on the screen
    // (out of scene bounds). Depending on the model, visibility value is either a
    // sigmoid or an argument of sigmoid.
    @property(nonatomic, readonly) float visibility;

    // Landmark presence. Should stay unset if not supported.
    // Float score of whether landmark is present on the scene (located within
    // scene bounds). Depending on the model, presence value is either a result of
    // sigmoid or an argument of sigmoid function to get landmark presence
    // probability.
    @property(nonatomic, readonly) float presence;
@end
