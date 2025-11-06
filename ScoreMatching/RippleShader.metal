#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

/// A ripple effect with chromatic aberration
/// - Parameters:
///   - position: The position of the pixel
///   - time: Animation time (0.0 to 1.0)
///   - center: The center point of the ripple (normalized 0-1)
///   - aspectRatio: Width / Height ratio to correct for screen shape
[[ stitchable ]] half4 rippleEffect(
    float2 position,
    SwiftUI::Layer layer,
    float time,
    float2 center,
    float aspectRatio
) {
    // Adjust position for aspect ratio
    float2 adjustedPos = position;
    adjustedPos.x *= aspectRatio;
    float2 adjustedCenter = center;
    adjustedCenter.x *= aspectRatio;

    // Calculate distance from tap center
    float2 toCenter = adjustedPos - adjustedCenter;
    float dist = length(toCenter);

    // Ripple parameters - subtle and elegant
    float rippleSpeed = 2.5;
    float rippleFrequency = 8.0;
    float rippleWidth = 0.15;

    // Calculate ripple wave
    float wave = time * rippleSpeed;
    float ripple = dist - wave;
    float rippleAmount = smoothstep(rippleWidth, 0.0, abs(ripple)) * (1.0 - time);

    // Chromatic aberration parameters - very subtle
    float aberrationStrength = 0.008 * rippleAmount;
    float2 direction = normalize(toCenter);

    // Sample RGB channels with slight offset for chromatic aberration
    float2 redOffset = position - direction * aberrationStrength * 1.2;
    float2 greenOffset = position;
    float2 blueOffset = position + direction * aberrationStrength * 1.2;

    half4 redSample = layer.sample(redOffset);
    half4 greenSample = layer.sample(greenOffset);
    half4 blueSample = layer.sample(blueOffset);

    // Combine channels
    half4 color = half4(
        redSample.r,
        greenSample.g,
        blueSample.b,
        greenSample.a
    );

    // Add subtle wave distortion at ripple edge
    float wavePattern = sin(ripple * rippleFrequency) * 0.5 + 0.5;
    float brightness = 1.0 + (wavePattern * rippleAmount * 0.15);

    color.rgb *= brightness;

    return color;
}
