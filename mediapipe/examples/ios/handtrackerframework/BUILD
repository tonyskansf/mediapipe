load(
    "@build_bazel_rules_apple//apple:ios.bzl", 
    "ios_framework",
)

MIN_IOS_VERSION = "13.0"

IOS_FAMILIES = [
    "iphone",
    "ipad",
]

FRAMEWORK_HEADERS = [
    "Header.h",
]

ios_framework(
    name = "HandTracker",
    hdrs = FRAMEWORK_HEADERS,
    bundle_id = "com.strv.HandTracker",
    bundle_name = "HandTracker",
    families = IOS_FAMILIES,
    infoplists = [
        "Info.plist",
    ],
    minimum_os_version = MIN_IOS_VERSION,
    visibility = ["//visibility:public"],
    deps = [
        ":HandTrackerLibrary",
        "@ios_opencv//:OpencvFramework",
    ],
)

objc_library(
    name = "HandTrackerLibrary",
    srcs = [
        "Header.mm",
    ],
    hdrs = FRAMEWORK_HEADERS,
    copts = [
        "-std=c++17",
    ],
    data = [
        "//mediapipe/graphs/hand_tracking:hand_tracking_mobile_gpu_binary_graph",
        "//mediapipe/modules/hand_landmark:hand_landmark_full.tflite",
        "//mediapipe/modules/hand_landmark:handedness.txt",
        "//mediapipe/modules/palm_detection:palm_detection_full.tflite",
    ],
    sdk_frameworks = [
        "AVFoundation",
        "CoreGraphics",
        "CoreMedia",
        "UIKit"
    ],
    deps = [
        "//mediapipe/objc:mediapipe_framework_ios",
        "//mediapipe/objc:mediapipe_input_sources_ios",
        "//mediapipe/objc:mediapipe_layer_renderer",
    ] + select({
        "//mediapipe:ios_i386": [],
        "//mediapipe:ios_x86_64": [],
        "//conditions:default": [
            "//mediapipe/graphs/hand_tracking:mobile_calculators",
            "//mediapipe/framework/formats:landmark_cc_proto",
        ],
    }),
)
