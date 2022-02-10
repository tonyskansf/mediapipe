#import "Header.h"

#import "mediapipe/objc/MPPGraph.h"
#import "mediapipe/objc/MPPCameraInputSource.h"
#import "mediapipe/objc/MPPLayerRenderer.h"

#include "mediapipe/framework/formats/landmark.pb.h"

static NSString* const kGraphName = @"hand_tracking_mobile_gpu";
static const char* kInputStream = "input_video";
static const char* kOutputStream = "output_video";
static const char* kLandmarksOutputStream = "hand_landmarks";
static const char* kNumHandsInputSidePacket = "num_hands";
static const char* kVideoQueueLabel = "com.strv.handTracker.videoQueue";

@interface HandTracker() <MPPGraphDelegate>
    @property(nonatomic) MPPGraph* mediapipeGraph;
@end

@interface Landmark()
    - (instancetype)initWithX:(float)x y:(float)y z:(float)z visibility:(float)visibility presence:(float)presence;
@end

@implementation HandTracker {
    /// Process camera frames on this queue.
    dispatch_queue_t _videoQueue;
}

#pragma mark - Cleanup methods

- (void)dealloc {
    self.mediapipeGraph.delegate = nil;
    [self.mediapipeGraph cancel];
    // Ignore errors since we're cleaning up.
    [self.mediapipeGraph closeAllInputStreamsWithError:nil];
    [self.mediapipeGraph waitUntilDoneWithError:nil];
}

#pragma mark - MediaPipe graph methods

+ (MPPGraph*)loadGraphFromResource:(NSString*)resource {
    // Load the graph config resource.
    NSError* configLoadError = nil;
    NSBundle* bundle = [NSBundle bundleForClass:[self class]];
    
    if (!resource || resource.length == 0) {
        NSLog(@"[HandTracker] Failed to load graph from resource.");
        return nil;
    }
    
    NSURL* graphURL = [bundle URLForResource:resource withExtension:@"binarypb"];
    NSData* data = [NSData dataWithContentsOfURL:graphURL options:0 error:&configLoadError];
    
    if (!data) {
        NSLog(@"[HandTracker] Failed to load MediaPipe graph config: %@", configLoadError);
        return nil;
    }
    
    // Parse the graph config resource into mediapipe::CalculatorGraphConfig proto object.
    mediapipe::CalculatorGraphConfig config;
    config.ParseFromArray(data.bytes, data.length);
    
    // Create MediaPipe graph with mediapipe::CalculatorGraphConfig proto object.
    MPPGraph* newGraph = [[MPPGraph alloc] initWithGraphConfig:config];
    [newGraph addFrameOutputStream:kOutputStream outputPacketType:MPPPacketTypePixelBuffer];
    
    NSLog(@"[HandTracker] Loading graph succeeded.");
    return newGraph;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        dispatch_queue_attr_t qosAttribute = dispatch_queue_attr_make_with_qos_class(
            DISPATCH_QUEUE_SERIAL, QOS_CLASS_USER_INTERACTIVE, /*relative_priority=*/0
        );
        _videoQueue = dispatch_queue_create(kVideoQueueLabel, qosAttribute);
        
        self.mediapipeGraph = [[self class] loadGraphFromResource:kGraphName];
        self.mediapipeGraph.delegate = self;

        // Set maxFramesInFlight to a small value to avoid memory contention for real-time processing.
        // https://github.com/google/mediapipe/blob/6abec128edd6d037e1a988605a59957c22f1e967/docs/getting_started/hello_world_ios.md#using-a-mediapipe-graph-in-ios
        self.mediapipeGraph.maxFramesInFlight = 2;

        [self.mediapipeGraph setSidePacket:(mediapipe::MakePacket<int>(1)) named:kNumHandsInputSidePacket];
        [self.mediapipeGraph addFrameOutputStream:kLandmarksOutputStream outputPacketType:MPPPacketTypeRaw];
    }
    return self;
}

- (void)startGraph {
    // Start running self.mediapipeGraph.
    NSError* error;
    if (![self.mediapipeGraph startWithError:&error]) {
        NSLog(@"[HandTracker] Failed to start graph: %@", error);
        return;
    } else if (![self.mediapipeGraph waitUntilIdleWithError:&error]) {
        NSLog(@"[HandTracker] Failed to complete graph initial run: %@", error);
    }

    NSLog(@"[HandTracker] Graph started.");
}

#pragma mark - MPPGraphDelegate methods

// Receives a raw packet from the MediaPipe graph. Invoked on a MediaPipe worker thread.
- (void)mediapipeGraph:(MPPGraph*)graph
       didOutputPacket:(const ::mediapipe::Packet&)packet
            fromStream:(const std::string&)streamName {
    if (streamName == kLandmarksOutputStream) {
        if (packet.IsEmpty()) {
            return; 
        }

        const auto& time = packet.Timestamp().Seconds();
        const auto& handLandmarks = packet.Get<std::vector<::mediapipe::NormalizedLandmarkList>>();

        for (int handIndex = 0; handIndex < handLandmarks.size(); ++handIndex) {
            const auto& landmarks = handLandmarks[handIndex];
            NSMutableArray<Landmark *> *result = [NSMutableArray array];
            for (int i = 0; i < landmarks.landmark_size(); ++i) {
                Landmark* landmark = [
                    [Landmark alloc] initWithX:landmarks.landmark(i).x()
                    y:landmarks.landmark(i).y()
                    z:landmarks.landmark(i).z()
                    visibility:landmarks.landmark(i).visibility()
                    presence:landmarks.landmark(i).presence()
                ];
                [result addObject:landmark];
            }
            [_delegate handTracker:self didOutputLandmarks:result timestamp:time];
        }
    }
}

#pragma mark - MPPInputSourceDelegate methods

- (void)processVideoFrame:(CVPixelBufferRef)imageBuffer timestamp: (double)timestamp {
    NSLog(@"[HandTracker] Graph: %@", self.mediapipeGraph.description);
    dispatch_async(_videoQueue, ^{
        // TODO: Return the underlying error inside sendPixelBuffer.
        BOOL result = [self.mediapipeGraph sendPixelBuffer:imageBuffer
                                    intoStream:kInputStream
                                    packetType:MPPPacketTypePixelBuffer
                                    timestamp:mediapipe::Timestamp::FromSeconds(timestamp)];

        if (result) {
            NSLog(@"[HandTracker] Sending pixel buffer SUCCEEDED.");
        } else {
            NSLog(@"[HandTracker] Sending pixel buffer FAILED.");
        }
    });
}

- (void)mediapipeGraph:(MPPGraph*)graph
    didOutputPixelBuffer:(CVPixelBufferRef)pixelBuffer
              fromStream:(const std::string&)streamName {
    if (streamName == kOutputStream) {
        [_delegate handTracker: self didOutputPixelBuffer: pixelBuffer];
    }
}

@end


@implementation Landmark

- (instancetype)initWithX:(float)x y:(float)y z:(float)z visibility:(float)visibility presence:(float)presence
{ 
    self = [super init];
    if (self) {
        _x = x;
        _y = y;
        _z = z;
        _visibility = visibility;
        _presence = presence;
    }
    return self;
}

@end
